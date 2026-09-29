defmodule RingThePen.GatesTest do
  use ExUnit.Case, async: true

  alias RingThePen.Gates

  @unknown %{"pitch_count" => nil, "pitch_cap" => nil, "injured" => nil, "pen_empty" => nil}

  describe "pitch cap (known only)" do
    test "fires when a known count reaches a known cap" do
      inputs = %{@unknown | "pitch_count" => 100, "pitch_cap" => 100}
      assert {:ok, %{fired: ["pitch_cap"], override: "escalate"}} = Gates.evaluate(inputs)
    end

    test "fires when a known count exceeds the cap" do
      inputs = %{@unknown | "pitch_count" => 112, "pitch_cap" => 100}
      assert {:ok, %{fired: ["pitch_cap"], override: "escalate"}} = Gates.evaluate(inputs)
    end

    test "does not fire below the cap" do
      inputs = %{@unknown | "pitch_count" => 84, "pitch_cap" => 100}
      assert {:ok, %{fired: [], override: nil}} = Gates.evaluate(inputs)
    end

    test "unknown count or cap never fires (unknown is never 0)" do
      assert {:ok, %{fired: [], override: nil}} = Gates.evaluate(@unknown)

      assert {:ok, %{fired: [], override: nil}} =
               Gates.evaluate(%{@unknown | "pitch_cap" => 100})

      assert {:ok, %{fired: [], override: nil}} =
               Gates.evaluate(%{@unknown | "pitch_count" => 120})
    end

    test "a zero pitch count is rejected, not coerced" do
      assert {:error, _} = Gates.evaluate(%{@unknown | "pitch_count" => 0, "pitch_cap" => 100})
    end
  end

  describe "injured / empty pen" do
    test "injured fires" do
      assert {:ok, %{fired: ["injured"], override: "escalate"}} =
               Gates.evaluate(%{@unknown | "injured" => true})
    end

    test "empty pen fires" do
      assert {:ok, %{fired: ["empty_pen"], override: "escalate"}} =
               Gates.evaluate(%{@unknown | "pen_empty" => true})
    end

    test "false or unknown never fires (never defaulted to available)" do
      assert {:ok, %{fired: [], override: nil}} = Gates.evaluate(@unknown)

      assert {:ok, %{fired: [], override: nil}} =
               Gates.evaluate(%{@unknown | "injured" => false, "pen_empty" => false})
    end

    test "multiple gates fire together" do
      inputs = %{@unknown | "injured" => true, "pen_empty" => true}

      assert {:ok, %{fired: fired, override: "escalate"}} = Gates.evaluate(inputs)
      assert Enum.sort(fired) == ["empty_pen", "injured"]
    end
  end

  describe "falsifier: a gate is code and can never be a Noul" do
    test "Noul-shaped input is rejected" do
      noul_like = Map.put(@unknown, "danger_pa_now", %{"type" => "noul", "noul" => 0.9})
      assert {:error, _} = Gates.evaluate(noul_like)
    end

    test "missing gate keys are rejected" do
      assert {:error, _} = Gates.evaluate(%{"pitch_count" => 100})
      assert {:error, _} = Gates.evaluate("gates")
    end

    test "mistyped flags are rejected" do
      assert {:error, _} = Gates.evaluate(%{@unknown | "injured" => "yes"})
      assert {:error, _} = Gates.evaluate(%{@unknown | "pitch_cap" => "100"})
    end
  end
end
