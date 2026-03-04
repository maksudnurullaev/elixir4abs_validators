defmodule Elixir4ABS.Rules.Registry do
  @moduledoc "Реестр всех таблиц решений для UI-просмотрщика."

  @rulesets %{
    # ── Существующие таблицы ────────────────────────────────────────────────────
    "credit_scoring" => %{
      module:      Elixir4ABS.Rules.CreditScoring,
      title:       "Кредитный скоринг",
      description: "Кредитная политика банка v2.3, §4.1",
      columns:     ["DDN ratio", "Credit score", "Решение", "Ставка, %"],
      inputs: [
        %{name: "ddn_ratio",    label: "DDN ratio",    type: :float,
          min: 0.0, max: 1.0,  step: "0.01"},
        %{name: "credit_score", label: "Credit score", type: :integer,
          min: 0,   max: 850,  step: "1"}
      ]
    },
    "debit_fees" => %{
      module:      Elixir4ABS.Rules.DebitFees,
      title:       "Комиссии по дебетовым операциям",
      description: "Тарифный план v4.1, раздел 2",
      columns:     ["Тип операции", "Канал", "Сумма", "Комиссия, %", "Мин. комиссия"],
      inputs: [
        %{name: "operation_type", label: "Тип операции", type: :select,
          options: ["transfer", "withdrawal", "payment"]},
        %{name: "channel",        label: "Канал",        type: :select,
          options: ["atm", "pos", "online", "branch"]},
        %{name: "amount",         label: "Сумма (UZS)",  type: :float,
          min: 0.0, step: "1000"}
      ]
    },
    "cashback" => %{
      module:      Elixir4ABS.Rules.Cashback,
      title:       "Программа кэшбэка",
      description: "Маркетинговая программа, актуальная версия",
      columns:     ["MCC-категория", "Продукт", "Кэшбэк, %", "Лимит/мес (UZS)"],
      inputs: [
        %{name: "mcc",     label: "MCC-код",  type: :integer,
          min: 0, max: 9999, step: "1"},
        %{name: "product", label: "Продукт",  type: :select,
          options: ["standard", "gold", "platinum"]}
      ]
    },

    # ── CBM — Core Banking Manager ──────────────────────────────────────────────
    "cbm_loan_overdue" => %{
      module:      Elixir4ABS.Rules.CBM.LoanOverdue,
      title:       "CBM: Обработка просрочки по кредиту",
      description: "Начисление штрафов и пеней по кредитным платежам",
      columns:     ["Дней просрочки", "Реструктур.", "Баланс ≥ Платежа",
                    "Списать долг", "Начисл. пеню", "Статус Просрочен", "SMS", "В Суд"],
      inputs: [
        %{name: "days_overdue",       label: "Дней просрочки",  type: :integer,
          min: 0, max: 365, step: "1"},
        %{name: "restructuring",      label: "Реструктуризация", type: :boolean,
          options: ["true", "false"]},
        %{name: "balance_sufficient", label: "Баланс ≥ Платежа", type: :boolean,
          options: ["true", "false"]}
      ]
    },

    # ── FMM — File and Media Manager ────────────────────────────────────────────
    "fmm_document_access" => %{
      module:      Elixir4ABS.Rules.FMM.DocumentAccess,
      title:       "FMM: Политика доступа к документам",
      description: "Управление доступом и жизненным циклом документов",
      columns:     ["Тип документа", "Роль", "Срок истёк", "Статус клиента",
                    "Просмотр", "Выгрузка", "Cold Storage", "Удалить", "Логировать"],
      inputs: [
        %{name: "doc_type",          label: "Тип документа",    type: :select,
          options: ["statement", "credit_file", "biometrics"]},
        %{name: "user_role",         label: "Роль пользователя", type: :select,
          options: ["operator", "credit_officer", "security", "archivist", "system"]},
        %{name: "retention_expired", label: "Срок хранения истёк", type: :boolean,
          options: ["false", "true"]},
        %{name: "client_status",     label: "Статус клиента",    type: :select,
          options: ["active", "closed_5y", "closed_10y"]}
      ]
    },

    # ── MDM — Master Data Manager ───────────────────────────────────────────────
    "mdm_client_onboarding" => %{
      module:      Elixir4ABS.Rules.MDM.ClientOnboarding,
      title:       "MDM: Верификация и онбординг клиента",
      description: "Перевод записи клиента из Draft → Active (Инструкция №3420)",
      columns:     ["ПИНФЛ", "Паспорт", "Face ID", "Чёрный список",
                    "→ Active", "→ Pending", "Заблокировать", "Уведомить"],
      inputs: [
        %{name: "pinfl_valid",     label: "ПИНФЛ (API МВД)",      type: :boolean,
          options: ["true", "false"]},
        %{name: "passport_valid",  label: "Паспорт действителен",  type: :boolean,
          options: ["true", "false"]},
        %{name: "face_match",      label: "Face ID > 80%",         type: :boolean,
          options: ["true", "false"]},
        %{name: "blacklist_match", label: "Чёрный список AML",     type: :boolean,
          options: ["false", "true"]}
      ]
    },
    "mdm_client_deduplication" => %{
      module:      Elixir4ABS.Rules.MDM.ClientDeduplication,
      title:       "MDM: Дедупликация — Золотая запись",
      description: "Логика при создании клиента, который уже может существовать в базе",
      columns:     ["ПИНФЛ совпад.", "Паспорт совпад.", "ФИО совпад.",
                    "Запрет созд.", "Создать", "Обновить", "На разбор"],
      inputs: [
        %{name: "pinfl_match",    label: "Совпадение ПИНФЛ",   type: :select,
          options: ["full", "none"]},
        %{name: "passport_match", label: "Совпадение паспорта", type: :select,
          options: ["full", "different", "same"]},
        %{name: "name_match",     label: "Совпадение ФИО",     type: :select,
          options: ["full", "different", "none"]}
      ]
    },
    "mdm_client_lifecycle" => %{
      module:      Elixir4ABS.Rules.MDM.ClientLifecycle,
      title:       "MDM: Жизненный цикл клиента (Lifecycle)",
      description: "Автоматическое изменение статуса по триггерам (Глава 6 Инструкции)",
      columns:     ["Паспорт просрочен", "AML риск", "Справка о смерти", "Счета закрыты >5л",
                    "Неактивен", "Заблокирован", "Умер", "В архив"],
      inputs: [
        %{name: "passport_expired",   label: "Паспорт просрочен",       type: :boolean,
          options: ["false", "true"]},
        %{name: "aml_listed",         label: "Запись в реестре AML",    type: :boolean,
          options: ["false", "true"]},
        %{name: "death_cert",         label: "Справка о смерти (ЗАГС)", type: :boolean,
          options: ["false", "true"]},
        %{name: "accounts_closed_5y", label: "Все счета закрыты >5 лет", type: :boolean,
          options: ["false", "true"]}
      ]
    },

    # ── ESB — Enterprise Service Bus ────────────────────────────────────────────
    "esb_message_routing" => %{
      module:      Elixir4ABS.Rules.ESB.MessageRouting,
      title:       "ESB: Маршрутизация и Retry Policy",
      description: "Поведение ESB при недоступности целевого модуля",
      columns:     ["Приоритет", "Статус назначения", "Попытки retry",
                    "Отправить", "В очередь", "→ DLQ", "Алерт", "Резерв. узел"],
      inputs: [
        %{name: "priority",    label: "Приоритет",         type: :select,
          options: ["normal", "high"]},
        %{name: "dest_status", label: "Статус назначения", type: :select,
          options: ["available", "busy", "unavailable"]},
        %{name: "retry_count", label: "Кол-во попыток",    type: :integer,
          min: 0, max: 20, step: "1"}
      ]
    },
    "esb_protocol_transformation" => %{
      module:      Elixir4ABS.Rules.ESB.ProtocolTransformation,
      title:       "ESB: Трансформация протоколов",
      description: "Конвертация между JSON, ISO 8583, XML/SOAP и форматами Legacy",
      columns:     ["Источник", "Целевой формат", "Шифрование",
                    "JSON (A)", "ISO 8583 (B)", "XML/SOAP (C)", "ЭЦП"],
      inputs: [
        %{name: "source",        label: "Источник данных",  type: :select,
          options: ["abs_module", "terminal_atm", "gov_service", "legacy_abs"]},
        %{name: "target_format", label: "Целевой формат",   type: :select,
          options: ["json", "iso8583", "xml_soap", "fixed_txt"]},
        %{name: "encryption",    label: "Шифрование",        type: :select,
          options: ["tls", "hsm", "tls_ecp", "vpn"]}
      ]
    }
  }

  def all,       do: @rulesets
  def get(name), do: Map.get(@rulesets, name)
  def names,     do: Map.keys(@rulesets)
end
