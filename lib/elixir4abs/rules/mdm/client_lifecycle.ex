defmodule Elixir4ABS.Rules.MDM.ClientLifecycle do
  use Elixir4ABS.DecisionTable

  @moduledoc """
  Таблица решений: автоматическое изменение статуса клиента (MDM Lifecycle).
  Источник: 02.01.02 Примеры таблиц решений по модулям

  Триггеры, которые постоянно отслеживают актуальность данных
  согласно Главе 6 Инструкции ЦБ №3420.

  Входные параметры:
  - `passport_expired`    — срок действия паспорта истёк (boolean)
  - `aml_listed`          — запись в реестре AML/Sanctions (boolean)
  - `death_cert`          — получена справка о смерти из ЗАГС (boolean)
  - `accounts_closed_5y`  — все счета закрыты более 5 лет назад (boolean)

  Результат:
  - `set_inactive`         — статус: Inactive (требуется обновление документов)
  - `set_blocked`          — статус: Blocked (мошенничество / AML)
  - `set_closed_deceased`  — статус: Closed Deceased (умер)
  - `set_archived`         — статус: Archived (клиент закрыт)
  """

  decision_table :decide,
    inputs:  [:passport_expired, :aml_listed, :death_cert, :accounts_closed_5y],
    outputs: [:set_inactive,     :set_blocked, :set_closed_deceased, :set_archived] do
    #           passport_expired  aml_listed  death_cert  closed_5y   inactive  blocked   deceased  archived
    rule [true,   false,  false,  false,  true,   false,  false,  false]  # П1 Просрочка
    rule [false,  true,   false,  false,  false,  true,   false,  false]  # П2 Санкции
    rule [false,  false,  true,   false,  false,  false,  true,   false]  # П3 Смерть
    rule [false,  false,  false,  true,   false,  false,  false,  true ]  # П4 Закрытие
  end
end
