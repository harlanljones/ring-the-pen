defmodule RingThePen.Shrink do
  @moduledoc """
  BvP credibility shrink (RTP-06, DEC-7).

  Posterior `= (n * xbar + k_shrink * m) / (n + k_shrink)`, with weights
  `w_bvp = n / (n + k_shrink)` and `w_prior = k_shrink / (n + k_shrink)`.

  The `k=20` pin is split per DEC-7: `k_display/0` (20) is the frozen
  display/underqualified gate and is never the blend constant. `k_shrink` is
  fitted from the artifact; until then the `k_shrink_placeholder/0` (1000 PA)
  applies and every result carries `uncalibrated: true`.

  Pure functions only. Unknown inputs are errors, never defaults: the prior
  `m` and `k_shrink` are explicit arguments.
  """

  @k_display 20
  @k_shrink_placeholder 1000

  @doc "Frozen display/underqualified gate (provisional per DEC-7)."
  @spec k_display() :: 20
  def k_display, do: @k_display

  @doc "Placeholder prior PA, uncalibrated until fitted from the artifact."
  @spec k_shrink_placeholder() :: 1000
  def k_shrink_placeholder, do: @k_shrink_placeholder

  @doc """
  Credibility posterior for one batter-pitcher pair.

  `n` is observed BvP PA, `xbar` the observed rate, `m` the prior mean rate,
  `k_shrink` the prior PA. When `n` is 0 the posterior equals `m` (pass
  `xbar` as `0.0`; its weight is zero).
  """
  @spec blend(non_neg_integer(), float(), float(), number()) ::
          {:ok, float()} | {:error, String.t()}
  def blend(n, xbar, m, k_shrink) do
    with :ok <- validate_n(n),
         :ok <- validate_rate(xbar, "xbar"),
         :ok <- validate_rate(m, "m"),
         :ok <- validate_k(k_shrink) do
      {:ok, (n * xbar + k_shrink * m) / (n + k_shrink)}
    end
  end

  @doc "Returns `{:ok, %{w_bvp: _, w_prior: _}}`; the weights sum to 1."
  @spec weights(non_neg_integer(), number()) ::
          {:ok, %{w_bvp: float(), w_prior: float()}} | {:error, String.t()}
  def weights(n, k_shrink) do
    with :ok <- validate_n(n),
         :ok <- validate_k(k_shrink) do
      k = k_shrink / 1
      {:ok, %{w_bvp: n / (n + k), w_prior: k / (n + k)}}
    end
  end

  @doc "True when the BvP sample is below the display gate (flag, not math)."
  @spec underqualified?(non_neg_integer(), pos_integer()) :: boolean()
  def underqualified?(n, k_display \\ @k_display)

  def underqualified?(n, k_display)
      when is_integer(n) and n >= 0 and is_integer(k_display) and k_display > 0,
      do: n < k_display

  def underqualified?(n, k_display),
    do:
      raise(
        ArgumentError,
        "n and k_display must be nonnegative/positive integers; got #{inspect(n)}, #{inspect(k_display)}"
      )

  @doc """
  Shrinks one pair into its card-ready row: posterior, weights,
  underqualified flag, and the uncalibrated badge.
  """
  @spec apply(non_neg_integer(), float(), float(), number(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def apply(n, xbar, m, k_shrink, opts \\ []) do
    k_display = Keyword.get(opts, :k_display, @k_display)

    with :ok <- validate_n(n),
         {:ok, posterior} <- blend(n, xbar, m, k_shrink),
         {:ok, %{w_bvp: w_bvp, w_prior: w_prior}} <- weights(n, k_shrink),
         true <- is_integer(k_display) and k_display > 0 do
      {:ok,
       %{
         n: n,
         xbar: xbar / 1,
         m: m / 1,
         k_shrink: k_shrink / 1,
         posterior: posterior,
         w_bvp: w_bvp,
         w_prior: w_prior,
         underqualified: n < k_display,
         uncalibrated: true
       }}
    else
      false -> {:error, "k_display must be a positive integer"}
      {:error, _} = error -> error
    end
  end

  defp validate_n(n) when is_integer(n) and n >= 0, do: :ok

  defp validate_n(n),
    do: {:error, "n must be a nonnegative integer of observed BvP PA; got #{inspect(n)}"}

  defp validate_rate(value, _name) when is_number(value) and value >= 0 and value <= 1, do: :ok

  defp validate_rate(value, name),
    do: {:error, "#{name} must be a rate in [0,1]; got #{inspect(value)}"}

  defp validate_k(k) when is_number(k) and k > 0, do: :ok

  defp validate_k(k),
    do: {:error, "k_shrink must be a positive number of prior PA; got #{inspect(k)}"}
end
