defmodule Elixir4ABS.Rules.Cashback do
  use Elixir4ABS.DecisionTable

  @moduledoc """
  Таблица решений: программа кэшбэка.
  Источник: Маркетинговая программа, актуальная версия

  Входные параметры:
  - `mcc`     — код категории торговца (MCC, ISO 18245)
  - `product` — продукт клиента: "standard" / "gold" / "platinum"

  Результат:
  - `cashback_pct` — процент кэшбэка
  - `monthly_limit` — лимит кэшбэка в месяц (UZS)

  Основные MCC-категории:
  - 5411       — продуктовые магазины
  - 5812       — рестораны
  - 4111-4131  — транспорт
  - 5912       — аптеки
  """

  decision_table :decide,
    inputs:  [:mcc, :product],
    outputs: [:cashback_pct, :monthly_limit] do
    #           mcc              product        cashback_pct  monthly_limit
    rule       [5411,            "platinum",    5.0,          500_000]
    rule       [5411,            "gold",        3.0,          300_000]
    rule       [5411,            "standard",    1.0,          100_000]
    rule       [5812,            "platinum",    3.0,          300_000]
    rule       [5812,            :any,          1.5,          150_000]
    rule       [{4111, 4131},    :any,          2.0,          200_000]
    rule       [5912,            :any,          2.0,          200_000]
    rule       [:any,            "platinum",    1.0,          100_000]
    rule       [:any,            :any,          0.5,           50_000]
  end
end
