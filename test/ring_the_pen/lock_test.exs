defmodule RingThePen.LockTest do
  use ExUnit.Case, async: true

  alias RingThePen.Lock

  defp choice(option, confidence) do
    %{"type" => "choice", "choice" => option, "confidence" => confidence}
  end

  defp score(confidence, level \\ 2, label \\ "warm") do
    %{"type" => "score", "confidence" => confidence, "level" => level, "label" => label}
  end

  defp noul(p), do: %{"type" => "noul", "noul" => p}

  defp answers(choice, score, p_now \\ 0.1, p_next \\ 0.1) do
    %{
      "pull_decision" => choice,
      "hook_urgency" => score,
      "danger_pa_now" => noul(p_now),
      "danger_window_next3" => noul(p_next)
    }
  end

  describe "thresholds" do
    test "values match DEC-5 and stay provisional" do
      assert %{
               choice_act: 0.8,
               choice_review: 0.5,
               score_act: 0.8,
               score_review: 0.5,
               noul_act: 0.85,
               status: "provisional"
             } = Lock.thresholds()
    end
  end

  describe "Choice routing" do
    test "other always escalates, however confident" do
      assert {:ok, %{"route" => "escalate"}} =
               Lock.route(answers(choice("other", 0.99), score(0.9)), underqualified: false)
    end

    test "confidence boundaries 0.8 act / 0.5 review / below escalate" do
      assert {:ok, %{"choice_route" => "act"}} =
               Lock.route(answers(choice("pull_now", 0.8), score(0.9)), underqualified: false)

      assert {:ok, %{"choice_route" => "review"}} =
               Lock.route(answers(choice("pull_now", 0.5), score(0.9)), underqualified: false)

      assert {:ok, %{"choice_route" => "escalate"}} =
               Lock.route(answers(choice("pull_now", 0.49), score(0.9)), underqualified: false)
    end
  end

  describe "Score routing" do
    test "routes on confidence with the same 0.8/0.5 bands" do
      assert {:ok, %{"score_route" => "act"}} =
               Lock.route(answers(choice("ride", 0.9), score(0.8)), underqualified: false)

      assert {:ok, %{"score_route" => "review"}} =
               Lock.route(answers(choice("ride", 0.9), score(0.5)), underqualified: false)

      assert {:ok, %{"score_route" => "escalate"}} =
               Lock.route(answers(choice("ride", 0.9), score(0.49)), underqualified: false)
    end

    test "a confident calm can act (lock routes on certainty, not direction)" do
      assert {:ok, %{"route" => "act", "score_level" => "calm"}} =
               Lock.route(answers(choice("ride", 0.9), score(0.9, 0, "calm")),
                 underqualified: false
               )
    end
  end

  describe "card combination" do
    test "card route is the worst of the Choice/Score routes" do
      assert {:ok, %{"route" => "review"}} =
               Lock.route(answers(choice("ride", 0.9), score(0.6)), underqualified: false)

      assert {:ok, %{"route" => "escalate"}} =
               Lock.route(answers(choice("ride", 0.9), score(0.2)), underqualified: false)
    end

    test "a Noul review pulls act down to review but never escalates" do
      # Noul p=0.5 -> max(0.5, 0.5) = 0.5 < 0.85 -> review.
      assert {:ok, %{"route" => "review"}} =
               Lock.route(answers(choice("ride", 0.9), score(0.9), 0.5, 0.1),
                 underqualified: false
               )

      # Certain Nouls leave a review card on review.
      assert {:ok, %{"route" => "review"}} =
               Lock.route(answers(choice("ride", 0.9), score(0.6), 0.95, 0.95),
                 underqualified: false
               )
    end

    test "Noul answers alone can never produce escalate" do
      for p_now <- [0.0, 0.3, 0.5, 0.9, 1.0], p_next <- [0.0, 0.5, 1.0] do
        assert {:ok, %{"route" => route}} =
                 Lock.route(answers(choice("ride", 0.9), score(0.9), p_now, p_next),
                   underqualified: false
                 )

        assert route in ["act", "review"]
      end
    end

    test "underqualified sample can never act" do
      assert {:ok, %{"route" => "review"}} =
               Lock.route(answers(choice("ride", 0.9), score(0.9)), underqualified: true)

      assert {:ok, %{"route" => "escalate"}} =
               Lock.route(answers(choice("ride", 0.9), score(0.2)), underqualified: true)
    end

    test "underqualified must be explicit, never defaulted" do
      assert {:error, _} = Lock.route(answers(choice("ride", 0.9), score(0.9)))

      assert {:error, _} =
               Lock.route(answers(choice("ride", 0.9), score(0.9)), underqualified: nil)
    end
  end

  describe "code gates override Jev" do
    test "a firing gate forces escalate on a would-be act card" do
      gates = %{"pitch_count" => 84, "pitch_cap" => nil, "injured" => nil, "pen_empty" => true}

      assert {:ok, %{"route" => "escalate", "gates_fired" => ["empty_pen"]}} =
               Lock.route(answers(choice("pull_now", 0.95), score(0.95)),
                 underqualified: false,
                 gates: gates
               )
    end

    test "pitch cap fires only when known" do
      gates = %{"pitch_count" => 100, "pitch_cap" => 100, "injured" => nil, "pen_empty" => nil}

      assert {:ok, %{"route" => "escalate", "gates_fired" => ["pitch_cap"]}} =
               Lock.route(answers(choice("ride", 0.95), score(0.95)),
                 underqualified: false,
                 gates: gates
               )
    end

    test "unknown gates change nothing" do
      assert {:ok, %{"route" => "act", "gates_fired" => []}} =
               Lock.route(answers(choice("ride", 0.9), score(0.9)), underqualified: false)
    end
  end

  describe "fail-closed inputs" do
    test "rejects malformed answers" do
      base = answers(choice("ride", 0.9), score(0.9))

      assert {:error, _} = Lock.route(Map.delete(base, "hook_urgency"), underqualified: false)

      assert {:error, _} =
               Lock.route(%{base | "pull_decision" => choice("trade", 0.9)},
                 underqualified: false
               )

      assert {:error, _} =
               Lock.route(%{base | "pull_decision" => choice("ride", 1.5)}, underqualified: false)

      assert {:error, _} =
               Lock.route(%{base | "danger_pa_now" => noul(2.0)}, underqualified: false)

      assert {:error, _} = Lock.route("answers", underqualified: false)
    end

    test "verdict carries the audit trail and the provisional label" do
      assert {:ok, verdict} =
               Lock.route(answers(choice("soft_hook", 0.7), score(0.85, 3, "pull_window")),
                 underqualified: false
               )

      assert verdict["route"] == "review"
      assert verdict["choice"] == "soft_hook"
      assert verdict["score_level"] == "pull_window"
      assert verdict["thresholds"] == "provisional"
      assert verdict["gates_fired"] == []
    end
  end
end
