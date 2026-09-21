defmodule Mix.Tasks.Ring.Record do
  @shortdoc "Records immutable live Jev judgments for judgment-state JSON files"
  @moduledoc """
  Records real Jev model responses for judgment states (RTP-10).

      mix ring.record --state priv/jev/states/2025-04-02-nYY.json

  Requires `TYPESAFE_API_KEY` in the environment. Writes one immutable JSON
  record per state into `priv/jev/recordings/` and refuses to overwrite an
  existing recording. Recorded files carry `source_lineage.kind = "recorded"`;
  synthetic fixtures under `priv/jev/fixtures/synthetic/` are a different,
  clearly labeled class and are never produced by this task.
  """

  use Mix.Task

  @requirements ["app.start"]
  @default_output "priv/jev/recordings"
  @safe_name ~r/\A[A-Za-z0-9][A-Za-z0-9._-]*\z/

  @impl Mix.Task
  def run(args) do
    {opts, rest, invalid} =
      OptionParser.parse(args, strict: [state: :keep, output: :string], aliases: [s: :state])

    if rest != [] or invalid != [],
      do: Mix.raise("invalid arguments; use --state FILE (repeatable) and/or --output DIR")

    requested = Keyword.get_values(opts, :state)

    if requested == [], do: Mix.raise("at least one --state FILE is required")

    reject_duplicate_selections!(requested)
    output_dir = opts[:output] || @default_output
    destinations = prepare_destinations!(output_dir, requested)

    existing = destinations |> Enum.map(& &1.path) |> Enum.filter(&File.exists?/1)

    if existing != [],
      do: Mix.raise("refusing to replace immutable recordings: " <> Enum.join(existing, ", "))

    client = TypeSafeAPI.new(api_key: api_key!())

    entries =
      Enum.map(destinations, fn destination ->
        state = read_state!(destination.path)
        lineage = %{"kind" => "recorded", "state_file" => destination.source}

        case RingThePen.Judgments.evaluate(client, state, source_lineage: lineage) do
          {:ok, record} ->
            Map.put(destination, :record, record)

          {:error, error} ->
            Mix.raise("Jev recording failed for #{destination.name}: #{inspect(error)}")
        end
      end)

    Enum.each(entries, fn entry ->
      write_immutable!(entry.path, entry.record)
      Mix.shell().info("recorded #{entry.name} -> #{entry.path}")
    end)
  end

  defp api_key! do
    case System.fetch_env("TYPESAFE_API_KEY") do
      {:ok, key} when byte_size(key) > 0 -> key
      _ -> Mix.raise("TYPESAFE_API_KEY is not set; recordings require a live Jev key")
    end
  end

  defp reject_duplicate_selections!(paths) do
    duplicates =
      paths
      |> Enum.frequencies()
      |> Enum.filter(fn {_path, count} -> count > 1 end)
      |> Enum.map(&elem(&1, 0))

    if duplicates != [], do: Mix.raise("duplicate --state paths: #{Enum.join(duplicates, ", ")}")
  end

  defp prepare_destinations!(output_dir, paths) do
    Enum.map(paths, fn source ->
      name = Path.basename(source, Path.extname(source))

      unless Regex.match?(@safe_name, name) and name not in [".", ".."],
        do: Mix.raise("unsafe state file name: #{inspect(name)}")

      path = Path.join(output_dir, name <> ".json")
      expanded_dir = Path.expand(output_dir)

      if Path.expand(path) != Path.join(expanded_dir, name <> ".json"),
        do: Mix.raise("unsafe recording destination: #{inspect(path)}")

      %{source: source, name: name, path: path}
    end)
  end

  defp read_state!(source) do
    with {:ok, body} <- File.read(source),
         {:ok, state} <- Jason.decode(body) do
      state
    else
      {:error, %Jason.DecodeError{} = error} ->
        Mix.raise("#{source} is not valid JSON: #{Exception.message(error)}")

      {:error, reason} ->
        Mix.raise("cannot read #{source}: #{inspect(reason)}")
    end
  end

  defp write_immutable!(path, record) do
    File.mkdir_p!(Path.dirname(path))

    case File.open(path, [:write, :exclusive, :utf8]) do
      {:ok, device} ->
        IO.write(device, Jason.encode!(record, pretty: true) <> "\n")
        File.close(device)

      {:error, reason} ->
        Mix.raise("cannot write #{path}: #{inspect(reason)}")
    end
  end
end
