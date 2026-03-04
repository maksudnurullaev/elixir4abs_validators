defmodule Elixir4ABS.Rules.CBM.LoanOverdue do
  use Elixir4ABS.DecisionTable

  @moduledoc """
  Таблица решений: обработка просрочки по кредитному платежу (CBM).
  Источник: 02.01.02 Примеры таблиц решений по модулям

  Входные параметры:
  - `days_overdue`       — количество дней просрочки (0+)
  - `restructuring`      — признак реструктуризации кредита (boolean)
  - `balance_sufficient` — сумма на счёте ≥ ежемесячному платежу (boolean)

  Результат (boolean-флаги действий):
  - `debit_principal`    — списать основной долг + %
  - `charge_penalty`     — начислить пеню (0.1% в день)
  - `set_overdue_status` — установить статус счёта «Просрочен»
  - `send_sms`           — отправить SMS-напоминание клиенту
  - `transfer_to_legal`  — передать дело в СБ/Суд
  """

  decision_table :decide,
    inputs:  [:days_overdue, :restructuring, :balance_sufficient],
    outputs: [:debit_principal, :charge_penalty, :set_overdue_status, :send_sms, :transfer_to_legal] do
    #           days           restructuring  balance   debit  penalty status sms    legal
    rule       [:any,          true,          :any,     true,  false,  false, false, false]  # П5 Реструктур.
    rule       [0,             false,         true,     true,  false,  false, false, false]  # П1 Норма
    rule       [{1, 3},        false,         false,    false, false,  false, true,  false]  # П2 Грейс
    rule       [{4, 30},       false,         false,    false, true,   true,  true,  false]  # П3 Просрочка
    rule       [{31, :inf},    false,         false,    false, true,   true,  false, true ]  # П4 Дефолт
  end
end
