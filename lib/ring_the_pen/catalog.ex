defmodule RingThePen.Catalog do
  @moduledoc """
  Trusted boundary for the offline `hook-card/1` artifact.

  `load/1` reads JSON and returns `{:ok, artifact}` only after validation.
  `validate/1` and `validate_card/1` return the original map unchanged on success;
  they never fill unknowns, repair math, reorder cards, or strip forbidden data.
  Errors are `{:error, {:invalid_catalog, message}}`, with file and JSON failures
  tagged `:file` and `:json` respectively. Only a complete artifact validation
  establishes provenance and agreement of the synthetic flags; validating a card
  alone establishes its shape, state boundary, samples and mathematical coherence.

  Source digests are structurally checked, not proof that a source was fetched.
  Historical ingestion must still verify the frozen source manifest. Synthetic
  artifacts stay explicitly flagged and may have no source entries.
  """

  alias RingThePen.{Questions, Shrink}

  @artifact_keys ~w(schema_version formula_version generated_by license purpose provenance synthetic cards)
  @provenance_keys ~w(sources bvp_formula k_display n_upcoming)
  @card_keys ~w(id game_id pa_index synthetic judgment_state bvp samples)
  @bvp_keys ~w(n xbar m k_shrink posterior underqualified)
  @sample_keys ~w(bvp_n upcoming_n)
  @license "Retrosheet data used under the Retrosheet notice (see NOTICE)"
  @purpose "Frozen precomputed hook cards for the Phase H card/lock path: each card pairs an exact judgment_state with its provenance"
  @tolerance 1.0e-12

  @type error :: {:error, {:invalid_catalog, String.t()} | {:file, term()} | {:json, term()}}

  @doc "Reads and validates a JSON file; returns `{:ok, artifact}` or a tagged error."
  @spec load(term()) :: {:ok, map()} | error()
  def load(path) when is_binary(path) do
    case File.read(path) do
      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, artifact} -> validate(artifact)
          {:error, reason} -> {:error, {:json, reason}}
        end

      {:error, reason} ->
        {:error, {:file, reason}}
    end
  end

  def load(_), do: invalid("path must be a string")

  @doc "Validates the entire artifact and returns `{:ok, original_artifact}` or a tagged error."
  @spec validate(term()) :: {:ok, map()} | error()
  def validate(artifact) do
    with :ok <- exact_keys(artifact, @artifact_keys, "artifact"),
         :ok <- check(artifact["schema_version"] === 1, "unsupported schema_version"),
         :ok <-
           check(artifact["formula_version"] === "hook-card/1", "unsupported formula_version"),
         :ok <-
           check(
             artifact["generated_by"] === "scripts/cards.py (RTP-08; offline)",
             "unexpected generated_by"
           ),
         :ok <- check(artifact["license"] === @license, "unexpected license"),
         :ok <- check(artifact["purpose"] === @purpose, "unexpected purpose"),
         :ok <- check(is_boolean(artifact["synthetic"]), "synthetic must be boolean"),
         :ok <- validate_provenance(artifact["provenance"], artifact["synthetic"]),
         :ok <- validate_cards(artifact["cards"], artifact["synthetic"]) do
      {:ok, artifact}
    end
  end

  @doc "Validates one card without artifact provenance; returns `{:ok, original_card}` or a tagged error."
  @spec validate_card(term()) :: {:ok, map()} | error()
  def validate_card(card) do
    with :ok <- exact_keys(card, @card_keys, "card"),
         :ok <- check(nonempty_string?(card["game_id"]), "game_id must be a nonempty string"),
         :ok <-
           check(
             nonnegative_integer?(card["pa_index"]),
             "pa_index must be a nonnegative integer"
           ),
         :ok <-
           check(
             card["id"] === "hook:#{card["game_id"]}:#{card["pa_index"]}",
             "id must be hook:<game_id>:<pa_index>"
           ),
         :ok <- check(is_boolean(card["synthetic"]), "card synthetic must be boolean"),
         :ok <- validate_state(card["judgment_state"]),
         :ok <- validate_bvp(card["bvp"], card["judgment_state"]),
         :ok <- validate_samples(card["samples"], card["bvp"], card["judgment_state"]) do
      {:ok, card}
    end
  end

  defp validate_provenance(provenance, synthetic) do
    with :ok <- exact_keys(provenance, @provenance_keys, "provenance"),
         :ok <- check(provenance["bvp_formula"] === "bvp-shrink/1", "unsupported bvp_formula"),
         :ok <- check(provenance["k_display"] === Shrink.k_display(), "k_display must be 20"),
         :ok <- check(provenance["n_upcoming"] === 3, "n_upcoming must be 3") do
      validate_sources(provenance["sources"], synthetic)
    end
  end

  defp validate_sources(sources, synthetic) when is_list(sources) do
    with :ok <- check(synthetic or sources != [], "real artifacts require source digests"),
         :ok <- each(sources, &validate_source(&1, synthetic)) do
      ids = Enum.map(sources, & &1["id"])
      check(length(Enum.uniq(ids)) == length(ids), "source ids must be unique")
    end
  end

  defp validate_sources(_, _), do: invalid("sources must be a list")

  defp validate_source(source, synthetic) do
    with :ok <- exact_keys(source, ~w(id sha256), "source"),
         :ok <- check(nonempty_string?(source["id"]), "source id must be a nonempty string") do
      check(
        digest?(source["sha256"], synthetic),
        "source sha256 must be 64-character lowercase hex; real digests cannot be placeholders"
      )
    end
  end

  defp validate_cards(cards, synthetic) when is_list(cards) do
    with :ok <-
           each(cards, fn card ->
             with {:ok, _} <- validate_card(card) do
               check(
                 card["synthetic"] === synthetic,
                 "card and artifact synthetic flags disagree"
               )
             end
           end) do
      ids = Enum.map(cards, & &1["id"])

      check(
        ids == Enum.sort(ids) and length(Enum.uniq(ids)) == length(ids),
        "cards must have ordered unique ids"
      )
    end
  end

  defp validate_cards(_, _), do: invalid("cards must be a list")

  defp validate_state(state) do
    case Questions.validate_state(state) do
      :ok ->
        # Questions owns the allowlist; its nonnegative upcoming-number check
        # deliberately does not enforce the catalog's stricter unit-rate bound.
        each(state["upcoming"], fn slot ->
          check(
            is_nil(slot["rate"]) or unit_rate?(slot["rate"]),
            "upcoming rate must be in [0,1] or null"
          )
        end)

      {:error, {:invalid_state, message}} ->
        invalid(message)
    end
  end

  defp validate_bvp(bvp, state) do
    with :ok <- exact_keys(bvp, @bvp_keys, "bvp"),
         :ok <- check(nonnegative_integer?(bvp["n"]), "bvp n must be a nonnegative integer"),
         :ok <-
           check(
             unit_rate?(bvp["xbar"]) and unit_rate?(bvp["m"]) and unit_rate?(bvp["posterior"]),
             "BvP rates must be in [0,1]"
           ),
         :ok <-
           check(
             is_number(bvp["k_shrink"]) and bvp["k_shrink"] > 0,
             "k_shrink must be positive"
           ),
         :ok <-
           check(
             bvp["underqualified"] === Shrink.underqualified?(bvp["n"]),
             "underqualified must equal n < 20"
           ),
         :ok <- check(bvp["m"] == state["prior_rate"], "prior_rate must equal bvp m") do
      validate_math(bvp, state)
    end
  end

  defp validate_math(bvp, state) do
    with {:ok, posterior} <- Shrink.blend(bvp["n"], bvp["xbar"], bvp["m"], bvp["k_shrink"]),
         {:ok, weights} <- Shrink.weights(bvp["n"], bvp["k_shrink"]) do
      check(
        close?(bvp["posterior"], posterior) and close?(state["w_bvp"], weights.w_bvp) and
          close?(state["w_prior"], weights.w_prior),
        "posterior and weights must match the BvP shrink formula"
      )
    else
      {:error, message} -> invalid(message)
    end
  rescue
    ArithmeticError -> invalid("BvP inputs exceed supported numeric range")
  end

  defp validate_samples(samples, bvp, state) do
    with :ok <- exact_keys(samples, @sample_keys, "samples"),
         :ok <- check(samples["bvp_n"] === bvp["n"], "samples.bvp_n must equal bvp.n") do
      expected = Enum.map(state["upcoming"], & &1["n"])

      check(
        samples["upcoming_n"] === expected,
        "samples.upcoming_n must equal upcoming slot counts, preserving nulls"
      )
    end
  end

  defp exact_keys(map, keys, label) when is_map(map) do
    check(
      Enum.sort(Map.keys(map)) == Enum.sort(keys),
      "#{label} keys must be exactly #{inspect(keys)}"
    )
  end

  defp exact_keys(_, _, label), do: invalid("#{label} must be a map")

  defp each(items, validator) do
    Enum.reduce_while(items, :ok, fn item, :ok ->
      case validator.(item) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp nonempty_string?(value), do: is_binary(value) and String.trim(value) != ""
  defp nonnegative_integer?(value), do: is_integer(value) and value >= 0
  defp unit_rate?(value), do: is_number(value) and value >= 0 and value <= 1
  defp close?(left, right), do: abs(left - right) <= @tolerance

  defp digest?(value, synthetic) when is_binary(value) do
    Regex.match?(~r/\A[0-9a-f]{64}\z/, value) and
      (synthetic or length(Enum.uniq(String.graphemes(value))) > 1)
  end

  defp digest?(_, _), do: false
  defp check(true, _), do: :ok
  defp check(false, message), do: invalid(message)
  defp invalid(message), do: {:error, {:invalid_catalog, message}}
end
