defmodule RingThePen.CatalogTest do
  use ExUnit.Case, async: true

  alias RingThePen.Catalog

  # Synthetic code-computed fixtures only; no historical outcomes or API calls.
  defp card(n \\ 20, pa_index \\ 4) do
    %{
      "id" => "hook:SYNTHETIC:#{pa_index}",
      "game_id" => "SYNTHETIC",
      "pa_index" => pa_index,
      "synthetic" => true,
      "judgment_state" => %{
        "inning" => 7,
        "outs" => 1,
        "runners_on" => 2,
        "score_diff" => -1,
        "pitch_count" => nil,
        "bullpen_state" => "unknown",
        "leverage_index" => nil,
        "w_bvp" => n / (n + 1000),
        "w_prior" => 1000 / (n + 1000),
        "prior_rate" => 0.32,
        "upcoming" => [
          %{"n" => 18, "rate" => 0.312},
          %{"n" => 0, "rate" => nil},
          %{"n" => nil, "rate" => nil}
        ]
      },
      "bvp" => %{
        "n" => n,
        "xbar" => 0.4,
        "m" => 0.32,
        "k_shrink" => 1000.0,
        "posterior" => (n * 0.4 + 1000 * 0.32) / (n + 1000),
        "underqualified" => n < 20
      },
      "samples" => %{"bvp_n" => n, "upcoming_n" => [18, 0, nil]}
    }
  end

  defp artifact(cards \\ [card()]) do
    %{
      "schema_version" => 1,
      "formula_version" => "hook-card/1",
      "generated_by" => "scripts/cards.py (RTP-08; offline)",
      "license" => "Retrosheet data used under the Retrosheet notice (see NOTICE)",
      "purpose" =>
        "Frozen precomputed hook cards for the Phase H card/lock path: each card pairs an exact judgment_state with its provenance",
      "provenance" => %{
        "sources" => [],
        "bvp_formula" => "bvp-shrink/1",
        "k_display" => 20,
        "n_upcoming" => 3
      },
      "synthetic" => true,
      "cards" => cards
    }
  end

  defp temp_path do
    path = Path.join(System.tmp_dir!(), "rtp-catalog-#{System.unique_integer([:positive])}.json")
    on_exit(fn -> File.rm(path) end)
    path
  end

  test "validates unchanged maps and preserves explicit unknowns" do
    input = artifact()
    assert {:ok, ^input} = Catalog.validate(input)
    input_card = card()
    assert {:ok, ^input_card} = Catalog.validate_card(input_card)
    assert {:ok, _} = Catalog.validate(artifact([]))
  end

  test "loads a validated JSON artifact and reports file/JSON errors" do
    path = temp_path()
    input = artifact()
    File.write!(path, Jason.encode!(input))
    assert {:ok, ^input} = Catalog.load(path)
    File.write!(path, "{broken")
    assert {:error, _} = Catalog.load(path)
    File.write!(path, Jason.encode!(Map.put(input, "schema_version", 2)))
    assert {:error, _} = Catalog.load(path)
    File.rm!(path)
    assert {:error, _} = Catalog.load(path)
    for bad <- [nil, 3, [], %{}], do: assert({:error, _} = Catalog.load(bad))
  end

  test "accepts the actual offline Python builder output" do
    path = temp_path()

    script = """
    from pathlib import Path
    from scripts.cards import build_card, build_artifact, serialize
    import sys
    card = build_card(game_id='SYNTHETIC', pa_index=4, inning=7, outs=1,
        runners_on=2, score_diff=-1, pitch_count=None, bullpen_state='unknown',
        leverage_index=None, bvp_n=20, bvp_xbar=.4, bvp_m=.32,
        upcoming=[(18,.312),(0,None),(None,None)])
    Path(sys.argv[1]).write_text(serialize(build_artifact([card], sources=[])))
    """

    assert {"", 0} = System.cmd("python3", ["-c", script, path])
    assert {:ok, result} = Catalog.load(path)
    assert result["synthetic"] == true
    assert get_in(result, ["cards", Access.at(0), "judgment_state", "pitch_count"]) == nil
  end

  test "rejects malformed JSON-shaped values at every object boundary without raising" do
    bad_shapes = [nil, true, false, 1, 1.2, "wrong", []]

    for bad <- bad_shapes do
      assert {:error, _} = Catalog.validate(bad)
      assert {:error, _} = Catalog.validate_card(bad)

      for key <- ["provenance", "cards"], not (key == "cards" and bad == []) do
        assert {:error, _} = Catalog.validate(Map.put(artifact(), key, bad))
      end

      for key <- ["bvp", "judgment_state", "samples"] do
        assert {:error, _} = Catalog.validate_card(Map.put(card(), key, bad))
      end
    end
  end

  test "rejects missing and unknown keys at every nesting level" do
    base = artifact()

    paths = [
      [],
      ["provenance"],
      ["cards", Access.at(0)],
      ["cards", Access.at(0), "bvp"],
      ["cards", Access.at(0), "samples"],
      ["cards", Access.at(0), "judgment_state"],
      ["cards", Access.at(0), "judgment_state", "upcoming", Access.at(0)]
    ]

    for path <- paths do
      object = if path == [], do: base, else: get_in(base, path)

      for key <- Map.keys(object) do
        changed =
          if path == [],
            do: Map.delete(base, key),
            else: put_in(base, path, Map.delete(object, key))

        assert {:error, _} = Catalog.validate(changed), "accepted missing #{inspect(path)} #{key}"
      end

      changed =
        if path == [],
          do: Map.put(base, "oracle", true),
          else: put_in(base, path, Map.put(object, "oracle", true))

      assert {:error, _} = Catalog.validate(changed)
    end
  end

  test "enforces frozen versions, attribution, purpose and boolean flags" do
    for {key, bad} <- [
          {"schema_version", 2},
          {"schema_version", 1.0},
          {"formula_version", "hook-card/2"},
          {"generated_by", "unknown"},
          {"license", ""},
          {"purpose", "something else"},
          {"synthetic", nil}
        ] do
      assert {:error, _} = Catalog.validate(Map.put(artifact(), key, bad))
    end

    for {key, bad} <- [{"bvp_formula", "bvp-shrink/2"}, {"k_display", 21}, {"n_upcoming", 4}] do
      assert {:error, _} = Catalog.validate(put_in(artifact(), ["provenance", key], bad))
    end

    assert {:error, _} = Catalog.validate_card(Map.put(card(), "synthetic", "true"))

    assert {:error, _} =
             Catalog.validate(put_in(artifact(), ["cards", Access.at(0), "synthetic"], false))
  end

  test "requires explicit meaningful unique source id and digest pairs for real mode" do
    # This verifies metadata policy only, and does not assert historical provenance.
    source = %{
      "id" => "test-metadata-only",
      "sha256" => Base.encode16(:crypto.hash(:sha256, "test-metadata-only"), case: :lower)
    }

    real = artifact([Map.put(card(), "synthetic", false)]) |> Map.put("synthetic", false)
    assert {:error, _} = Catalog.validate(real)
    real = put_in(real, ["provenance", "sources"], [source])
    assert {:ok, ^real} = Catalog.validate(real)

    for bad <- [
          nil,
          %{},
          "",
          [%{}],
          [Map.put(source, "extra", true)],
          [Map.delete(source, "sha256")],
          [Map.put(source, "id", " ")],
          [source, source]
        ] do
      assert {:error, _} = Catalog.validate(put_in(real, ["provenance", "sources"], bad))
    end

    for digest <- [
          nil,
          "",
          "unknown",
          String.duplicate("0", 64),
          String.duplicate("x", 64),
          "abc",
          42
        ] do
      assert {:error, _} =
               Catalog.validate(
                 put_in(real, ["provenance", "sources"], [Map.put(source, "sha256", digest)])
               )
    end
  end

  test "requires stable hook identity and ordered unique cards" do
    for {key, value} <- [
          {"id", "pitcher:123:2025"},
          {"id", "hook:SYNTHETIC:5"},
          {"game_id", " "},
          {"game_id", 3},
          {"pa_index", -1},
          {"pa_index", 4.0}
        ] do
      assert {:error, _} = Catalog.validate_card(Map.put(card(), key, value))
    end

    assert {:error, _} = Catalog.validate(artifact([card(), card()]))
    assert {:error, _} = Catalog.validate(artifact([card(20, 5), card()]))
    assert {:ok, _} = Catalog.validate(artifact([card(), card(20, 5)]))
  end

  test "cross-checks sample counts, prior, weights, posterior and qualification" do
    mutations = [
      {["samples", "bvp_n"], 19},
      {["samples", "upcoming_n"], [18, 0, 0]},
      {["samples", "upcoming_n"], [18, 0]},
      {["bvp", "posterior"], 0.9},
      {["bvp", "underqualified"], true},
      {["judgment_state", "prior_rate"], 0.31},
      {["judgment_state", "w_bvp"], 0.5},
      {["bvp", "n"], -1},
      {["bvp", "xbar"], nil},
      {["bvp", "m"], 1.2},
      {["bvp", "k_shrink"], 0},
      {["bvp", "posterior"], nil},
      {["bvp", "underqualified"], "false"}
    ]

    for {path, value} <- mutations do
      assert {:error, _} = Catalog.validate_card(put_in(card(), path, value)), inspect(path)
    end

    # Swapping both weights keeps their sum valid but contradicts the sample.
    changed =
      card()
      |> put_in(["judgment_state", "w_bvp"], 1000 / 1020)
      |> put_in(["judgment_state", "w_prior"], 20 / 1020)

    assert {:error, _} = Catalog.validate_card(changed)
  end

  test "qualification is precisely n < 20 and zero sample retains its prior" do
    for n <- [0, 19, 20, 21] do
      input = card(n)
      assert {:ok, ^input} = Catalog.validate_card(input)

      assert {:error, _} =
               Catalog.validate_card(put_in(input, ["bvp", "underqualified"], n >= 20))
    end
  end

  test "keeps the judgment boundary strict including upcoming unit rates" do
    for key <- ["pitcher_id", "team", "year", "pa_result", "next_pa_outcome", "oracle"] do
      assert {:error, _} =
               Catalog.validate_card(
                 update_in(card(), ["judgment_state"], &Map.put(&1, key, true))
               )

      assert {:error, _} =
               Catalog.validate_card(
                 update_in(
                   card(),
                   ["judgment_state", "upcoming", Access.at(0)],
                   &Map.put(&1, key, true)
                 )
               )
    end

    for bad <- [-0.1, 1.1, "unknown", %{"oracle" => true}] do
      assert {:error, _} =
               Catalog.validate_card(
                 put_in(card(), ["judgment_state", "upcoming", Access.at(0), "rate"], bad)
               )
    end

    for {key, value} <- [{"pitch_count", 0}, {"bullpen_state", nil}, {"inning", 0}] do
      assert {:error, _} = Catalog.validate_card(put_in(card(), ["judgment_state", key], value))
    end
  end

  test "rejects enormous numeric inputs without raising or coercing them" do
    huge = Integer.pow(10, 400)

    for changed <- [
          put_in(card(), ["bvp", "k_shrink"], huge),
          put_in(card(), ["bvp", "n"], huge),
          put_in(card(), ["bvp", "xbar"], huge),
          put_in(card(), ["judgment_state", "w_bvp"], huge)
        ] do
      assert {:error, _} = Catalog.validate_card(changed)
    end
  end

  test "rejects every malformed scalar type rather than defaulting a value" do
    for path <- [
          ["bvp", "n"],
          ["bvp", "xbar"],
          ["bvp", "m"],
          ["bvp", "k_shrink"],
          ["bvp", "posterior"],
          ["samples", "bvp_n"],
          ["judgment_state", "w_bvp"],
          ["judgment_state", "w_prior"],
          ["judgment_state", "prior_rate"],
          ["pa_index"],
          ["game_id"]
        ],
        bad <- [nil, true, false, [], %{}, "unknown"] do
      assert {:error, _} = Catalog.validate_card(put_in(card(), path, bad))
    end
  end

  test "requires the shared prior field to equal its outer metric exactly" do
    assert {:error, _} =
             Catalog.validate_card(
               put_in(card(), ["judgment_state", "prior_rate"], 0.32 + 1.0e-13)
             )
  end

  test "synthetic provenance may use an explicit placeholder digest without becoming real" do
    input =
      put_in(artifact(), ["provenance", "sources"], [
        %{"id" => "synthetic-test-only", "sha256" => String.duplicate("0", 64)}
      ])

    assert {:ok, ^input} = Catalog.validate(input)
  end
end
