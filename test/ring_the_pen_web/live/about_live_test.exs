defmodule RingThePenWeb.AboutLiveTest do
  use RingThePenWeb.ConnCase, async: true

  test "GET /about serves the live About page", %{conn: conn} do
    conn = get(conn, "/about")
    assert html_response(conn, 200) =~ "About Ring The Pen"

    {:ok, view, html} = live(conn, "/about")
    assert html =~ "Ring The Pen"
    assert has_element?(view, "main#main-content")
    assert has_element?(view, "h1", "About Ring The Pen")
  end

  test "explains the card formulas and credibility blend", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/about")
    text = visible_text(html)

    assert text =~ "hook-card/1"
    assert text =~ "bvp-shrink/1"
    assert text =~ "re24-leverage/1"
    assert text =~ "(n × x̄ + k_shrink × m) / (n + k_shrink)"
    assert text =~ "w_bvp = n / (n + k_shrink)"
    assert text =~ "w_prior = k_shrink / (n + k_shrink)"
    assert text =~ "k_display = 20"
    assert text =~ "k_shrink ≈ 1000"
    assert text =~ "m"
    assert text =~ "N = 3"
    assert text =~ "underqualified"
    assert text =~ "uncalibrated"
  end

  test "labels the display gate provisional and separate from the shrink placeholder", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, "/about")
    text = visible_text(html)

    assert text =~ "Display gate · provisional"
    assert text =~ "k_display = 20"
    assert text =~ "k_shrink ≈ 1000 PA"
    assert text =~ "uncalibrated placeholder until the value is fitted"
  end

  test "distinguishes the intended prior method from current verified inputs", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/about")
    text = visible_text(html)

    assert text =~ "intended prior method"
    assert text =~ "3-year Marcel 5/4/3"
    assert text =~ "career-to-date"
    assert text =~ "artifact freshness date"
    assert text =~ "real prior extraction and pair wiring are pending"
    refute text =~ "The prior is built from"
    assert text =~ "no verified real prior"
  end

  test "documents current lock thresholds and keeps their provisional status", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/about")
    text = visible_text(html)
    thresholds = RingThePen.Lock.thresholds()

    assert thresholds.status == "provisional"
    assert text =~ "Choice"
    assert text =~ "Score"
    assert text =~ "Noul"
    assert text =~ "#{thresholds.choice_act}"
    assert text =~ "#{thresholds.choice_review}"
    assert text =~ "#{thresholds.noul_act}"
    assert text =~ "provisional"
    assert text =~ "other"
    assert text =~ "underqualified"
    assert text =~ "unknown pitch count remains unknown"
    assert text =~ "never treated as zero"
  end

  test "shows the required Retrosheet attribution and historical boundary", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/about")
    text = visible_text(html)

    assert text =~
             "The information used here was obtained free of charge from and is copyrighted by Retrosheet. Interested parties may contact Retrosheet at 20 Sunset Rd., Newark, DE 19711."

    assert text =~ "historical and delayed"
    assert text =~ "never served or described as live"
    assert text =~ "source SHA-256 digests"
    assert text =~ "pinned"
  end

  test "states the H, L, and P scope and latency and evaluation limits", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/about")
    text = visible_text(html)

    assert text =~ "Phase H"
    assert text =~ "Phase L"
    assert text =~ "single-user/password"
    assert text =~ "individual, non-commercial, non-bulk"
    assert text =~ "polite polling"
    assert text =~ "Phase P"
    assert text =~ "D6"
    assert text =~ "blocked"
    assert text =~ "written authorization"
    assert text =~ "licensed feed"
    assert text =~ "delayed box"
    assert text =~ "sim-live"
    assert text =~ "without a full page reload"
    assert text =~ "pitch release"
    assert text =~ "D7"
    assert text =~ "evaluation report"
    assert text =~ "no accuracy claim"
    refute text =~ "instant from pitch"
    assert text =~ "No public-live service or release is claimed here"
  end

  defp visible_text(html) do
    html
    |> String.replace(~r/<[^>]*>/u, " ")
    |> String.replace("&#39;", "'")
    |> String.replace(~r/\s+/u, " ")
  end
end
