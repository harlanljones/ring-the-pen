defmodule Mix.Tasks.Ring.RecordTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  test "reads the requested input state before validating it" do
    directory = Path.join(System.tmp_dir!(), "ring-record-#{System.unique_integer([:positive])}")
    input_path = Path.join(directory, "invalid-state.json")
    output_dir = Path.join(directory, "recordings")
    input = ~s({"not_a_state":true})
    previous_key = System.get_env("TYPESAFE_API_KEY")

    File.mkdir_p!(directory)
    File.write!(input_path, input)

    try do
      System.put_env("TYPESAFE_API_KEY", "test-only-dummy-key")
      Mix.Task.reenable("ring.record")

      error =
        assert_raise Mix.Error, fn ->
          capture_io(fn ->
            Mix.Task.run("ring.record", ["--state", input_path, "--output", output_dir])
          end)
        end

      assert Exception.message(error) =~ "invalid_state"

      refute Exception.message(error) =~
               "cannot read #{Path.join(output_dir, "invalid-state.json")}"

      assert File.read!(input_path) == input
      refute File.exists?(Path.join(output_dir, "invalid-state.json"))
    after
      restore_env("TYPESAFE_API_KEY", previous_key)
      File.rm_rf!(directory)
    end
  end

  test "sends the frozen question pack for a valid state before handling a Jev error" do
    directory = Path.join(System.tmp_dir!(), "ring-record-#{System.unique_integer([:positive])}")
    input_path = Path.join(directory, "valid-state.json")
    output_dir = Path.join(directory, "recordings")

    input =
      Jason.encode!(%{
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
        "upcoming" => [
          %{"n" => 18, "rate" => 0.312},
          %{"n" => 7, "rate" => 0.25},
          %{"n" => nil, "rate" => nil}
        ]
      })

    previous_key = System.get_env("TYPESAFE_API_KEY")
    previous_base_url = Application.fetch_env(:typesafe_api, :base_url)

    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, {{127, 0, 0, 1}, port}} = :inet.sockname(listener)
    server = Task.async(fn -> serve_validation_error(listener) end)

    File.mkdir_p!(directory)
    File.write!(input_path, input)

    try do
      System.put_env("TYPESAFE_API_KEY", "test-only-dummy-key")
      Application.put_env(:typesafe_api, :base_url, "http://127.0.0.1:#{port}")
      Mix.Task.reenable("ring.record")

      error =
        assert_raise Mix.Error, fn ->
          capture_io(fn ->
            Mix.Task.run("ring.record", ["--state", input_path, "--output", output_dir])
          end)
        end

      assert Exception.message(error) =~ "Jev recording failed"
      assert {:ok, request} = Task.yield(server, 5_000)

      assert Map.keys(request["questions"]) |> Enum.sort() ==
               ~w(danger_pa_now danger_window_next3 hook_urgency pull_decision)

      assert File.read!(input_path) == input
      refute File.exists?(Path.join(output_dir, "valid-state.json"))
    after
      restore_env("TYPESAFE_API_KEY", previous_key)
      restore_app_env(:typesafe_api, :base_url, previous_base_url)
      :gen_tcp.close(listener)
      Task.shutdown(server, 1_000)
      File.rm_rf!(directory)
    end
  end

  test "refuses to overwrite an existing recording and preserves it" do
    directory = Path.join(System.tmp_dir!(), "ring-record-#{System.unique_integer([:positive])}")
    input_path = Path.join(directory, "state.json")
    output_dir = Path.join(directory, "recordings")
    output_path = Path.join(output_dir, "state.json")
    input = ~s({"not_a_state":true})
    existing = ~s({"immutable":true})
    previous_key = System.get_env("TYPESAFE_API_KEY")

    File.mkdir_p!(output_dir)
    File.write!(input_path, input)
    File.write!(output_path, existing)

    try do
      System.delete_env("TYPESAFE_API_KEY")
      Mix.Task.reenable("ring.record")

      error =
        assert_raise Mix.Error, fn ->
          capture_io(fn ->
            Mix.Task.run("ring.record", ["--state", input_path, "--output", output_dir])
          end)
        end

      assert Exception.message(error) =~ "refusing to replace immutable recordings"
      assert File.read!(input_path) == input
      assert File.read!(output_path) == existing
    after
      restore_env("TYPESAFE_API_KEY", previous_key)
      File.rm_rf!(directory)
    end
  end

  defp restore_env(name, nil), do: System.delete_env(name)
  defp restore_env(name, value), do: System.put_env(name, value)

  defp restore_app_env(application, key, :error), do: Application.delete_env(application, key)

  defp restore_app_env(application, key, {:ok, value}),
    do: Application.put_env(application, key, value)

  defp serve_validation_error(listener) do
    {:ok, socket} = :gen_tcp.accept(listener)
    request = read_request(socket)
    body = ~s({"detail":"offline test"})

    response =
      "HTTP/1.1 400 Bad Request\r\ncontent-type: application/json\r\ncontent-length: #{byte_size(body)}\r\nconnection: close\r\n\r\n#{body}"

    :ok = :gen_tcp.send(socket, response)
    :ok = :gen_tcp.close(socket)
    request
  end

  defp read_request(socket, buffer \\ "") do
    case :binary.match(buffer, "\r\n\r\n") do
      {offset, 4} ->
        header_size = offset + 4
        headers = binary_part(buffer, 0, offset)
        body = binary_part(buffer, header_size, byte_size(buffer) - header_size)
        [_, length] = Regex.run(~r/(?:\r\n|^)content-length:\s*(\d+)/i, headers)
        content_length = String.to_integer(length)

        if byte_size(body) >= content_length do
          body |> binary_part(0, content_length) |> Jason.decode!()
        else
          receive_request_data(socket, buffer)
        end

      :nomatch ->
        receive_request_data(socket, buffer)
    end
  end

  defp receive_request_data(socket, buffer) do
    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, data} -> read_request(socket, buffer <> data)
      {:error, reason} -> raise "offline TypeSafe API stub failed: #{inspect(reason)}"
    end
  end
end
