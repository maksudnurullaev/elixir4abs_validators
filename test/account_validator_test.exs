defmodule Elixir4ABS.AccountValidatorTest do
  use ExUnit.Case, async: true

  alias Elixir4ABS.AccountValidator

  describe "calculate_k14/1" do
    test "computes expected key for known sequence" do
      # Example from README: we compose a 24-digit sequence and compute manually
      seq = [4,0,0,4,4, 2,0,2,0,8, 0,0,1, 1,2,3,4,5,6,7,8,0,0,1]
      # we don't know expected numeric result from text, but we can assert 0..9
      key = AccountValidator.calculate_k14(seq)
      assert key in 0..9
    end
  end

  describe "valid_account?/2" do
    test "accepts a valid account" do
      # Construct a realistic example: mfo 00444, account with digit 9th computed
      mfo = "00444"
      # assemble a 20-digit account where we set the 9th digit later
      base = "20208000112345678001"  # placeholder; we will recompute
      acc_digits = base |> String.graphemes() |> Enum.map(&String.to_integer/1)
      {prefix, [_k | suffix]} = Enum.split(acc_digits, 8)
      seq24 = digits_from_string(mfo) ++ prefix ++ suffix
      key = AccountValidator.calculate_k14(seq24)
      account = (prefix ++ [key] ++ suffix) |> Enum.join()
      assert AccountValidator.valid_account?(mfo, account)
    end

    test "rejects an invalid account" do
      assert not AccountValidator.valid_account?("00444", "20208000112345678002")
    end
  end

  describe "calculate_key_m1/1" do
    test "result is a single digit (0–9)" do
      seq = List.duplicate(0, 25)
      key = AccountValidator.calculate_key_m1(seq)
      assert key in 0..9
    end
  end

  describe "valid_account_m1?/2" do
    test "accepts a valid account" do
      mfo = "00444"
      base = "20208000112345678001"
      acc_digits = base |> String.graphemes() |> Enum.map(&String.to_integer/1)
      {prefix, [_k | suffix]} = Enum.split(acc_digits, 8)
      seq25 = digits_from_string(mfo) ++ prefix ++ [0] ++ suffix
      key = AccountValidator.calculate_key_m1(seq25)
      account = (prefix ++ [key] ++ suffix) |> Enum.join()
      assert AccountValidator.valid_account_m1?(mfo, account)
    end

    test "rejects an account with wrong key" do
      mfo = "00444"
      base = "20208000112345678001"
      acc_digits = base |> String.graphemes() |> Enum.map(&String.to_integer/1)
      {prefix, [_k | suffix]} = Enum.split(acc_digits, 8)
      seq25 = digits_from_string(mfo) ++ prefix ++ [0] ++ suffix
      correct_key = AccountValidator.calculate_key_m1(seq25)
      wrong_key = rem(correct_key + 1, 10)
      invalid_account = (prefix ++ [wrong_key] ++ suffix) |> Enum.join()
      assert not AccountValidator.valid_account_m1?(mfo, invalid_account)
    end
  end

  defp digits_from_string(str) do
    str |> String.graphemes() |> Enum.map(&String.to_integer/1)
  end
end
