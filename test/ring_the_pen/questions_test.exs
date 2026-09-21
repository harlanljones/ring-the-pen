defmodule RingThePen.QuestionsTest do
  use ExUnit.Case, async: true

  alias RingThePen.Questions
  alias TypeSafeAPI.Question.{Choice, Noul, Score}

  # All numbers below are precomputed context code would hand to Jev. None of
  # them is computed by, or inside, Jev.
  @valid_upcoming [
    %{"n" => 18, "rate" => 0.312},
    %{"n" => 7, "rate" => 0.25},
    %{"n" => nil, "rate" => nil}
  ]

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
    "upcoming" => @valid_upcoming
  }

  @base_questions Questions.questions()

  describe "frozen question pack" do
    test "exposes exactly the four PRD questions with the frozen ids" do
      assert Keyword.keys(@base_questions) ==
               [:pull_decision, :hook_urgency, :danger_pa_now, :danger_window_next3]
    end

    test "pull_decision is a Choice with the five frozen options including other" do
      assert {:pull_decision, %Choice{criteria: options}} =
               List.keyfind(@base_questions, :pull_decision, 0)

      assert Enum.map(options, &elem(&1, 0)) ==
               [:pull_now, :ride, :soft_hook, :emergency_hook, :other]

      # Falsifier guard: `other` must be present so Jev can decline every listed option.
      assert Enum.any?(options, fn {id, text} -> id == :other and is_binary(text) end)
    end

    test "hook_urgency is a Score with the five frozen levels" do
      assert {:hook_urgency, %Score{levels: levels}} =
               List.keyfind(@base_questions, :hook_urgency, 0)

      assert Enum.map(levels, &Score.label/1) == ["calm", "watch", "warm", "pull_window", "yank"]
    end

    test "both Noul questions are secondary-only danger targets with frozen criteria text" do
      assert {:danger_pa_now, %Noul{instructions: now_text, criteria: now_criteria}} =
               List.keyfind(@base_questions, :danger_pa_now, 0)

      assert {:danger_window_next3, %Noul{instructions: window_text, criteria: window_criteria}} =
               List.keyfind(@base_questions, :danger_window_next3, 0)

      assert is_binary(now_text) and is_binary(window_text)
      assert %{true: t1, false: f1} = now_criteria
      assert is_binary(t1) and is_binary(f1)
      assert %{true: t2, false: f2} = window_criteria
      assert is_binary(t2) and is_binary(f2)
      # The window Noul must state its horizon as the frozen N=3 upcoming batters.
      assert window_text =~ "3"
    end

    test "no question encodes a deterministic code gate (pitch cap / injury / empty pen)" do
      serialized =
        Enum.map_join(@base_questions, "\n", fn {_id, q} ->
          q.__struct__.encode(q) |> inspect(limit: :infinity)
        end)

      refute serialized =~ "pitch cap"
      refute serialized =~ "injured"
      refute serialized =~ "empty pen"
    end
  end

  describe "judgment_state allowlist" do
    test "accepts the precomputed allowlisted state" do
      assert :ok = Questions.validate_state(@valid_state)
    end

    test "rejects any identity, outcome, or oracle field" do
      forbidden = [
        {"player_name", "Shohei Ohtani"},
        {"pitcher_id", 660_271},
        {"batter_names", ["Mookie Betts", "Freddie Freeman", "Will Smith"]},
        {"team", "LAD"},
        {"year", 2026},
        {"next_pa_outcome", "strikeout"},
        {"pa_result", "single"},
        {"runs_allowed_next3", 2},
        {"oracle", true},
        {"hit_probability", 0.4}
      ]

      for {key, value} <- forbidden do
        assert {:error, {:invalid_state, _}} =
                 Questions.validate_state(Map.put(@valid_state, key, value)),
               "expected #{key} to be rejected"
      end
    end

    test "rejects a state missing an allowlisted field" do
      for key <- Map.keys(@valid_state) do
        assert {:error, {:invalid_state, _}} =
                 Questions.validate_state(Map.delete(@valid_state, key)),
               "expected missing #{key} to be rejected"
      end
    end

    test "a missing pitch count is explicit unknown (null), never 0" do
      assert :ok = Questions.validate_state(%{@valid_state | "pitch_count" => nil})

      assert {:error, {:invalid_state, _}} =
               Questions.validate_state(%{@valid_state | "pitch_count" => 0})

      assert {:error, {:invalid_state, _}} =
               Questions.validate_state(%{@valid_state | "pitch_count" => "unknown"})

      assert {:error, {:invalid_state, _}} =
               Questions.validate_state(%{@valid_state | "pitch_count" => -1})
    end

    test "rejects malformed precomputed values" do
      bad_states = [
        %{@valid_state | "inning" => 0},
        %{@valid_state | "outs" => 3},
        %{@valid_state | "runners_on" => 4},
        %{@valid_state | "bullpen_state" => "fine"},
        %{@valid_state | "bullpen_state" => nil},
        %{@valid_state | "leverage_index" => "high"},
        %{@valid_state | "w_bvp" => nil},
        %{@valid_state | "w_prior" => 0.4},
        %{@valid_state | "prior_rate" => 1.5},
        %{@valid_state | "score_diff" => 1.5},
        %{@valid_state | "upcoming" => List.delete_at(@valid_upcoming, 0)},
        %{@valid_state | "upcoming" => @valid_upcoming ++ [%{"n" => 1, "rate" => 0.1}]},
        %{
          @valid_state
          | "upcoming" => [%{"n" => 5, "rate" => 0.3, "batter" => "x"} | tl(@valid_upcoming)]
        },
        %{@valid_state | "upcoming" => [%{"n" => 5, "rate" => "hot"} | tl(@valid_upcoming)]},
        %{@valid_state | "upcoming" => [%{"n" => -1, "rate" => 0.3} | tl(@valid_upcoming)]}
      ]

      for state <- bad_states do
        assert {:error, {:invalid_state, _}} = Questions.validate_state(state)
      end
    end

    test "rejects non-map states" do
      assert {:error, {:invalid_state, _}} = Questions.validate_state(nil)
      assert {:error, {:invalid_state, _}} = Questions.validate_state("state")
    end
  end

  describe "hashing" do
    test "question hash is deterministic, domain-separated, and changes if criteria change" do
      hash = Questions.hash(@base_questions)
      assert hash == Questions.hash(@base_questions)
      assert hash =~ ~r/^sha256:[0-9a-f]{64}$/

      refute Questions.hash(@base_questions) == Questions.state_hash(@valid_state)

      assert Questions.state_hash(@valid_state) =~ ~r/^sha256:[0-9a-f]{64}$/

      assert Questions.state_hash(@valid_state) !=
               Questions.state_hash(%{@valid_state | "pitch_count" => 85})
    end

    test "state hash changes when any precomputed value changes" do
      base = Questions.state_hash(@valid_state)

      changes = [
        %{@valid_state | "pitch_count" => nil},
        %{@valid_state | "leverage_index" => nil},
        %{
          @valid_state
          | "upcoming" => List.replace_at(@valid_upcoming, 0, %{"n" => 19, "rate" => 0.312})
        },
        %{@valid_state | "bullpen_state" => "unknown"}
      ]

      for changed <- changes do
        refute Questions.state_hash(changed) == base
      end
    end
  end
end
