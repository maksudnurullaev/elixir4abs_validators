defmodule Elixir4ABS.Rules.CreditScoring do
  use Elixir4ABS.DecisionTable

  @moduledoc """
  Таблица решений: кредитный скоринг.
  Источник: Кредитная политика банка v2.3, §4.1

  Входные параметры:
  - `ddn_ratio`    — коэффициент долговой нагрузки (0.0 – 1.0)
  - `credit_score` — кредитный скор (0 – 850)

  Результат:
  - `decision` — `:approve` / `:review` / `:reject`
  - `rate`     — процентная ставка (%) или `nil`
  """

  decision_table :decide,
    inputs:  [:ddn_ratio, :credit_score],
    outputs: [:decision, :rate] do
    #           ddn_ratio      credit_score    decision    rate
    rule       [{0.0, 0.5},    {700, :inf},    :approve,   18.5]
    rule       [{0.0, 0.5},    {600, 699},     :approve,   22.0]
    rule       [{0.5, 0.7},    {700, :inf},    :review,    nil ]
    rule       [{0.7, :inf},   :any,           :reject,    nil ]
    rule       [:any,          {0, 599},       :reject,    nil ]
  end
end
