defmodule RingThePen.Lock do
  @moduledoc """
  Confidence lock (RTP-11, D4, DEC-5/0008).

  Routes each card to `"act" | "review" | "escalate"` from the validated
  judgment record's serialized answers. The lock routes on answer
  **certainty**, never on direction: Choice and Score route on their
  `confidence`, Noul on `max(p, 1 - p)`. The judged direction (Choice option,
  Score level) is carried in the verdict for audit and display, not routed on
  — a confident `calm` must be able to `act` (ride), and an uncertain `yank`
  must not.

  Rules (thresholds provisional per DEC-5 until a D5 report exists):

  - Choice: `other` → escalate; else confidence ≥ 0.80 → act, ≥ 0.50 →
    review, else escalate.
  - Score: confidence ≥ 0.80 → act, ≥ 0.50 → review, else escalate.
  - Noul: `max(p, 1-p)` ≥ 0.85 → act, else review — never escalate alone.
  - Card route = worst of the Choice/Score routes; a Noul `review` can pull
    `act` down to `review` but can never escalate.
  - An underqualified sample (D1 `k_display`) can never `act`.
  - Hard code gates (`RingThePen.Gates`) force `escalate` and are not
    overridable by Jev. The lock may escalate but never fabricates a verdict.
  """

  alias RingThePen.Gates

  @choice_options ~w(pull_now ride soft_hook emergency_hook other)
  @answer_ids ~w(pull_decision hook_urgency danger_pa_now danger_window_next3)

  @doc "Provisional lock thresholds (DEC-5/0008)."
  @spec thresholds() :: map()
  def thresholds do
    %{
      choice_act: 0.8,
      choice_review: 0.5,
      score_act: 0.8,
      score_review: 0.5,
      noul_act: 0.85,
      status: "provisional"
    }
  end

  @doc """
  Routes a card from its serialized answers.

  Options: `:underqualified` (required boolean — the D1 `k_display` flag is
  card state, never defaulted) and `:gates` (code-gate inputs for
  `RingThePen.Gates.evaluate/1`; unknown when absent).
  """
  @spec route(map(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def route(answers, opts \\ [])

  def route(answers, opts) when is_map(answers) do
    with :ok <- exact_answer_ids(answers),
         {:ok, choice_route, choice} <- choice_route(answers["pull_decision"]),
         {:ok, score_route, score} <- score_route(answers["hook_urgency"]),
         {:ok, noul_routes} <- noul_routes(answers),
         {:ok, underqualified} <- underqualified_opt(opts),
         {:ok, %{fired: fired, override: override}} <-
           Gates.evaluate(gate_inputs(opts)) do
      base = worst(choice_route, score_route)

      after_noul =
        if base == "act" and Enum.any?(Map.values(noul_routes), &(&1 == "review")),
          do: "review",
          else: base

      after_sample = if after_noul == "act" and underqualified, do: "review", else: after_noul
      final = if override == "escalate", do: "escalate", else: after_sample

      {:ok,
       %{
         "route" => final,
         "choice_route" => choice_route,
         "score_route" => score_route,
         "noul_routes" => noul_routes,
         "choice" => choice,
         "score_level" => score,
         "gates_fired" => fired,
         "underqualified" => underqualified,
         "thresholds" => "provisional"
       }}
    end
  end

  def route(_, _), do: {:error, "lock answers must be a map"}

  defp choice_route(%{"type" => "choice", "choice" => choice, "confidence" => confidence})
       when choice in @choice_options and is_number(confidence) and confidence >= 0 and
              confidence <= 1 do
    route =
      cond do
        choice == "other" -> "escalate"
        confidence >= thresholds().choice_act -> "act"
        confidence >= thresholds().choice_review -> "review"
        true -> "escalate"
      end

    {:ok, route, choice}
  end

  defp choice_route(_),
    do:
      {:error,
       "pull_decision must be a choice answer with a frozen option and confidence in [0,1]"}

  defp score_route(%{"type" => "score", "confidence" => confidence, "level" => level} = answer)
       when is_number(confidence) and confidence >= 0 and confidence <= 1 and is_integer(level) do
    route =
      cond do
        confidence >= thresholds().score_act -> "act"
        confidence >= thresholds().score_review -> "review"
        true -> "escalate"
      end

    {:ok, route, answer["label"]}
  end

  defp score_route(_),
    do: {:error, "hook_urgency must be a score answer with a level and confidence in [0,1]"}

  defp noul_routes(answers) do
    ids = @answer_ids -- ["pull_decision", "hook_urgency"]

    Enum.reduce_while(ids, {:ok, %{}}, fn id, {:ok, acc} ->
      case answers[id] do
        %{"type" => "noul", "noul" => p} when is_number(p) and p >= 0 and p <= 1 ->
          {:cont, {:ok, Map.put(acc, id, noul_route(p))}}

        _ ->
          {:halt, {:error, "#{id} must be a Noul answer with probability in [0,1]"}}
      end
    end)
  end

  defp noul_route(p) do
    if max(p, 1 - p) >= thresholds().noul_act, do: "act", else: "review"
  end

  defp underqualified_opt(opts) do
    case Keyword.fetch(opts, :underqualified) do
      {:ok, value} when is_boolean(value) ->
        {:ok, value}

      _ ->
        {:error,
         "underqualified must be an explicit boolean (D1 k_display flag is card state, never defaulted)"}
    end
  end

  defp gate_inputs(opts) do
    case Keyword.get(opts, :gates) do
      nil -> %{"pitch_count" => nil, "pitch_cap" => nil, "injured" => nil, "pen_empty" => nil}
      inputs -> inputs
    end
  end

  defp exact_answer_ids(answers) do
    if Enum.sort(Map.keys(answers)) == Enum.sort(@answer_ids) do
      :ok
    else
      {:error, "lock answers must carry exactly #{inspect(@answer_ids)}"}
    end
  end

  defp worst("escalate", _), do: "escalate"
  defp worst(_, "escalate"), do: "escalate"
  defp worst("review", _), do: "review"
  defp worst(_, "review"), do: "review"
  defp worst("act", "act"), do: "act"
end
