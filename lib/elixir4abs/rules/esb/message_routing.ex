defmodule Elixir4ABS.Rules.ESB.MessageRouting do
  use Elixir4ABS.DecisionTable

  @moduledoc """
  Таблица решений: маршрутизация и отказоустойчивость (ESB Retry Policy).
  Источник: 02.01.02 Примеры таблиц решений по модулям

  Определяет поведение ESB, когда целевой модуль временно недоступен.

  Входные параметры:
  - `priority`    — приоритет сообщения: "normal" / "high"
  - `dest_status` — статус назначения: "available" / "busy" / "unavailable"
  - `retry_count` — количество произведённых попыток отправки (0+)

  Результат (boolean-флаги действий):
  - `send_immediately`   — отправить немедленно
  - `put_in_queue`       — поместить в очередь (буфер)
  - `move_to_dlq`        — переместить в Dead Letter Queue
  - `send_alert`         — отправить аварийное уведомление
  - `switch_to_backup`   — переключить на резервный узел
  """

  decision_table :decide,
    inputs:  [:priority, :dest_status, :retry_count],
    outputs: [:send_immediately, :put_in_queue, :move_to_dlq, :send_alert, :switch_to_backup] do
    #           priority    dest           retries      send   queue  dlq    alert  backup
    rule       ["normal",   "available",   0,           true,  false, false, false, false]  # П1 Норма
    rule       ["normal",   "busy",        :any,        false, true,  false, false, false]  # П2 Очередь
    rule       [:any,       "unavailable", {1, 3},      false, true,  false, false, false]  # П3 Повтор
    rule       ["normal",   "unavailable", {4, :inf},   false, false, true,  true,  false]  # П4 DLQ/Фатально
    rule       ["high",     "unavailable", 0,           false, false, false, true,  true ]  # П5 Критично
  end
end
