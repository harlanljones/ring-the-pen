defmodule RingThePen.JudgmentsTest do
  use ExUnit.Case, async: true

  alias RingThePen.Judgments
  alias RingThePen.Questions
  alias TypeSafeAPI.Answer.{Choice, Noul, Score}

  @questions Questions.questions()

  @valid_state %{
    "inning" => 7,
    "outs" => 1,
    "runners_on" => 2,
    "score_diff" => -1,
    "pitch_count" => 84,
    "bullpen_state" => "available",
    "leverage_index" => 2.4,
    "w_bvp" => 0.47368421052631576,
    "w_prior" => 0.5263157894736842,
    "prior_rate" => 0.33,
    "upcoming" => [
      %{"n" => 18, "rate" => 0.312},
      %{"n" => 7, "rate" => 0.25},
      %{"n" => nil, "rate" => nil}
    ]
  }

  defp valid_answers do
    %{
      pull_decision: %Choice{
        id: :pull_decision,
        choice: :soft_hook,
        description: Enum.at(@questions[:pull_decision].criteria, 2) |> elem(1),
        probabilities: %{
          pull_now: 0.08,
          ride: 0.12,
          soft_hook: 0.55,
          emergency_hook: 0.05,
          other: 0.2
        },
        options:
          Enum.map(@questions[:pull_decision].criteria, fn {key, _} -> {key, pull_prob(key)} end),
        confidence: 0.62
      },
      hook_urgency: %Score{
        id: :hook_urgency,
        score: 2.1,
        level: 2,
        label: "warm",
        description: @questions[:hook_urgency].levels |> Enum.at(2) |> elem(1),
        levels:
          Enum.with_index(Enum.map(@questions[:hook_urgency].levels, &elem(&1, 0)))
          |> Enum.map(fn {label, i} -> {label, hook_prob(i)} end),
        probabilities: %{0 => 0.06, 1 => 0.13, 2 => 0.54, 3 => 0.19, 4 => 0.08},
        confidence: 0.54,
        legend:
          @questions[:hook_urgency].levels
          |> Enum.with_index()
          |> Map.new(fn {{label, description}, i} ->
            {i, %{"label" => label, "description" => description}}
          end)
      },
      danger_pa_now: %Noul{id: :danger_pa_now, noul: 0.28, confidence: 0.72},
      danger_window_next3: %Noul{id: :danger_window_next3, noul: 0.55, confidence: 0.55}
    }
  end

  defp pull_prob(:pull_now), do: 0.08
  defp pull_prob(:ride), do: 0.12
  defp pull_prob(:soft_hook), do: 0.55
  defp pull_prob(:emergency_hook), do: 0.05
  defp pull_prob(:other), do: 0.2

  defp hook_prob(0), do: 0.06
  defp hook_prob(1), do: 0.13
  defp hook_prob(2), do: 0.54
  defp hook_prob(3), do: 0.19
  defp hook_prob(4), do: 0.08

  defp raw_response do
    %{
      "answers" => %{
        "pull_decision" => %{
          "type" => "choice",
          "choice" => "soft_hook",
          "confidence" => 0.62,
          "probabilities" => %{
            "pull_now" => 0.08,
            "ride" => 0.12,
            "soft_hook" => 0.55,
            "emergency_hook" => 0.05,
            "other" => 0.2
          }
        },
        "hook_urgency" => %{
          "type" => "score",
          "score" => 2.1,
          "confidence" => 0.54,
          "probabilities" => %{"0" => 0.06, "1" => 0.13, "2" => 0.54, "3" => 0.19, "4" => 0.08},
          "legend" =>
            Map.new(Enum.with_index(@questions[:hook_urgency].levels), fn {{l, d}, i} ->
              {Integer.to_string(i), %{"label" => l, "description" => d}}
            end)
        },
        "danger_pa_now" => %{"type" => "noul", "noul" => 0.28},
        "danger_window_next3" => %{"type" => "noul", "noul" => 0.55}
      },
      "model" => "test-model",
      "usage" => %{"input_tokens" => 10, "output_tokens" => 5}
    }
  end

  defp build_record(opts \\ []) do
    opts =
      Keyword.merge(
        [
          response: raw_response(),
          recorded_at: "2026-09-21T00:00:00Z",
          source_lineage: %{"kind" => "synthetic", "note" => "test input"}
        ],
        opts
      )

    Judgments.from_answers(@valid_state, @questions, "test-model", valid_answers(), opts)
  end

  describe "from_answers/5" do
    test "accepts a fully valid judgment set and returns a frozen-schema record" do
      assert {:ok, record} = build_record()

      assert record["schema_version"] == 1
      assert record["state_hash"] == Questions.state_hash(@valid_state)
      assert record["questions_hash"] == Questions.hash(@questions)
      assert record["model"] == "test-model"

      assert MapSet.new(Map.keys(record)) ==
               MapSet.new(
                 ~w(schema_version state_hash questions_hash model recorded_at response answers source_lineage)
               )
    end

    test "rejects a missing raw response" do
      assert {:error, {:invalid_answers, "response has no answers map"}} =
               build_record(response: nil)

      assert {:error, {:invalid_record, "response is required"}} =
               Judgments.from_answers(
                 @valid_state,
                 @questions,
                 "test-model",
                 valid_answers(),
                 recorded_at: "2026-09-21T00:00:00Z"
               )
    end

    test "rejects an answer whose selected choice is not an option" do
      answers =
        Map.update!(valid_answers(), :pull_decision, fn choice ->
          %{choice | choice: :balk}
        end)

      assert {:error, {:invalid_answers, "unexpected option for pull_decision"}} =
               Judgments.from_answers(@valid_state, @questions, "test-model", answers,
                 response: raw_response(),
                 source_lineage: %{"kind" => "synthetic"}
               )
    end

    test "rejects a choice whose probabilities do not sum to one" do
      answers =
        Map.update!(valid_answers(), :pull_decision, fn choice ->
          %{choice | probabilities: Map.put(choice.probabilities, :soft_hook, 0.65)}
        end)

      assert {:error, {:invalid_answers, message}} =
               Judgments.from_answers(@valid_state, @questions, "test-model", answers,
                 response: raw_response(),
                 source_lineage: %{"kind" => "synthetic"}
               )

      assert message =~ "do not sum to one"
    end

    test "rejects a confidence outside [0,1]" do
      answers =
        Map.update!(valid_answers(), :hook_urgency, fn score -> %{score | confidence: 1.5} end)

      assert {:error, {:invalid_answers, message}} =
               Judgments.from_answers(@valid_state, @questions, "test-model", answers,
                 response: raw_response(),
                 source_lineage: %{"kind" => "synthetic"}
               )

      assert message =~ "confidence"
    end

    test "rejects a Noul whose confidence is not max(noul, 1 - noul)" do
      answers = Map.update!(valid_answers(), :danger_pa_now, fn n -> %{n | confidence: 0.5} end)

      assert {:error, {:invalid_answers, "Noul confidence mismatch for danger_pa_now"}} =
               Judgments.from_answers(@valid_state, @questions, "test-model", answers,
                 response: raw_response(),
                 source_lineage: %{"kind" => "synthetic"}
               )
    end

    test "rejects a score whose value disagrees with its probabilities" do
      answers =
        Map.update!(valid_answers(), :hook_urgency, fn score -> %{score | score: 4.0} end)

      assert {:error, {:invalid_record, "score disagrees with probabilities for hook_urgency"}} =
               Judgments.from_answers(@valid_state, @questions, "test-model", answers,
                 response: raw_response(),
                 source_lineage: %{"kind" => "synthetic"}
               )
    end
  end

  describe "validate_record/3" do
    test "round-trips a valid record" do
      {:ok, record} = build_record()
      assert {:ok, ^record} = Judgments.validate_record(record, @valid_state, @questions)
    end

    test "rejects a record whose state hash does not match the presented state" do
      {:ok, record} = build_record()
      other_state = Map.put(@valid_state, "inning", 8)

      assert {:error, :state_hash_mismatch} =
               Judgments.validate_record(record, other_state, @questions)
    end

    test "rejects a record whose questions hash does not match the frozen pack" do
      {:ok, record} = build_record()

      assert {:error, :questions_hash_mismatch} =
               Judgments.validate_record(record, @valid_state, [
                 {:bogus, @questions[:pull_decision]}
               ])
    end

    test "rejects a record whose keys do not match the frozen contract" do
      {:ok, record} = build_record()
      record = Map.delete(record, "model") |> Map.put("extra", 1)

      assert {:error, {:invalid_record, "record keys do not match the frozen contract"}} =
               Judgments.validate_record(record, @valid_state, @questions)
    end

    test "rejects a record whose lineage kind is unknown" do
      assert {:error, {:invalid_record, message}} =
               build_record(source_lineage: %{"kind" => "dreamed"})

      assert message =~ "source_lineage"

      {:ok, record} = build_record()
      tampered = Map.put(record, "source_lineage", %{"kind" => "dreamed"})

      assert {:error, {:invalid_record, message}} =
               Judgments.validate_record(tampered, @valid_state, @questions)

      assert message =~ "source_lineage"
    end
  end

  describe "raw-vs-serialized agreement" do
    test "rejects a record whose serialized choice disagrees with the raw response" do
      {:ok, record} = build_record()

      record =
        put_in(
          record,
          ["answers", "pull_decision", "confidence"],
          0.9
        )

      assert {:error, {:invalid_record, message}} =
               Judgments.validate_record(record, @valid_state, @questions)

      assert message =~ "disagrees with raw response"
    end

    test "rejects a response with a wrong score legend" do
      raw = raw_response()

      raw =
        put_in(raw, ["answers", "hook_urgency", "legend", "0", "label"], "not-calm")

      assert {:error, {:invalid_answers, "raw score legend mismatch for hook_urgency"}} =
               Judgments.from_answers(@valid_state, @questions, "test-model", valid_answers(),
                 response: raw,
                 source_lineage: %{"kind" => "synthetic"}
               )
    end

    test "rejects a response missing a usage key" do
      raw = raw_response() |> update_in(["usage"], &Map.delete(&1, "output_tokens"))

      assert {:error, {:invalid_answers, message}} =
               Judgments.from_answers(@valid_state, @questions, "test-model", valid_answers(),
                 response: raw,
                 source_lineage: %{"kind" => "synthetic"}
               )

      assert message =~ "usage"
    end
  end

  describe "frozen question pack snapshot (priv/jev/questions/v1.json)" do
    @pack_path "priv/jev/questions/v1.json"

    test "exists, has the frozen schema version, and hashes to the module's pack hash" do
      assert {:ok, body} = File.read(@pack_path)
      assert {:ok, pack} = Jason.decode(body)
      assert pack["schema_version"] == 1
      assert pack["pack"] == "ring-the-pen/questions/v1"
      assert pack["questions_hash"] == Questions.hash(@questions)
    end

    test "each snapshot question equals the module's wire encoding exactly" do
      {:ok, pack} = Jason.decode(File.read!(@pack_path))

      Enum.zip(pack["questions"], @questions)
      |> Enum.each(fn {%{"id" => id, "question" => snapshot}, {module_id, question}} ->
        assert id == Atom.to_string(module_id)

        encoded = wire_encode(question.__struct__.encode(question))
        assert snapshot == encoded
      end)
    end

    # OrderedObject (Choice criteria) is a struct, not a map: unwind it to a
    # plain map so it compares equal to the decoded JSON object.
    defp wire_encode(%TypeSafeAPI.JSON.OrderedObject{pairs: pairs}) do
      Map.new(pairs, fn {key, value} -> {key, wire_encode(value)} end)
    end

    defp wire_encode(value) when is_map(value) and not is_struct(value) do
      Map.new(value, fn {key, inner} -> {key, wire_encode(inner)} end)
    end

    defp wire_encode(value) when is_list(value), do: Enum.map(value, &wire_encode/1)

    defp wire_encode(value), do: value
  end

  describe "offline replay of synthetic fixtures (no TYPESAFE_API_KEY)" do
    @fixtures_dir "priv/jev/fixtures/synthetic"

    test "every synthetic fixture record replays against its synthetic state" do
      fixtures =
        Path.wildcard(Path.join(@fixtures_dir, "synthetic--*.json"))
        |> Enum.sort()

      assert fixtures != []

      Enum.each(fixtures, fn fixture_path ->
        assert fixture_path =~ ~r/synthetic--/, "synthetic fixtures must carry the prefix"
        assert {:ok, state} = Jason.decode(File.read!(state_path(fixture_path)))
        assert Questions.validate_state(state) == :ok

        assert {:ok, record} = Judgments.load(fixture_path, state, @questions)
        assert record["source_lineage"]["kind"] == "synthetic"
        assert record["response"]["model"] == "synthetic-fixture"
      end)
    end

    test "a tampered fixture fails closed" do
      fixture_path = Path.join(@fixtures_dir, "synthetic--inpa-threat.json")
      {:ok, record} = Jason.decode(File.read!(fixture_path))
      tampered = Map.put(record, "questions_hash", "sha256:deadbeef")

      assert {:error, :questions_hash_mismatch} =
               Judgments.validate_record(tampered, decoded_state("inpa-threat"), @questions)
    end

    defp decoded_state(name) do
      {:ok, state} =
        Jason.decode(File.read!(Path.join([@fixtures_dir, "states", name <> ".json"])))

      state
    end

    defp state_path(fixture_path) do
      name =
        fixture_path
        |> Path.basename(".json")
        |> String.replace_prefix("synthetic--", "")

      Path.join([@fixtures_dir, "states", name <> ".json"])
    end
  end

  describe "recordings directory contract" do
    test "holds no synthetic content and READMEs the pending status" do
      readme = File.read!(Path.join("priv", "jev/recordings/README.md"))
      assert readme =~ "recorded"

      recordings = Path.wildcard(Path.join("priv", "jev/recordings/*.json"))
      assert recordings == [], "no real recordings exist yet; nothing may masquerade as one"
    end
  end
end
