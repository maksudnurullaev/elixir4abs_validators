defmodule Elixir4ABS.Rules.FMM.DocumentAccess do
  use Elixir4ABS.DecisionTable

  @moduledoc """
  Таблица решений: политика доступа и хранения документов (FMM).
  Источник: 02.01.02 Примеры таблиц решений по модулям

  Входные параметры:
  - `doc_type`           — тип документа: "statement" / "credit_file" / "biometrics"
  - `user_role`          — роль пользователя: "operator" / "credit_officer" / "security" / "archivist" / "system"
  - `retention_expired`  — срок обязательного хранения истёк (boolean)
  - `client_status`      — статус клиента: "active" / "closed_5y" / "closed_10y"

  Результат (boolean-флаги действий):
  - `allow_view`         — разрешить просмотр
  - `allow_download`     — разрешить выгрузку (PDF)
  - `move_to_cold`       — переместить в Cold Storage
  - `permanent_delete`   — безвозвратное удаление
  - `log_access`         — логировать каждое чтение
  """

  decision_table :decide,
    inputs:  [:doc_type, :user_role, :retention_expired, :client_status],
    outputs: [:allow_view, :allow_download, :move_to_cold, :permanent_delete, :log_access] do
    #           doc_type         role               expired  status        view   dl     cold   del    log
    rule       ["statement",     "operator",        false,   "active",     true,  true,  false, false, false]  # П1 Публичный
    rule       ["credit_file",   "credit_officer",  false,   "active",     true,  false, false, false, true ]  # П2 Конфиденц.
    rule       ["biometrics",    "security",        false,   "active",     true,  false, false, false, true ]  # П3 Сверхсекр.
    rule       [:any,            "archivist",       true,    "closed_5y",  true,  false, true,  false, true ]  # П4 Архив
    rule       [:any,            "system",          true,    "closed_10y", false, false, false, true,  false]  # П5 Удаление
  end
end
