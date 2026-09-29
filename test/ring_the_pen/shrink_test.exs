defmodule RingThePen.ShrinkTest do
  use ExUnit.Case, async: true

  alias RingThePen.Shrink

  # Hand-computed fixtures (DEC-7 credibility blend):
  # (20*0.400 + 1000*0.320)/1020 = 328/1020; weights 20/1020 and 1000/1020.
  @n 20
  @xbar 0.400
  @m 0.320
  @k 1000
  @posterior 328 / 1020
  @w_bvp 20 / 1020
  @w_prior 1000 / 1020

  describe "constants" do
    test "k_display is the frozen 20 gate" do
      assert Shrink.k_display() == 20
    end

    test "k_shrink placeholder is 1000 until fitted" do
      assert Shrink.k_shrink_placeholder() == 1000
    end
  end

  describe "blend/4" do
    test "zero sample returns the prior" do
      assert {:ok, posterior} = Shrink.blend(0, 0.0, 0.320, @k)
      assert_in_delta posterior, 0.320, 1.0e-12
    end

    test "hand-computed blend with the placeholder k" do
      assert {:ok, posterior} = Shrink.blend(@n, @xbar, @m, @k)
      assert_in_delta posterior, @posterior, 1.0e-12
    end

    test "blend is monotone in the sample" do
      assert {:ok, low} = Shrink.blend(5, @xbar, @m, @k)
      assert {:ok, high} = Shrink.blend(100, @xbar, @m, @k)
      assert low < high and high < @xbar
    end

    test "rejects unknown or invalid inputs instead of defaulting" do
      assert {:error, _} = Shrink.blend(-1, @xbar, @m, @k)
      assert {:error, _} = Shrink.blend(@n, nil, @m, @k)
      assert {:error, _} = Shrink.blend(@n, 1.5, @m, @k)
      assert {:error, _} = Shrink.blend(@n, @xbar, -0.1, @k)
      assert {:error, _} = Shrink.blend(@n, @xbar, @m, 0)
      assert {:error, _} = Shrink.blend(@n, @xbar, @m, nil)
    end
  end

  describe "weights/2" do
    test "weights sum to 1 across sample sizes" do
      for n <- [0, 1, 19, 20, 21, 100, 2000] do
        assert {:ok, %{w_bvp: w_bvp, w_prior: w_prior}} = Shrink.weights(n, @k)
        assert_in_delta w_bvp + w_prior, 1.0, 1.0e-12
      end
    end

    test "hand-computed weights" do
      assert {:ok, %{w_bvp: w_bvp, w_prior: w_prior}} = Shrink.weights(@n, @k)
      assert_in_delta w_bvp, @w_bvp, 1.0e-12
      assert_in_delta w_prior, @w_prior, 1.0e-12
    end

    test "zero sample carries zero BvP weight" do
      assert {:ok, %{w_bvp: w_bvp, w_prior: w_prior}} = Shrink.weights(0, @k)
      assert_in_delta w_bvp, 0.0, 1.0e-12
      assert_in_delta w_prior, 1.0, 1.0e-12
    end
  end

  describe "underqualified?/2" do
    test "pa_vs 19/20/21 boundary on k_display" do
      assert Shrink.underqualified?(19)
      refute Shrink.underqualified?(20)
      refute Shrink.underqualified?(21)
    end

    test "the gate never changes the posterior" do
      assert {:ok, at_19} = Shrink.blend(19, @xbar, @m, @k)
      assert_in_delta at_19, (19 * @xbar + @k * @m) / (19 + @k), 1.0e-12
    end
  end

  describe "apply/5" do
    test "returns the card-ready row with the uncalibrated badge" do
      assert {:ok, row} = Shrink.apply(@n, @xbar, @m, @k)
      assert_in_delta row.posterior, @posterior, 1.0e-12
      assert_in_delta row.w_bvp + row.w_prior, 1.0, 1.0e-12
      assert row.underqualified == false
      assert row.uncalibrated == true
      assert row.k_shrink == @k / 1
    end

    test "zero-sample row holds the prior and flags underqualified" do
      assert {:ok, row} = Shrink.apply(0, 0.0, 0.310, @k)
      assert_in_delta row.posterior, 0.310, 1.0e-12
      assert row.underqualified == true
    end
  end
end
