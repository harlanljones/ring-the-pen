defmodule RingThePen.Workbench do
  @moduledoc """
  File-backed Phase H catalog → saved judgment → confidence lock boundary.

  Paths come only from server configuration. A failed step returns no displayable
  card, answer, or verdict. No request at this boundary calls Jev or fetches data.
  """

  alias RingThePen.{Catalog, Judgments, Lock, Questions}

  @local_mode Mix.env() in [:dev, :test]
  @empty %{
    status: :catalog_unavailable,
    cards: [],
    artifact: nil,
    card: nil,
    record: nil,
    verdict: nil,
    gates: nil
  }

  @doc "Opens a selected hook card after all trust boundaries succeed."
  @spec open(String.t() | nil) :: map()
  def open(id \\ nil) do
    config = Application.get_env(:ring_the_pen, :workbench, [])
    catalog_path = Keyword.get(config, :catalog_path, default_catalog_path())

    with {:ok, artifact} <- Catalog.load(catalog_path),
         :ok <- allow_artifact(artifact, config) do
      base = %{@empty | cards: artifact["cards"], artifact: artifact}
      select(base, id, config)
    else
      _ -> @empty
    end
  end

  defp default_catalog_path, do: Application.app_dir(:ring_the_pen, "priv/data/hook_cards.json")

  defp default_recordings_dir,
    do: Application.app_dir(:ring_the_pen, "priv/jev/recordings")

  defp allow_artifact(%{"synthetic" => true}, config) do
    if @local_mode and Keyword.get(config, :allow_synthetic, false) == true,
      do: :ok,
      else: {:error, :synthetic_disabled}
  end

  defp allow_artifact(_, _), do: :ok

  defp select(base, nil, _),
    do: %{base | status: if(base.cards == [], do: :empty, else: :choose_card)}

  defp select(base, id, config) when is_binary(id) do
    case Enum.find(base.cards, &(&1["id"] == id)) do
      nil ->
        %{base | status: :card_not_found}

      card ->
        with {:ok, record} <- matching_record(card, base.artifact, config),
             gates <- gate_inputs(card),
             {:ok, verdict} <-
               Lock.route(record["answers"],
                 underqualified: card["bvp"]["underqualified"],
                 gates: gates
               ) do
          %{base | status: :ready, card: card, record: record, verdict: verdict, gates: gates}
        else
          {:error, status} when is_atom(status) -> %{base | status: status}
          _ -> %{base | status: :judgment_unavailable}
        end
    end
  end

  defp select(base, _, _), do: %{base | status: :card_not_found}

  defp matching_record(card, artifact, config) do
    dir = Keyword.get(config, :recordings_dir, default_recordings_dir())
    state = card["judgment_state"]
    hash = Questions.state_hash(state)

    with {:ok, names} <- list_json_files(dir),
         {:ok, matches} <- find_matches(dir, names, hash),
         {:ok, record} <- one_match(matches),
         {:ok, record} <- Judgments.validate_record(record, state, Questions.questions()),
         :ok <- match_lineage(record, artifact) do
      {:ok, record}
    else
      {:error, :no_match} -> {:error, :no_judgment}
      {:error, :multiple_matches} -> {:error, :multiple_judgments}
      _ -> {:error, :judgment_unavailable}
    end
  end

  defp list_json_files(dir) when is_binary(dir) do
    case File.ls(dir) do
      {:ok, names} -> {:ok, names |> Enum.filter(&String.ends_with?(&1, ".json")) |> Enum.sort()}
      {:error, _} -> {:error, :unavailable}
    end
  end

  defp list_json_files(_), do: {:error, :unavailable}

  defp find_matches(dir, names, hash) do
    Enum.reduce_while(names, {:ok, []}, fn name, {:ok, matches} ->
      path = Path.join(dir, name)

      with true <- File.regular?(path),
           {:ok, json} <- File.read(path),
           {:ok, record} <- Jason.decode(json),
           true <- is_map(record) do
        if record["state_hash"] == hash do
          {:cont, {:ok, [record | matches]}}
        else
          {:cont, {:ok, matches}}
        end
      else
        _ -> {:halt, {:error, :unavailable}}
      end
    end)
  end

  defp one_match([]), do: {:error, :no_match}
  defp one_match([record]), do: {:ok, record}
  defp one_match(_), do: {:error, :multiple_matches}

  defp match_lineage(%{"source_lineage" => %{"kind" => "synthetic"}}, %{
         "synthetic" => true
       }),
       do: :ok

  defp match_lineage(%{"source_lineage" => %{"kind" => "recorded"}}, %{
         "synthetic" => false
       }),
       do: :ok

  defp match_lineage(_, _), do: {:error, :lineage_mismatch}

  defp gate_inputs(card) do
    %{
      "pitch_count" => card["judgment_state"]["pitch_count"],
      "pitch_cap" => nil,
      "injured" => nil,
      "pen_empty" => nil
    }
  end
end
