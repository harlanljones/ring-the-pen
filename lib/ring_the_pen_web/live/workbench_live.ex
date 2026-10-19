defmodule RingThePenWeb.WorkbenchLive do
  @moduledoc "Phase H historical hook-card workbench."
  use RingThePenWeb, :live_view

  alias RingThePen.Workbench

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Ring The Pen",
       selected_id: nil,
       workbench: Workbench.open()
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    id = Map.get(params, "id")
    {:noreply, assign(socket, selected_id: id, workbench: Workbench.open(id))}
  end

  @impl true
  def handle_event("select", %{"card_id" => ""}, socket) do
    {:noreply, push_patch(socket, to: ~p"/")}
  end

  def handle_event("select", %{"card_id" => id}, socket) when is_binary(id) do
    {:noreply, push_patch(socket, to: ~p"/cards/#{id}")}
  end

  def handle_event("select", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/")}
  end

  def handle_event("reload", _, socket) do
    {:noreply, assign(socket, workbench: Workbench.open(socket.assigns.selected_id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main id="main-content">
      <header>
        <p class="eyebrow">Phase H · historical · not live</p>
        <h1>Ring The Pen</h1>
        <p>
          Inspect a frozen hook card, its saved typed judgment, and the confidence
          lock's route. The numbers are precomputed in code. This historical
          workbench does not follow a game in real time.
        </p>
        <p :if={@workbench.artifact && @workbench.artifact["synthetic"]} class="badge">
          SYNTHETIC TEST DATA · no historical game represented
        </p>
      </header>

      <section :if={@workbench.cards != []} class="panel" aria-labelledby="card-select-heading">
        <h2 id="card-select-heading">Choose a hook card</h2>
        <form id="card-selection" phx-change="select" aria-label="Select hook card">
          <label for="card-selector">Hook card</label>
          <select id="card-selector" name="card_id">
            <option value="" selected={@selected_id == nil}>Choose a card</option>
            <option
              :for={card <- @workbench.cards}
              value={card["id"]}
              selected={@selected_id == card["id"]}
            >
              {card["id"]}
            </option>
          </select>
        </form>
      </section>

      <section id="workbench-status" class="status" role="status" aria-live="polite">
        <%= if @workbench.status == :ready do %>
          <p>Validated hook card and saved judgment loaded.</p>
        <% else %>
          <h2>{status_heading(@workbench.status)}</h2>
          <p>{status_detail(@workbench.status)}</p>
        <% end %>
        <button type="button" phx-click="reload">Reload catalog and judgments</button>
      </section>

      <%= if @workbench.status == :ready do %>
        <section class="panel" aria-labelledby="lock-route">
          <h2 id="lock-route">Lock route: {@workbench.verdict["route"]}</h2>
          <p :if={@workbench.verdict["route"] == "act"} class="primary-decision">
            Primary decision: {choice_label(@workbench.verdict["choice"])}
          </p>
          <p :if={@workbench.verdict["route"] != "act"}>
            Review all answer probabilities before deciding. The lock does not issue a single recommendation on this route.
          </p>
          <p>
            Choice route: {@workbench.verdict["choice_route"]} · Score route: {@workbench.verdict[
              "score_route"
            ]}
          </p>
          <p>
            Choice confidence: {percent(@workbench.record["answers"]["pull_decision"]["confidence"])} · Score confidence: {percent(
              @workbench.record["answers"]["hook_urgency"]["confidence"]
            )}
          </p>
          <p>
            Confidence thresholds are provisional. Secondary Noul answers may reduce act to review, but never escalate alone.
          </p>
        </section>

        <section class="panel" aria-labelledby="card-heading">
          <h2 id="card-heading">Hook card</h2>
          <p><strong>{@workbench.card["id"]}</strong></p>
          <p>Pitcher: Unknown · Batter: Unknown</p>
          <p>Player names are unavailable for this card.</p>
          <div class="metrics-grid">
            <p>Inning: {@workbench.card["judgment_state"]["inning"]}</p>
            <p>Outs: {@workbench.card["judgment_state"]["outs"]}</p>
            <p>Runners on: {@workbench.card["judgment_state"]["runners_on"]}</p>
            <p>Score difference: {@workbench.card["judgment_state"]["score_diff"]}</p>
            <p>Pitch count: {known(@workbench.card["judgment_state"]["pitch_count"])}</p>
            <p>Leverage index: {known(@workbench.card["judgment_state"]["leverage_index"])}</p>
            <p>Bullpen state: {@workbench.card["judgment_state"]["bullpen_state"]}</p>
          </div>
          <p>An unavailable pitch count stays Unknown.</p>
        </section>

        <section class="panel" aria-labelledby="upcoming-heading">
          <h2 id="upcoming-heading">Next 3 batters</h2>
          <div class="table-wrap">
            <table>
              <caption>Upcoming batters</caption>
              <thead>
                <tr>
                  <th scope="col">Slot</th><th scope="col">Batter</th><th scope="col">
                    BvP sample n
                  </th><th scope="col">Precomputed rate</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={
                  {slot, index} <- Enum.with_index(@workbench.card["judgment_state"]["upcoming"], 1)
                }>
                  <th scope="row">{index}</th>
                  <td>Unknown</td>
                  <td>{known(slot["n"])}</td>
                  <td>{rate(slot["rate"])}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section class="panel" aria-labelledby="bvp-heading">
          <h2 id="bvp-heading">Batter versus pitcher estimate</h2>
          <div class="metrics-grid">
            <p>BvP n: {@workbench.card["bvp"]["n"]}</p>
            <p>Observed rate: {rate(@workbench.card["bvp"]["xbar"])}</p>
            <p>Prior rate: {rate(@workbench.card["bvp"]["m"])}</p>
            <p>Posterior rate: {rate(@workbench.card["bvp"]["posterior"])}</p>
            <p>BvP weight: {percent(@workbench.card["judgment_state"]["w_bvp"])}</p>
            <p>Prior weight: {percent(@workbench.card["judgment_state"]["w_prior"])}</p>
            <p>k_display: {@workbench.artifact["provenance"]["k_display"]} (provisional)</p>
            <p>k_shrink: {shrink_constant(@workbench.card["bvp"]["k_shrink"])}</p>
          </div>
          <p :if={@workbench.card["bvp"]["underqualified"]} class="badge">
            Underqualified BvP sample (n &lt; 20); the lock cannot route act.
          </p>
          <p :if={!@workbench.card["bvp"]["underqualified"]}>
            BvP sample meets the display threshold.
          </p>
          <p>The prior and k_shrink are uncalibrated; these estimates are provisional.</p>
        </section>

        <section class="panel" aria-labelledby="gates-heading">
          <h2 id="gates-heading">Deterministic code gates</h2>
          <div class="metrics-grid">
            <p>Pitch count: {known(@workbench.gates["pitch_count"])}</p>
            <p>Pitch cap: Unknown</p>
            <p>Injury: Unknown</p>
            <p>Empty pen: Unknown</p>
          </div>
          <p>Fired gates: {fired(@workbench.verdict["gates_fired"])}</p>
          <p>
            Unknown gate inputs do not fire a gate. Bullpen availability does not establish whether the pen is empty.
          </p>
        </section>

        <section class="panel" aria-labelledby="answers-heading">
          <h2 id="answers-heading">Saved judgment probabilities</h2>
          <div class="table-wrap">
            <table>
              <caption>Pull decision probabilities</caption>
              <thead>
                <tr>
                  <th scope="col">Decision</th><th scope="col">Probability</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={option <- @workbench.record["answers"]["pull_decision"]["options"]}>
                  <th scope="row">{choice_label(option["option"])}</th>
                  <td>{percent(option["probability"])}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="table-wrap">
            <table>
              <caption>Hook urgency probabilities</caption>
              <thead>
                <tr>
                  <th scope="col">Urgency</th><th scope="col">Probability</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={level <- @workbench.record["answers"]["hook_urgency"]["levels"]}>
                  <th scope="row">{choice_label(level["label"])}</th>
                  <td>{percent(level["probability"])}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <p>
            Current PA danger (secondary): {percent(
              @workbench.record["answers"]["danger_pa_now"]["noul"]
            )} · no danger: {complement(@workbench.record["answers"]["danger_pa_now"]["noul"])} · route {@workbench.verdict[
              "noul_routes"
            ]["danger_pa_now"]}
          </p>
          <p>
            Next 3 danger (secondary): {percent(
              @workbench.record["answers"]["danger_window_next3"]["noul"]
            )} · no danger: {complement(@workbench.record["answers"]["danger_window_next3"]["noul"])} · route {@workbench.verdict[
              "noul_routes"
            ]["danger_window_next3"]}
          </p>
          <p>
            Danger means reaching base safely or forcing in a run. These are saved model answers, not calibrated event probabilities.
          </p>
        </section>

        <section id="audit" class="panel" aria-labelledby="audit-heading">
          <h2 id="audit-heading">Audit trail</h2>
          <dl>
            <dt>state hash</dt><dd><code>{@workbench.record["state_hash"]}</code></dd>
            <dt>questions hash</dt><dd><code>{@workbench.record["questions_hash"]}</code></dd>
            <dt>model</dt><dd>{@workbench.record["model"]}</dd>
            <dt>recorded at</dt><dd>{@workbench.record["recorded_at"]}</dd>
            <dt>lineage</dt><dd>{@workbench.record["source_lineage"]["kind"]}</dd>
            <dt>formula version</dt><dd>{@workbench.artifact["formula_version"]}</dd>
          </dl>
        </section>
      <% end %>

      <footer>
        <p>
          The information used here was obtained free of charge from and is copyrighted by Retrosheet.
          Interested parties may contact Retrosheet at 20 Sunset Rd., Newark, DE 19711.
        </p>
        <p>
          Retrosheet data is historical and delayed; it is never served as live. Phase H is historical.
          No public live feed is redistributed before gate D6 clears. See <a href="/about">About</a>
          for provenance and license status.
        </p>
      </footer>
    </main>
    """
  end

  defp status_heading(:catalog_unavailable), do: "No hook card loaded"
  defp status_heading(:empty), do: "No hook card loaded"
  defp status_heading(:choose_card), do: "Choose a hook card"
  defp status_heading(:card_not_found), do: "Card not found"
  defp status_heading(:no_judgment), do: "No matching saved judgment"
  defp status_heading(:multiple_judgments), do: "Multiple saved judgments"
  defp status_heading(:judgment_unavailable), do: "Judgment unavailable"

  defp status_detail(:catalog_unavailable),
    do:
      "Catalog unavailable. Check the configured historical artifact or local synthetic-data setting."

  defp status_detail(:empty), do: "The catalog contains no hook cards yet."

  defp status_detail(:choose_card),
    do: "Select a card to validate its saved judgment and lock route."

  defp status_detail(:card_not_found),
    do: "The requested card is absent from the validated catalog."

  defp status_detail(:no_judgment), do: "No matching saved judgment exists for this card state."

  defp status_detail(:multiple_judgments),
    do: "Multiple saved judgments match this card state; the workbench cannot choose one."

  defp status_detail(:judgment_unavailable),
    do:
      "Judgment unavailable or invalid. The card cannot be displayed without a validated lock route."

  defp known(nil), do: "Unknown"
  defp known(value), do: to_string(value)

  defp rate(nil), do: "Unknown"
  defp rate(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)

  defp shrink_constant(value) when is_integer(value), do: Integer.to_string(value)

  defp shrink_constant(value) when is_float(value) do
    if value == trunc(value), do: Integer.to_string(trunc(value)), else: Float.to_string(value)
  end

  defp percent(nil), do: "Unknown"
  defp percent(value), do: :erlang.float_to_binary(value * 100.0, decimals: 1) <> "%"

  defp complement(value), do: percent(1.0 - value)

  defp fired([]), do: "None"
  defp fired(reasons), do: Enum.map_join(reasons, ", ", &choice_label/1)

  defp choice_label(value), do: value |> String.replace("_", " ") |> String.capitalize()
end
