defmodule Elixir4ABS.Rules.DebitFees do
  use Elixir4ABS.DecisionTable

  @moduledoc """
  Таблица решений: комиссии по дебетовым операциям.
  Источник: Тарифный план v4.1, раздел 2

  Входные параметры:
  - `operation_type` — тип операции: "transfer" / "withdrawal" / "payment"
  - `channel`        — канал: "atm" / "pos" / "online" / "branch"
  - `amount`         — сумма операции (UZS)

  Результат:
  - `fee_pct` — процент комиссии
  - `fee_min` — минимальная комиссия (UZS)
  """

  decision_table :decide,
    inputs:  [:operation_type, :channel, :amount],
    outputs: [:fee_pct, :fee_min] do
    #                operation_type   channel     amount         fee_pct  fee_min
    rule            ["transfer",      "online",   :any,          0.3,     500  ]
    rule            ["transfer",      "branch",   :any,          0.5,     1000 ]
    rule            ["withdrawal",    "atm",      {0, 500_000},  0.0,     0    ]
    rule            ["withdrawal",    "atm",      {500_000, :inf}, 1.0,   5000 ]
    rule            ["withdrawal",    "branch",   :any,          1.5,     2000 ]
    rule            ["payment",       :any,       :any,          0.0,     0    ]
    rule            [:any,            :any,       :any,          1.0,     1000 ]
  end
end
