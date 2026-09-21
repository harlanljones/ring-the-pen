defmodule RingThePen.Questions do
  @moduledoc """
  Frozen TypeSafe Jev question pack for in-PA hook-card judgments (RTP-09).

  Question ids and options are FROZEN by `docs/PRD.md` v0.1.2 §2 and
  `docs/specs/hook-card.md` §5; the per-option criteria sentences are frozen
  here by this work item. The exported snapshot lives in
  `priv/jev/questions/v1.json` so recorded judgments (RTP-10) can pin the pack.

  Boundary: this module validates and hashes only — it never computes math.
  The judgment state may carry precomputed allowlisted numbers only; a missing
  pitch count is explicit `null`, never `0` (PRD falsifier: blank `nump` as
  pitches). Deterministic hard gates (pitch cap when known, injured, empty
  pen) are code, never a question here.
  """

  @pull_decision TypeSafeAPI.choice(
                   "Judge the supplied precomputed numeric state for this in-PA pitcher-removal decision. Do not calculate or infer any statistic that is not presented.",
                   pull_now:
                     "The presented state jointly supports removing the pitcher before this plate appearance is completed.",
                   ride:
                     "The presented state jointly supports letting the pitcher face this plate appearance without restriction.",
                   soft_hook:
                     "The presented state jointly supports warming a reliever now while leaving the current pitcher in.",
                   emergency_hook:
                     "The presented state jointly supports removing the pitcher immediately, before warm-up is complete, because of what the presented numbers show.",
                   other:
                     "None of the listed removal decisions is supported by the presented state."
                 )

  @hook_urgency TypeSafeAPI.score(
                  "Rate the urgency of the removal decision from the supplied precomputed numeric state only. Do not recompute any sample qualification or rate.",
                  [
                    {"calm",
                     "The presented state shows no urgency signal for this plate appearance."},
                    {"watch",
                     "The presented state shows an early but not immediate urgency signal."},
                    {"warm", "The presented state shows a reliever should be warming now."},
                    {"pull_window",
                     "The presented state shows the optimal removal point is now or this plate appearance."},
                    {"yank",
                     "The presented state shows removal is urgent immediately, this at-bat."}
                  ]
                )

  # Noul danger targets are secondary-only (DEC-5/0008): they can route
  # act/review and never escalate a card on their own. "Danger" is frozen as
  # the batter reaching base safely or forcing in a run.
  @danger_pa_now TypeSafeAPI.noul(
                   "Based only on the supplied precomputed numeric state for this plate appearance, is the current batter likely to reach base safely or force in a run? Do not calculate any probability from the presented numbers; answer from the state as presented.",
                   true: "The current batter reaching base safely or forcing in a run is likely.",
                   false:
                     "The current batter reaching base safely or forcing in a run is not likely."
                 )

  @danger_window_next3 TypeSafeAPI.noul(
                         "Based only on the supplied precomputed numeric state covering the current plate appearance and the next 3 upcoming batters, is any of those 3 upcoming batters likely to reach base safely or force in a run against this pitcher? Do not calculate any probability from the presented numbers; answer from the state as presented.",
                         true:
                           "At least one of the next 3 upcoming batters reaching base safely or forcing in a run is likely.",
                         false:
                           "At least one of the next 3 upcoming batters reaching base safely or forcing in a run is not likely."
                       )

  @state_keys ~w(inning outs runners_on score_diff pitch_count bullpen_state leverage_index w_bvp w_prior prior_rate upcoming)
  @bullpen_states ~w(available limited unknown)
  @upcoming_slots 3
  @upcoming_slot_keys ~w(n rate)
  @weight_tolerance 1.0e-9

  @doc "The frozen question pack, keyed by question id."
  @spec questions() :: keyword()
  def questions do
    [
      pull_decision: @pull_decision,
      hook_urgency: @hook_urgency,
      danger_pa_now: @danger_pa_now,
      danger_window_next3: @danger_window_next3
    ]
  end

  @doc "Noul question ids, frozen; the capture/evaluation tasks resolve these names."
  @spec noul_ids() :: [String.t()]
  def noul_ids, do: ["danger_pa_now", "danger_window_next3"]

  @doc """
  Hash of the frozen question pack (SHA-256 over a canonical, domain-separated
  encoding of each question's id + wire encoding).
  """
  @spec hash(keyword()) :: String.t()
  def hash(questions) when is_list(questions) do
    encoded =
      Enum.map(questions, fn {id, question} ->
        %{"id" => Atom.to_string(id), "question" => question.__struct__.encode(question)}
      end)

    digest("ring-the-pen/questions/v1\n", encoded)
  end

  @doc "Hash of a validated judgment state (SHA-256 over a canonical encoding)."
  @spec state_hash(map()) :: String.t()
  def state_hash(state) when is_map(state), do: digest("ring-the-pen/state/v1\n", state)

  @doc """
  Validates a judgment state against the exact precomputed allowlist. Rejects
  any identity, outcome, oracle, or non-numeric-context field.
  """
  @spec validate_state(map()) :: :ok | {:error, {:invalid_state, String.t()}}
  def validate_state(state) when is_map(state) do
    with :ok <- exact_keys(state, @state_keys, "state"),
         :ok <- validate_integer(state["inning"], 1, :infinity, "inning"),
         :ok <- validate_integer(state["outs"], 0, 2, "outs"),
         :ok <- validate_integer(state["runners_on"], 0, 3, "runners_on"),
         :ok <- validate_integer(state["score_diff"], :infinity, :infinity, "score_diff"),
         :ok <- validate_pitch_count(state["pitch_count"]),
         :ok <- validate_bullpen(state["bullpen_state"]),
         :ok <- validate_optional_number(state["leverage_index"], "leverage_index"),
         :ok <- validate_unit_rate(state["prior_rate"], "prior_rate"),
         :ok <- validate_weights(state["w_bvp"], state["w_prior"]) do
      validate_upcoming(state["upcoming"])
    end
  end

  def validate_state(_), do: {:error, {:invalid_state, "judgment_state must be a map"}}

  # The pitch-count falsifier: unknown is null, never 0. A known count in
  # universe A is a positive integer (pa=1 AND nump>0); `pa=1 AND nump ∈
  # {blank, 0}` is the unknown class, so 0 is never a valid known count.
  defp validate_pitch_count(nil), do: :ok

  defp validate_pitch_count(count) when is_integer(count) and count > 0, do: :ok

  defp validate_pitch_count(count),
    do:
      {:error,
       {:invalid_state,
        "pitch_count must be a positive integer or null (unknown); got #{inspect(count)} — a missing count is never 0"}}

  defp validate_bullpen(state) when state in @bullpen_states, do: :ok

  defp validate_bullpen(other),
    do:
      {:error,
       {:invalid_state,
        "bullpen_state must be one of #{inspect(@bullpen_states)}; got #{inspect(other)}"}}

  defp validate_integer(value, low, high, _name)
       when is_integer(value) and (low == :infinity or value >= low) and
              (high == :infinity or value <= high),
       do: :ok

  defp validate_integer(value, low, high, name),
    do:
      {:error,
       {:invalid_state,
        "#{name} must be an integer in #{range_text(low, high)}; got #{inspect(value)}"}}

  defp validate_optional_number(nil, _name), do: :ok

  defp validate_optional_number(value, _name) when is_number(value) and value >= 0, do: :ok

  defp validate_optional_number(value, name),
    do:
      {:error,
       {:invalid_state, "#{name} must be a nonnegative number or null; got #{inspect(value)}"}}

  defp validate_unit_rate(value, _name)
       when is_number(value) and value >= 0 and value <= 1,
       do: :ok

  defp validate_unit_rate(value, name),
    do: {:error, {:invalid_state, "#{name} must be a number in [0,1]; got #{inspect(value)}"}}

  defp validate_weights(w_bvp, w_prior)
       when is_number(w_bvp) and is_number(w_prior) and w_bvp >= 0 and w_bvp <= 1 and
              w_prior >= 0 and w_prior <= 1 do
    if abs(w_bvp + w_prior - 1) <= @weight_tolerance do
      :ok
    else
      {:error, {:invalid_state, "w_bvp and w_prior must sum to 1 per DEC-7"}}
    end
  end

  defp validate_weights(w_bvp, w_prior),
    do:
      {:error,
       {:invalid_state,
        "w_bvp and w_prior must be numbers in [0,1]; got #{inspect(w_bvp)} and #{inspect(w_prior)}"}}

  defp validate_upcoming(upcoming)
       when is_list(upcoming) and length(upcoming) == @upcoming_slots do
    Enum.reduce_while(upcoming, :ok, fn
      slot, :ok when is_map(slot) ->
        with :ok <- exact_keys(slot, @upcoming_slot_keys, "upcoming slot"),
             :ok <- validate_slot_n(slot["n"]),
             :ok <- validate_optional_number(slot["rate"], "upcoming rate") do
          {:cont, :ok}
        else
          {:error, _} = error -> {:halt, error}
        end

      slot, :ok ->
        {:halt, {:error, {:invalid_state, "upcoming slots must be maps; got #{inspect(slot)}"}}}
    end)
  end

  defp validate_upcoming(upcoming),
    do:
      {:error,
       {:invalid_state,
        "upcoming must be exactly #{@upcoming_slots} batter slots (frozen N=3); got #{inspect(upcoming)}"}}

  defp validate_slot_n(nil), do: :ok

  defp validate_slot_n(n) when is_integer(n) and n >= 0, do: :ok

  defp validate_slot_n(n),
    do:
      {:error,
       {:invalid_state,
        "upcoming BvP sample n must be a nonnegative integer or null; got #{inspect(n)}"}}

  defp exact_keys(map, expected, label) do
    if Enum.sort(Map.keys(map)) == Enum.sort(expected),
      do: :ok,
      else: {:error, {:invalid_state, "#{label} keys must be exactly #{inspect(expected)}"}}
  end

  defp range_text(:infinity, :infinity), do: "the integers"
  defp range_text(low, :infinity), do: "#{low} or more"
  defp range_text(low, high), do: "[#{low}, #{high}]"

  defp digest(prefix, value) do
    "sha256:" <> Base.encode16(:crypto.hash(:sha256, prefix <> canonical(value)), case: :lower)
  end

  defp canonical(value) when is_map(value) do
    value
    |> Enum.map(fn {key, item} -> {to_string(key), item} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map_join(",", fn {key, item} -> Jason.encode!(key) <> ":" <> canonical(item) end)
    |> then(&("{" <> &1 <> "}"))
  end

  defp canonical(value) when is_list(value),
    do: "[" <> Enum.map_join(value, ",", &canonical/1) <> "]"

  defp canonical(value) when is_atom(value) and value not in [true, false, nil],
    do: Jason.encode!(Atom.to_string(value))

  defp canonical(value), do: Jason.encode!(value)
end
