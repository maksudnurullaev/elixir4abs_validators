defmodule Elixir4ABS.DecisionTableTest do
  use ExUnit.Case, async: true

  alias Elixir4ABS.Rules.{CreditScoring, DebitFees, Cashback}
  alias Elixir4ABS.Rules.CBM.LoanOverdue
  alias Elixir4ABS.Rules.FMM.DocumentAccess
  alias Elixir4ABS.Rules.MDM.{ClientOnboarding, ClientDeduplication, ClientLifecycle}
  alias Elixir4ABS.Rules.ESB.{MessageRouting, ProtocolTransformation}

  # ── CreditScoring ────────────────────────────────────────────────────────────

  describe "CreditScoring.decide/1" do
    test "approves low DDN + high score at 18.5%" do
      assert CreditScoring.decide(%{ddn_ratio: 0.3, credit_score: 750}) ==
               %{decision: :approve, rate: 18.5}
    end

    test "approves low DDN + medium score at 22%" do
      assert CreditScoring.decide(%{ddn_ratio: 0.4, credit_score: 650}) ==
               %{decision: :approve, rate: 22.0}
    end

    test "sends to review for medium DDN + high score" do
      assert CreditScoring.decide(%{ddn_ratio: 0.6, credit_score: 720}) ==
               %{decision: :review, rate: nil}
    end

    test "rejects high DDN regardless of score" do
      assert CreditScoring.decide(%{ddn_ratio: 0.8, credit_score: 800}) ==
               %{decision: :reject, rate: nil}
    end

    test "rejects low credit score regardless of DDN" do
      assert CreditScoring.decide(%{ddn_ratio: 0.2, credit_score: 450}) ==
               %{decision: :reject, rate: nil}
    end

    test "boundary: DDN exactly 0.5 with score 700 → first rule" do
      assert CreditScoring.decide(%{ddn_ratio: 0.5, credit_score: 700}) ==
               %{decision: :approve, rate: 18.5}
    end

    test "boundary: DDN 0.71 (above review range) → reject" do
      assert CreditScoring.decide(%{ddn_ratio: 0.71, credit_score: 750}) ==
               %{decision: :reject, rate: nil}
    end
  end

  describe "CreditScoring metadata" do
    test "stores 5 rules in __dt_rules_meta__" do
      rules = CreditScoring.__dt_rules_meta__()
      assert is_list(rules)
      assert length(rules) == 5
    end

    test "each rule spec has 4 elements (2 inputs + 2 outputs)" do
      rules = CreditScoring.__dt_rules_meta__()
      assert Enum.all?(rules, fn spec -> length(spec) == 4 end)
    end
  end

  # ── DebitFees ────────────────────────────────────────────────────────────────

  describe "DebitFees.decide/1" do
    test "online transfer — 0.3%, min 500" do
      assert DebitFees.decide(%{operation_type: "transfer", channel: "online", amount: 100_000.0}) ==
               %{fee_pct: 0.3, fee_min: 500}
    end

    test "branch transfer — 0.5%, min 1000" do
      assert DebitFees.decide(%{operation_type: "transfer", channel: "branch", amount: 50_000.0}) ==
               %{fee_pct: 0.5, fee_min: 1000}
    end

    test "ATM withdrawal up to 500k — no fee" do
      assert DebitFees.decide(%{operation_type: "withdrawal", channel: "atm", amount: 300_000.0}) ==
               %{fee_pct: 0.0, fee_min: 0}
    end

    test "ATM withdrawal above 500k — 1%, min 5000" do
      assert DebitFees.decide(%{operation_type: "withdrawal", channel: "atm", amount: 600_000.0}) ==
               %{fee_pct: 1.0, fee_min: 5000}
    end

    test "payment — always free" do
      assert DebitFees.decide(%{operation_type: "payment", channel: "pos", amount: 999_999.0}) ==
               %{fee_pct: 0.0, fee_min: 0}
    end
  end

  describe "DebitFees metadata" do
    test "stores 7 rules in __dt_rules_meta__" do
      assert length(DebitFees.__dt_rules_meta__()) == 7
    end
  end

  # ── Cashback ─────────────────────────────────────────────────────────────────

  describe "Cashback.decide/1" do
    test "grocery MCC 5411 + platinum → 5% up to 500k" do
      assert Cashback.decide(%{mcc: 5411, product: "platinum"}) ==
               %{cashback_pct: 5.0, monthly_limit: 500_000}
    end

    test "grocery MCC 5411 + standard → 1% up to 100k" do
      assert Cashback.decide(%{mcc: 5411, product: "standard"}) ==
               %{cashback_pct: 1.0, monthly_limit: 100_000}
    end

    test "restaurant MCC 5812 + gold → 1.5% (any non-platinum)" do
      assert Cashback.decide(%{mcc: 5812, product: "gold"}) ==
               %{cashback_pct: 1.5, monthly_limit: 150_000}
    end

    test "transport MCC range 4111-4131 → 2%" do
      assert Cashback.decide(%{mcc: 4120, product: "standard"}) ==
               %{cashback_pct: 2.0, monthly_limit: 200_000}
    end

    test "pharmacy MCC 5912 → 2%" do
      assert Cashback.decide(%{mcc: 5912, product: "gold"}) ==
               %{cashback_pct: 2.0, monthly_limit: 200_000}
    end

    test "unknown MCC + platinum → 1%" do
      assert Cashback.decide(%{mcc: 9999, product: "platinum"}) ==
               %{cashback_pct: 1.0, monthly_limit: 100_000}
    end

    test "unknown MCC + standard → 0.5% default" do
      assert Cashback.decide(%{mcc: 9999, product: "standard"}) ==
               %{cashback_pct: 0.5, monthly_limit: 50_000}
    end
  end

  describe "Cashback metadata" do
    test "stores 9 rules in __dt_rules_meta__" do
      assert length(Cashback.__dt_rules_meta__()) == 9
    end
  end

  # ── No-match fallback ────────────────────────────────────────────────────────

  describe "catch-all fallback clause" do
    test "CreditScoring: пробел ddn=0.6 + score=650 не покрыт ни одним правилом" do
      # Rule 3 требует score >= 700, rule 4 требует ddn >= 0.7, rule 5 требует score <= 599
      assert CreditScoring.decide(%{ddn_ratio: 0.6, credit_score: 650}) ==
               {:error, :no_match}
    end

    test "MessageRouting: high-priority + available — пробел в таблице" do
      # П1 требует priority=normal, П5 требует dest=unavailable
      assert MessageRouting.decide(%{priority: "high", dest_status: "available", retry_count: 0}) ==
               {:error, :no_match}
    end

    test "LoanOverdue: days=0 + no restructuring + balance=false — не описано в таблице" do
      assert LoanOverdue.decide(%{days_overdue: 0, restructuring: false, balance_sufficient: false}) ==
               {:error, :no_match}
    end
  end

  # ── CBM.LoanOverdue ──────────────────────────────────────────────────────────

  describe "LoanOverdue.decide/1" do
    test "П5 Реструктуризация: списать долг, без штрафов (любые дни)" do
      assert LoanOverdue.decide(%{days_overdue: 15, restructuring: true, balance_sufficient: false}) ==
               %{debit_principal: true, charge_penalty: false, set_overdue_status: false,
                 send_sms: false, transfer_to_legal: false}
    end

    test "П1 Норма: списать основной долг, без действий" do
      assert LoanOverdue.decide(%{days_overdue: 0, restructuring: false, balance_sufficient: true}) ==
               %{debit_principal: true, charge_penalty: false, set_overdue_status: false,
                 send_sms: false, transfer_to_legal: false}
    end

    test "П2 Грейс (1-3 дня): только SMS" do
      assert LoanOverdue.decide(%{days_overdue: 2, restructuring: false, balance_sufficient: false}) ==
               %{debit_principal: false, charge_penalty: false, set_overdue_status: false,
                 send_sms: true, transfer_to_legal: false}
    end

    test "П3 Просрочка (4-30 дней): пеня + статус + SMS" do
      assert LoanOverdue.decide(%{days_overdue: 15, restructuring: false, balance_sufficient: false}) ==
               %{debit_principal: false, charge_penalty: true, set_overdue_status: true,
                 send_sms: true, transfer_to_legal: false}
    end

    test "П4 Дефолт (> 30 дней): пеня + статус + суд" do
      assert LoanOverdue.decide(%{days_overdue: 45, restructuring: false, balance_sufficient: false}) ==
               %{debit_principal: false, charge_penalty: true, set_overdue_status: true,
                 send_sms: false, transfer_to_legal: true}
    end

    test "граница: 3 дня → Грейс, 4 дня → Просрочка" do
      grace    = LoanOverdue.decide(%{days_overdue: 3, restructuring: false, balance_sufficient: false})
      overdue  = LoanOverdue.decide(%{days_overdue: 4, restructuring: false, balance_sufficient: false})
      assert grace.send_sms    == true  and grace.charge_penalty   == false
      assert overdue.charge_penalty == true and overdue.send_sms == true
    end
  end

  describe "LoanOverdue metadata" do
    test "stores 5 rules in __dt_rules_meta__" do
      assert length(LoanOverdue.__dt_rules_meta__()) == 5
    end
  end

  # ── FMM.DocumentAccess ───────────────────────────────────────────────────────

  describe "DocumentAccess.decide/1" do
    test "П1 Публичный: операционист, выписка — просмотр + выгрузка" do
      assert DocumentAccess.decide(%{doc_type: "statement", user_role: "operator",
                                     retention_expired: false, client_status: "active"}) ==
               %{allow_view: true, allow_download: true, move_to_cold: false,
                 permanent_delete: false, log_access: false}
    end

    test "П2 Конфиденциально: кредитный офицер — только просмотр + лог" do
      assert DocumentAccess.decide(%{doc_type: "credit_file", user_role: "credit_officer",
                                     retention_expired: false, client_status: "active"}) ==
               %{allow_view: true, allow_download: false, move_to_cold: false,
                 permanent_delete: false, log_access: true}
    end

    test "П3 Сверхсекретно: СБ, биометрия — просмотр + лог" do
      assert DocumentAccess.decide(%{doc_type: "biometrics", user_role: "security",
                                     retention_expired: false, client_status: "active"}) ==
               %{allow_view: true, allow_download: false, move_to_cold: false,
                 permanent_delete: false, log_access: true}
    end

    test "П4 Архив: архивариус, любой тип — холодное хранение + лог" do
      assert DocumentAccess.decide(%{doc_type: "statement", user_role: "archivist",
                                     retention_expired: true, client_status: "closed_5y"}) ==
               %{allow_view: true, allow_download: false, move_to_cold: true,
                 permanent_delete: false, log_access: true}
    end

    test "П5 Удаление: система, срок истёк 10 лет — безвозвратное удаление" do
      assert DocumentAccess.decide(%{doc_type: "credit_file", user_role: "system",
                                     retention_expired: true, client_status: "closed_10y"}) ==
               %{allow_view: false, allow_download: false, move_to_cold: false,
                 permanent_delete: true, log_access: false}
    end
  end

  describe "DocumentAccess metadata" do
    test "stores 5 rules in __dt_rules_meta__" do
      assert length(DocumentAccess.__dt_rules_meta__()) == 5
    end
  end

  # ── MDM.ClientOnboarding ─────────────────────────────────────────────────────

  describe "ClientOnboarding.decide/1" do
    test "П1 Успех: все проверки пройдены → Active" do
      assert ClientOnboarding.decide(%{pinfl_valid: true, passport_valid: true,
                                       face_match: true, blacklist_match: false}) ==
               %{assign_active: true, assign_pending: false,
                 block_profile: false, notify_passport: false}
    end

    test "П2 Данные МВД: ПИНФЛ не прошёл → Pending" do
      assert ClientOnboarding.decide(%{pinfl_valid: false, passport_valid: true,
                                       face_match: true, blacklist_match: false}) ==
               %{assign_active: false, assign_pending: true,
                 block_profile: false, notify_passport: false}
    end

    test "П3 Просрочка паспорта: паспорт недействителен → уведомить" do
      assert ClientOnboarding.decide(%{pinfl_valid: true, passport_valid: false,
                                       face_match: true, blacklist_match: false}) ==
               %{assign_active: false, assign_pending: false,
                 block_profile: false, notify_passport: true}
    end

    test "П4 AML Риск: чёрный список → заблокировать (приоритет над остальными)" do
      assert ClientOnboarding.decide(%{pinfl_valid: true, passport_valid: true,
                                       face_match: false, blacklist_match: true}) ==
               %{assign_active: false, assign_pending: false,
                 block_profile: true, notify_passport: false}
    end
  end

  describe "ClientOnboarding metadata" do
    test "stores 4 rules in __dt_rules_meta__" do
      assert length(ClientOnboarding.__dt_rules_meta__()) == 4
    end
  end

  # ── MDM.ClientDeduplication ──────────────────────────────────────────────────

  describe "ClientDeduplication.decide/1" do
    test "П1 Дубль: полное совпадение — запрет создания" do
      assert ClientDeduplication.decide(%{pinfl_match: "full", passport_match: "full",
                                          name_match: "full"}) ==
               %{block_creation: true, create_profile: false,
                 update_profile: false, manual_review: false}
    end

    test "П2 Новый клиент: нет совпадений — создать профиль" do
      assert ClientDeduplication.decide(%{pinfl_match: "none", passport_match: "none",
                                          name_match: "none"}) ==
               %{block_creation: false, create_profile: true,
                 update_profile: false, manual_review: false}
    end

    test "П3 Обновление: ПИНФЛ совпал, паспорт другой — обновить данные" do
      assert ClientDeduplication.decide(%{pinfl_match: "full", passport_match: "different",
                                          name_match: "full"}) ==
               %{block_creation: false, create_profile: false,
                 update_profile: true, manual_review: false}
    end

    test "П4 Конфликт: ПИНФЛ + паспорт совпали, ФИО отличается — ручной разбор" do
      assert ClientDeduplication.decide(%{pinfl_match: "full", passport_match: "same",
                                          name_match: "different"}) ==
               %{block_creation: false, create_profile: false,
                 update_profile: false, manual_review: true}
    end
  end

  describe "ClientDeduplication metadata" do
    test "stores 4 rules in __dt_rules_meta__" do
      assert length(ClientDeduplication.__dt_rules_meta__()) == 4
    end
  end

  # ── MDM.ClientLifecycle ──────────────────────────────────────────────────────

  describe "ClientLifecycle.decide/1" do
    test "П1 Просрочка паспорта → Inactive" do
      assert ClientLifecycle.decide(%{passport_expired: true, aml_listed: false,
                                      death_cert: false, accounts_closed_5y: false}) ==
               %{set_inactive: true, set_blocked: false,
                 set_closed_deceased: false, set_archived: false}
    end

    test "П2 Санкции AML → Blocked" do
      assert ClientLifecycle.decide(%{passport_expired: false, aml_listed: true,
                                      death_cert: false, accounts_closed_5y: false}) ==
               %{set_inactive: false, set_blocked: true,
                 set_closed_deceased: false, set_archived: false}
    end

    test "П3 Справка о смерти → Closed Deceased" do
      assert ClientLifecycle.decide(%{passport_expired: false, aml_listed: false,
                                      death_cert: true, accounts_closed_5y: false}) ==
               %{set_inactive: false, set_blocked: false,
                 set_closed_deceased: true, set_archived: false}
    end

    test "П4 Все счета закрыты > 5 лет → Archived" do
      assert ClientLifecycle.decide(%{passport_expired: false, aml_listed: false,
                                      death_cert: false, accounts_closed_5y: true}) ==
               %{set_inactive: false, set_blocked: false,
                 set_closed_deceased: false, set_archived: true}
    end
  end

  describe "ClientLifecycle metadata" do
    test "stores 4 rules in __dt_rules_meta__" do
      assert length(ClientLifecycle.__dt_rules_meta__()) == 4
    end
  end

  # ── ESB.MessageRouting ───────────────────────────────────────────────────────

  describe "MessageRouting.decide/1" do
    test "П1 Норма: назначение доступно → отправить немедленно" do
      assert MessageRouting.decide(%{priority: "normal", dest_status: "available", retry_count: 0}) ==
               %{send_immediately: true, put_in_queue: false, move_to_dlq: false,
                 send_alert: false, switch_to_backup: false}
    end

    test "П2 Очередь: назначение занято → в буфер" do
      assert MessageRouting.decide(%{priority: "normal", dest_status: "busy", retry_count: 5}) ==
               %{send_immediately: false, put_in_queue: true, move_to_dlq: false,
                 send_alert: false, switch_to_backup: false}
    end

    test "П3 Повтор: не отвечает, 1–3 попытки → в очередь на retry" do
      assert MessageRouting.decide(%{priority: "normal", dest_status: "unavailable", retry_count: 2}) ==
               %{send_immediately: false, put_in_queue: true, move_to_dlq: false,
                 send_alert: false, switch_to_backup: false}
    end

    test "П4 DLQ: не отвечает, > 3 попыток → DLQ + алерт" do
      assert MessageRouting.decide(%{priority: "normal", dest_status: "unavailable", retry_count: 5}) ==
               %{send_immediately: false, put_in_queue: false, move_to_dlq: true,
                 send_alert: true, switch_to_backup: false}
    end

    test "П5 Критично: высокий приоритет, первая попытка, не отвечает → алерт + резерв" do
      assert MessageRouting.decide(%{priority: "high", dest_status: "unavailable", retry_count: 0}) ==
               %{send_immediately: false, put_in_queue: false, move_to_dlq: false,
                 send_alert: true, switch_to_backup: true}
    end
  end

  describe "MessageRouting metadata" do
    test "stores 5 rules in __dt_rules_meta__" do
      assert length(MessageRouting.__dt_rules_meta__()) == 5
    end
  end

  # ── ESB.ProtocolTransformation ───────────────────────────────────────────────

  describe "ProtocolTransformation.decide/1" do
    test "П1 Internal: модуль ABS → схема JSON (A)" do
      assert ProtocolTransformation.decide(%{source: "abs_module", target_format: "json",
                                             encryption: "tls"}) ==
               %{schema_a_json: true, schema_b_iso: false,
                 schema_c_xml: false, add_digital_signature: false}
    end

    test "П2 Card: терминал/АТМ → схема ISO 8583 (B)" do
      assert ProtocolTransformation.decide(%{source: "terminal_atm", target_format: "iso8583",
                                             encryption: "hsm"}) ==
               %{schema_a_json: false, schema_b_iso: true,
                 schema_c_xml: false, add_digital_signature: false}
    end

    test "П3 Gov: госсервис → схема XML/SOAP (C) + ЭЦП" do
      assert ProtocolTransformation.decide(%{source: "gov_service", target_format: "xml_soap",
                                             encryption: "tls_ecp"}) ==
               %{schema_a_json: false, schema_b_iso: false,
                 schema_c_xml: true, add_digital_signature: true}
    end

    test "П4 Legacy: старая АБС, фикс. формат — без трансформации схем" do
      assert ProtocolTransformation.decide(%{source: "legacy_abs", target_format: "fixed_txt",
                                             encryption: "vpn"}) ==
               %{schema_a_json: false, schema_b_iso: false,
                 schema_c_xml: false, add_digital_signature: false}
    end
  end

  describe "ProtocolTransformation metadata" do
    test "stores 4 rules in __dt_rules_meta__" do
      assert length(ProtocolTransformation.__dt_rules_meta__()) == 4
    end
  end
end
