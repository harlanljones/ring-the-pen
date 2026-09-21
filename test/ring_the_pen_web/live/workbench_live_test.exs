defmodule RingThePenWeb.WorkbenchLiveTest do
  use RingThePenWeb.ConnCase, async: true

  test "GET / serves the workbench shell over HTTP", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Ring The Pen"
  end

  test "live view mounts and states there is no card loaded", %{conn: conn} do
    {:ok, view, html} = live(conn, "/")

    assert html =~ "Ring The Pen"
    assert html =~ "No hook card loaded"
    assert has_element?(view, "p.eyebrow", "Phase H")
    assert has_element?(view, "section.empty-state")
  end

  test "does not present Retrosheet as live", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "never served as live"
  end
end
