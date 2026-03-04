defmodule Elixir4ABS.Rules.ESB.ProtocolTransformation do
  use Elixir4ABS.DecisionTable

  @moduledoc """
  Таблица решений: трансформация протоколов (ESB).
  Источник: 02.01.02 Примеры таблиц решений по модулям

  Банковская шина как конвертер между JSON (внутри системы)
  и банковскими форматами (ISO 8583, XML/SOAP, фиксированная длина).

  Входные параметры:
  - `source`        — источник данных: "abs_module" / "terminal_atm" / "gov_service" / "legacy_abs"
  - `target_format` — целевой формат: "json" / "iso8583" / "xml_soap" / "fixed_txt"
  - `encryption`    — способ шифрования: "tls" / "hsm" / "tls_ecp" / "vpn"

  Результат:
  - `schema_a_json`         — схема трансформации A (JSON)
  - `schema_b_iso`          — схема трансформации B (ISO 8583)
  - `schema_c_xml`          — схема трансформации C (XML/SOAP)
  - `add_digital_signature` — добавить цифровую подпись (ЭЦП)
  """

  decision_table :decide,
    inputs:  [:source, :target_format, :encryption],
    outputs: [:schema_a_json, :schema_b_iso, :schema_c_xml, :add_digital_signature] do
    #           source          format        encryption    json   iso    xml    sig
    rule       ["abs_module",   "json",       "tls",        true,  false, false, false]  # П1 Internal
    rule       ["terminal_atm", "iso8583",    "hsm",        false, true,  false, false]  # П2 Card
    rule       ["gov_service",  "xml_soap",   "tls_ecp",    false, false, true,  true ]  # П3 Gov
    rule       ["legacy_abs",   "fixed_txt",  "vpn",        false, false, false, false]  # П4 Legacy
  end
end
