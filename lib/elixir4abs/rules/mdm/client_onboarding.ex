defmodule Elixir4ABS.Rules.MDM.ClientOnboarding do
  use Elixir4ABS.DecisionTable

  @moduledoc """
  Таблица решений: верификация и онбординг клиента (MDM).
  Источник: 02.01.02 Примеры таблиц решений по модулям

  Определяет, может ли запись клиента быть переведена из состояния `Draft` в `Active`.

  Входные параметры:
  - `pinfl_valid`      — ПИНФЛ прошёл валидацию API МВД (boolean)
  - `passport_valid`   — срок действия паспорта в порядке (boolean)
  - `face_match`       — совпадение Face ID > 80% (boolean)
  - `blacklist_match`  — совпадение с чёрным списком AML (boolean)

  Результат:
  - `assign_active`     — присвоить статус Active
  - `assign_pending`    — присвоить статус Pending (ожидание данных МВД)
  - `block_profile`     — заблокировать профиль (AML-риск)
  - `notify_passport`   — уведомить о необходимости обновить паспорт
  """

  decision_table :decide,
    inputs:  [:pinfl_valid,   :passport_valid, :face_match, :blacklist_match],
    outputs: [:assign_active, :assign_pending, :block_profile, :notify_passport] do
    #           pinfl_valid  passport_valid  face_match  blacklist   active   pending  block    notify
    rule [true,   true,    :any,   true,   false,  false,  true,   false]  # П4 AML Риск (приоритет)
    rule [true,   true,    true,   false,  true,   false,  false,  false]  # П1 Успех
    rule [false,  true,    true,   false,  false,  true,   false,  false]  # П2 Данные МВД
    rule [true,   false,   true,   false,  false,  false,  false,  true ]  # П3 Просрочка паспорта
  end
end
