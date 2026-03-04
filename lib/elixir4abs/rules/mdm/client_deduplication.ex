defmodule Elixir4ABS.Rules.MDM.ClientDeduplication do
  use Elixir4ABS.DecisionTable

  @moduledoc """
  Таблица решений: определение «Золотой записи» — дедупликация (MDM).
  Источник: 02.01.02 Примеры таблиц решений по модулям

  Логика при попытке создания клиента, который, возможно, уже существует в базе.

  Входные параметры:
  - `pinfl_match`    — совпадение по ПИНФЛ: "full" / "none"
  - `passport_match` — совпадение по номеру паспорта: "full" / "different" / "same"
  - `name_match`     — совпадение по ФИО: "full" / "different" / "none"

  Результат:
  - `block_creation`  — запретить создание (найден дубль)
  - `create_profile`  — создать новый профиль
  - `update_profile`  — обновить данные в существующем профиле
  - `manual_review`   — направить на ручной разбор (конфликт данных)
  """

  decision_table :decide,
    inputs:  [:pinfl_match, :passport_match, :name_match],
    outputs: [:block_creation, :create_profile, :update_profile, :manual_review] do
    #           pinfl    passport      name         block  create update review
    rule       ["full",  "full",       "full",      true,  false, false, false]  # П1 Дубль
    rule       ["none",  "none",       "none",      false, true,  false, false]  # П2 Новый
    rule       ["full",  "different",  "full",      false, false, true,  false]  # П3 Обновление
    rule       ["full",  "same",       "different", false, false, false, true ]  # П4 Конфликт
  end
end
