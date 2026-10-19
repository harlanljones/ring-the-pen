defmodule RingThePenWeb.WorkbenchLiveTest do
  use RingThePenWeb.ConnCase, async: false

  alias RingThePen.Questions

  @moduletag :tmp_dir
  setup %{tmp_dir: dir} do
    prior = Application.get_env(:ring_the_pen, :workbench)

    on_exit(fn ->
      if prior,
        do: Application.put_env(:ring_the_pen, :workbench, prior),
        else: Application.delete_env(:ring_the_pen, :workbench)
    end)

    catalog = Path.join(dir, "catalog.json")
    recordings = Path.join(dir, "recordings")
    File.mkdir_p!(recordings)

    Application.put_env(:ring_the_pen, :workbench,
      catalog_path: catalog,
      recordings_dir: recordings,
      allow_synthetic: true
    )

    %{catalog: catalog, recordings: recordings}
  end

  test "missing catalog is an honest historical empty state", %{conn: conn} do
    {:ok, view, html} = live(conn, "/")
    assert html =~ "No hook card loaded"
    assert html =~ "historical"
    assert html =~ "Retrosheet"
    assert html =~ "obtained free of charge from and is copyrighted by Retrosheet"
    refute html =~ "Lock route:"
    assert has_element?(view, "main#main-content")
  end

  test "act route shows card metrics, all probabilities, unknowns and audit", ctx do
    item = card(20)
    write_catalog(ctx.catalog, [item])
    write_record(ctx.recordings, item, :act)

    {:ok, view, html} = live(ctx.conn, "/cards/#{item["id"]}")
    assert html =~ "Lock route: act"
    {status_at, _} = :binary.match(html, ~s(id="workbench-status"))
    {route_at, _} = :binary.match(html, ~s(id="lock-route"))
    {card_at, _} = :binary.match(html, ~s(id="card-heading"))
    assert status_at < route_at
    assert route_at < card_at
    assert html =~ "Pitcher: Unknown"
    assert html =~ "Batter: Unknown"
    assert html =~ "Pitch count: Unknown"
    assert html =~ "Pitch cap: Unknown"
    assert html =~ "Injury: Unknown"
    assert html =~ "Empty pen: Unknown"
    assert html =~ "k_display: 20 (provisional)"
    assert html =~ "k_shrink: 20"
    assert html =~ "Choice confidence: 90.0%"
    assert html =~ "Score confidence: 90.0%"
    assert html =~ "no danger: 90.0%"
    assert html =~ "Observed rate: 0.400"
    assert html =~ "Prior rate: 0.330"
    assert html =~ "Posterior rate: 0.365"
    assert html =~ ">0.312</td>"
    refute html =~ "31.2%"
    assert html =~ Questions.state_hash(item["judgment_state"])
    assert html =~ Questions.hash(Questions.questions())
    assert html =~ "SYNTHETIC"
    assert has_element?(view, "#lock-route")
    assert has_element?(view, "#audit")
    assert has_element?(view, "table caption", "Upcoming batters")
    assert has_element?(view, "table caption", "Pull decision probabilities")
    assert has_element?(view, "table caption", "Hook urgency probabilities")
    assert has_element?(view, ".primary-decision")
  end

  test "review and escalate show all probabilities without a primary recommendation", ctx do
    review = card(18, 1)
    escalate = card(20, 2)
    write_catalog(ctx.catalog, [review, escalate])
    write_record(ctx.recordings, review, :review)
    write_record(ctx.recordings, escalate, :escalate)

    for {item, route} <- [{review, "review"}, {escalate, "escalate"}] do
      {:ok, view, html} = live(ctx.conn, "/cards/#{item["id"]}")
      assert html =~ "Lock route: #{route}"
      assert html =~ "Pull decision probabilities"
      assert html =~ "Hook urgency probabilities"
      assert html =~ "secondary"
      refute has_element?(view, ".primary-decision")
    end
  end

  test "underqualified sample blocks act", ctx do
    item = card(18)
    write_catalog(ctx.catalog, [item])
    write_record(ctx.recordings, item, :act)
    {:ok, _view, html} = live(ctx.conn, "/cards/#{item["id"]}")
    assert html =~ "Lock route: review"
    assert html =~ "Underqualified"
  end

  test "large shrink constant and blended rates use readable decimal precision", ctx do
    item =
      card(20)
      |> put_in(["bvp", "k_shrink"], 1000.0)
      |> put_in(["bvp", "posterior"], (20 * 0.4 + 1000 * 0.33) / 1020)
      |> put_in(["judgment_state", "w_bvp"], 20 / 1020)
      |> put_in(["judgment_state", "w_prior"], 1000 / 1020)

    write_catalog(ctx.catalog, [item])
    write_record(ctx.recordings, item, :act)
    {:ok, _view, html} = live(ctx.conn, "/cards/#{item["id"]}")
    assert html =~ "k_shrink: 1000"
    refute html =~ "1.0e3"
    assert html =~ "Posterior rate: 0.331"
  end

  test "known pitch count reaches code gates while limited bullpen leaves empty pen unknown",
       ctx do
    item =
      card(20)
      |> put_in(["judgment_state", "pitch_count"], 84)
      |> put_in(["judgment_state", "bullpen_state"], "limited")

    write_catalog(ctx.catalog, [item])
    write_record(ctx.recordings, item, :act)

    {:ok, _view, html} = live(ctx.conn, "/cards/#{item["id"]}")
    assert html =~ "Pitch count: 84"
    assert html =~ "Bullpen state: limited"
    assert html =~ "Empty pen: Unknown"
    assert html =~ "Fired gates: None"
    assert html =~ "Lock route: act"
  end

  test "patch selection clears a prior verdict for missing judgment and unknown id", ctx do
    first = card(20, 1)
    missing = card(20, 2)
    write_catalog(ctx.catalog, [first, missing])
    write_record(ctx.recordings, first, :act)

    {:ok, view, _html} = live(ctx.conn, "/cards/#{first["id"]}")
    assert has_element?(view, ".primary-decision")
    view |> form("#card-selection", %{"card_id" => missing["id"]}) |> render_change()
    assert_patch(view, "/cards/" <> URI.encode_www_form(missing["id"]))
    assert render(view) =~ "No matching saved judgment"
    refute render(view) =~ "Lock route: act"
    refute has_element?(view, ".primary-decision")

    write_record(ctx.recordings, missing, :review)
    assert view |> element("button[phx-click='reload']") |> render_click() =~ "Lock route: review"

    assert render_patch(view, "/cards/hook:missing:99") =~ "Card not found"
    refute render(view) =~ "Pull decision probabilities"
  end

  test "bad catalog, invalid matching record and duplicate records fail closed", ctx do
    write_catalog(ctx.catalog, [])
    {:ok, _view, html} = live(ctx.conn, "/")
    assert html =~ "No hook card loaded"

    File.write!(ctx.catalog, "{bad")
    {:ok, _view, html} = live(ctx.conn, "/")
    assert html =~ "Catalog unavailable"
    refute html =~ ctx.catalog

    item = card(20)
    write_catalog(ctx.catalog, [item])
    bad = Path.join(ctx.recordings, "bad.json")
    File.write!(bad, "{bad")
    {:ok, _view, html} = live(ctx.conn, "/cards/#{item["id"]}")
    assert html =~ "Judgment unavailable"
    File.rm!(bad)

    path = write_record(ctx.recordings, item, :act)
    record = path |> File.read!() |> Jason.decode!()
    File.write!(path, Jason.encode!(Map.put(record, "questions_hash", "wrong")))
    {:ok, _view, html} = live(ctx.conn, "/cards/#{item["id"]}")
    assert html =~ "Judgment unavailable"
    refute html =~ "Lock route:"

    write_record(ctx.recordings, item, :act)
    File.cp!(path, Path.join(ctx.recordings, "duplicate.json"))
    {:ok, _view, html} = live(ctx.conn, "/cards/#{item["id"]}")
    assert html =~ "Multiple saved judgments"
    refute html =~ "Lock route:"

    File.rm!(Path.join(ctx.recordings, "duplicate.json"))
    record = path |> File.read!() |> Jason.decode!()
    File.write!(path, Jason.encode!(put_in(record, ["source_lineage", "kind"], "recorded")))
    {:ok, _view, html} = live(ctx.conn, "/cards/#{item["id"]}")
    assert html =~ "Judgment unavailable"
    refute html =~ "Lock route:"
  end

  test "synthetic data requires local opt-in", ctx do
    item = card(20)
    write_catalog(ctx.catalog, [item])
    write_record(ctx.recordings, item, :act)

    Application.put_env(:ring_the_pen, :workbench,
      catalog_path: ctx.catalog,
      recordings_dir: ctx.recordings,
      allow_synthetic: false
    )

    {:ok, _view, html} = live(ctx.conn, "/cards/#{item["id"]}")
    assert html =~ "Catalog unavailable"
    refute html =~ "Lock route:"
  end

  test "malformed selector input clears the card safely", ctx do
    item = card(20)
    write_catalog(ctx.catalog, [item])
    write_record(ctx.recordings, item, :act)
    {:ok, view, _html} = live(ctx.conn, "/cards/#{item["id"]}")
    assert has_element?(view, ".primary-decision")

    render_change(view, "select", %{"card_id" => %{"bad" => "value"}})
    assert_patch(view, "/")
    refute render(view) =~ "Lock route:"
  end

  defp card(n, index \\ 1) do
    state =
      "priv/jev/fixtures/synthetic/states/unknown-pitch-count.json"
      |> File.read!()
      |> Jason.decode!()
      |> Map.merge(%{"inning" => 6 + index, "w_bvp" => n / (n + 20), "w_prior" => 20 / (n + 20)})

    %{
      "id" => "hook:SYNTHETIC:#{index}",
      "game_id" => "SYNTHETIC",
      "pa_index" => index,
      "synthetic" => true,
      "judgment_state" => state,
      "bvp" => %{
        "n" => n,
        "xbar" => 0.4,
        "m" => 0.33,
        "k_shrink" => 20.0,
        "posterior" => (n * 0.4 + 20 * 0.33) / (n + 20),
        "underqualified" => n < 20
      },
      "samples" => %{"bvp_n" => n, "upcoming_n" => [18, 7, nil]}
    }
  end

  defp write_catalog(path, cards) do
    artifact = %{
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

    File.write!(path, Jason.encode!(artifact))
  end

  defp write_record(dir, item, route) do
    record =
      "priv/jev/fixtures/synthetic/synthetic--unknown-pitch-count.json"
      |> File.read!()
      |> Jason.decode!()
      |> Map.put("state_hash", Questions.state_hash(item["judgment_state"]))
      |> route_answers(route)

    path = Path.join(dir, "#{item["pa_index"]}.json")
    File.write!(path, Jason.encode!(record))
    path
  end

  defp route_answers(record, :review), do: record

  defp route_answers(record, route) do
    selected = if route == :escalate, do: "other", else: "ride"

    choice_probs = %{
      "pull_now" => 0.02,
      "ride" => if(selected == "ride", do: 0.9, else: 0.02),
      "soft_hook" => 0.03,
      "emergency_hook" => 0.03,
      "other" => if(selected == "other", do: 0.9, else: 0.02)
    }

    score_probs = %{"0" => 0.9, "1" => 0.025, "2" => 0.025, "3" => 0.025, "4" => 0.025}

    record
    |> update_in(["answers"], fn answers ->
      answers
      |> update_in(["pull_decision"], fn choice ->
        choice
        |> Map.merge(%{
          "choice" => selected,
          "description" =>
            if(selected == "ride",
              do:
                "The presented state jointly supports letting the pitcher face this plate appearance without restriction.",
              else: "None of the listed removal decisions is supported by the presented state."
            ),
          "confidence" => 0.9,
          "probabilities" => choice_probs
        })
        |> Map.update!("options", fn options ->
          Enum.map(options, &%{&1 | "probability" => choice_probs[&1["option"]]})
        end)
      end)
      |> update_in(["hook_urgency"], fn score ->
        score
        |> Map.merge(%{
          "confidence" => 0.9,
          "score" => 0.25,
          "level" => 0,
          "label" => "calm",
          "description" =>
            "The presented state shows no urgency signal for this plate appearance.",
          "probabilities" => score_probs
        })
        |> Map.update!("levels", fn levels ->
          levels
          |> Enum.with_index()
          |> Enum.map(fn {level, index} ->
            %{level | "probability" => score_probs[to_string(index)]}
          end)
        end)
      end)
      |> update_in(["danger_pa_now"], &Map.merge(&1, %{"noul" => 0.1, "confidence" => 0.9}))
      |> update_in(["danger_window_next3"], &Map.merge(&1, %{"noul" => 0.1, "confidence" => 0.9}))
    end)
    |> update_in(["response", "answers"], fn answers ->
      answers
      |> update_in(
        ["pull_decision"],
        &Map.merge(&1, %{
          "choice" => selected,
          "confidence" => 0.9,
          "probabilities" => choice_probs
        })
      )
      |> update_in(
        ["hook_urgency"],
        &Map.merge(&1, %{
          "confidence" => 0.9,
          "score" => 0.25,
          "probabilities" => score_probs
        })
      )
      |> update_in(["danger_pa_now"], &Map.put(&1, "noul", 0.1))
      |> update_in(["danger_window_next3"], &Map.put(&1, "noul", 0.1))
    end)
  end
end
