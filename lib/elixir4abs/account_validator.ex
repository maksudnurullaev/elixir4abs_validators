defmodule Elixir4ABS.AccountValidator do
  @moduledoc """
  Валидация и вычисление контрольного ключа для банковских счетов Узбекистана.

  Алгоритм реализован согласно описанию в `README_VALIDATOR_1.md`.
  """

  @doc """
  Проверяет корректность 20-значного номера счета.

  Может принимать МФО и номер счета либо строками, либо списками цифр.
  Возвращает `true` если ключ совпадает, иначе `false`.
  """
  @spec valid_account?(binary | [integer], binary | [integer]) :: boolean
  def valid_account?(mfo, account) when is_binary(mfo) and is_binary(account) do
    mfo_digits = digits_from_string(mfo)
    acc_digits = digits_from_string(account)
    valid_account?(mfo_digits, acc_digits)
  end

  def valid_account?(mfo_digits, acc_digits)
      when is_list(mfo_digits) and is_list(acc_digits) and length(mfo_digits) == 5 and
             length(acc_digits) == 20 do
    # извлекаем 9-ю цифру (индекс 8) как предоставленный ключ
    provided_key = Enum.at(acc_digits, 8)

    # строим 24-значную последовательность без ключа
    {prefix, [_k | suffix]} = Enum.split(acc_digits, 8)
    seq24 = mfo_digits ++ prefix ++ suffix

    calculate_k14(seq24) == provided_key
  end

  @doc """
  Рассчитывает ключ K14 на основании 24‑значной последовательности (без самой позиции ключа).
  Алгоритм из раздела "Метод - 2" (`mod 11`).
  """
  @spec calculate_k14([integer]) :: integer
  def calculate_k14(digits) when is_list(digits) and length(digits) == 24 do
    # сумма произведений соседних пар
    pairs_sum =
      digits
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] -> a * b end)
      |> Enum.sum()

    total = pairs_sum + (List.last(digits) * 9)
    rem = rem(total, 11)

    case rem do
      0 -> 9
      1 -> 0
      _ -> 11 - rem
    end
  end

  # вспомогательная функция для конвертации строки в список цифр
  defp digits_from_string(str) when is_binary(str) do
    str
    |> String.graphemes()
    |> Enum.map(&String.to_integer/1)
  end
end
