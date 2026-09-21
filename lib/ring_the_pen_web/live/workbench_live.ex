defmodule RingThePenWeb.WorkbenchLive do
  @moduledoc """
  Phase H workbench shell.

  Intentionally empty of card data: the frozen hook-card artifact is not built
  yet (see ROADMAP RTP-05). This surface renders an honest empty state rather
  than fabricated numbers.
  """
  use RingThePenWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Ring The Pen")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main>
      <header>
        <p class="eyebrow">Phase H · historical · not live</p>
        <h1>Ring The Pen</h1>
        <p>
          An in-PA pitcher-removal workbench. Code assembles a hook card from
          precomputed state, a typed Jev judgment returns a Choice, Score, and
          Noul, and a confidence lock gates the verdict. Math lives in code only.
        </p>
      </header>

      <section class="empty-state" aria-label="No card loaded">
        <h2>No hook card loaded</h2>
        <p>
          The frozen historical artifact is not built yet, so there is nothing to
          judge. This surface shows an explicit empty state instead of any
          invented number.
        </p>
        <p class="connection">
          Next: RTP-05 (Retrosheet universe A ingest) then RTP-08 (frozen hook-card
          artifact).
        </p>
      </section>

      <footer>
        <p>
          Retrosheet data is historical and delayed; it is never served as live.
          No public live feed is redistributed before gate D6 clears.
        </p>
      </footer>
    </main>
    """
  end
end
