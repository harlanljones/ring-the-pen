defmodule RingThePen.Gates do
  @moduledoc """
  Deterministic hard code gates (RTP-11, D3).

  Pitch cap (only when known), injured pitcher, and empty pen are code, never
  Jev: any firing gate forces the card to `escalate` with the gate reason, and
  no Jev answer can override it. Unknown inputs never fire a gate — a missing
  pitch count is unknown (`nil`), never 0, and unknown availability is never
  defaulted to "available".

  A gate cannot be expressed as a Noul: the input schema accepts exactly the
  four gate keys with strict types and rejects anything else.
  """

  @gate_keys ~w(pitch_count pitch_cap injured pen_empty)

  @doc """
  Evaluates the gate inputs.

  Returns `{:ok, %{fired: [...], override: nil | "escalate"}}`. `fired` lists
  the gate reasons (`"pitch_cap"`, `"injured"`, `"empty_pen"`); when non-empty
  the override is `"escalate"`.
  """
  @spec evaluate(map()) :: {:ok, map()} | {:error, String.t()}
  def evaluate(inputs) when is_map(inputs) do
    with :ok <- exact_keys(inputs),
         :ok <- validate_count(inputs["pitch_count"], "pitch_count"),
         :ok <- validate_count(inputs["pitch_cap"], "pitch_cap"),
         :ok <- validate_flag(inputs["injured"], "injured"),
         :ok <- validate_flag(inputs["pen_empty"], "pen_empty") do
      fired =
        []
        |> maybe_pitch_cap(inputs["pitch_count"], inputs["pitch_cap"])
        |> maybe_fire(inputs["injured"], "injured")
        |> maybe_fire(inputs["pen_empty"], "empty_pen")

      override = if fired == [], do: nil, else: "escalate"
      {:ok, %{fired: fired, override: override}}
    end
  end

  def evaluate(_), do: {:error, "gate inputs must be a map"}

  defp maybe_pitch_cap(fired, count, cap)
       when is_integer(count) and is_integer(cap) and count >= cap,
       do: ["pitch_cap" | fired]

  defp maybe_pitch_cap(fired, _count, _cap), do: fired

  defp maybe_fire(fired, true, reason), do: [reason | fired]
  defp maybe_fire(fired, _value, _reason), do: fired

  defp exact_keys(inputs) do
    unknown = Map.keys(inputs) -- @gate_keys

    if unknown == [] and Enum.all?(@gate_keys, &Map.has_key?(inputs, &1)) do
      :ok
    else
      {:error,
       "gate inputs must be exactly #{inspect(@gate_keys)}; a gate is code and can never be expressed as a Noul"}
    end
  end

  # Unknown pitch counts are nil, never 0: 0 is rejected, not coerced.
  defp validate_count(nil, _name), do: :ok
  defp validate_count(value, _name) when is_integer(value) and value > 0, do: :ok

  defp validate_count(value, name),
    do: {:error, "#{name} must be a positive integer or null (unknown); got #{inspect(value)}"}

  defp validate_flag(nil, _name), do: :ok
  defp validate_flag(value, _name) when is_boolean(value), do: :ok

  defp validate_flag(value, name),
    do: {:error, "#{name} must be a boolean or null (unknown); got #{inspect(value)}"}
end
