defmodule Elixir4ABS.Swift.Parser.Pacs008Test do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Elixir4ABS.Swift.Parser.Pacs008

  @fixture_dir "test/fixtures/swift"

  defp load(name), do: File.read!(Path.join(@fixture_dir, name))

  describe "parse/1 — happy path" do
    test "валидный pacs.008 с 1 транзакцией" do
      assert {:ok, %Pacs008{} = result} = Pacs008.parse(load("pacs008_valid_single.xml"))

      assert result.msg_id == "MSG-20260317-001"
      assert result.nb_of_txs == 1
      assert Decimal.equal?(result.ctrl_sum, Decimal.new("1000.00"))
      assert result.sttlm_dt == ~D[2026-03-17]
      assert length(result.transactions) == 1

      [txn] = result.transactions
      assert txn.end_to_end_id == "E2E-20260317-001"
      assert txn.currency == "RUB"
      assert txn.debtor_bic == "SABRRUMM"
      assert txn.creditor_bic == "VTBRRUMM"
      assert txn.debtor_name == "ООО Ромашка"
      assert txn.creditor_name == "ИП Петров"
      assert txn.remittance_info == "Оплата по договору №123 от 01.03.2026"
    end

    test "валидный pacs.008 с 3 транзакциями" do
      assert {:ok, %Pacs008{nb_of_txs: 3, transactions: txns}} =
               Pacs008.parse(load("pacs008_valid_multi.xml"))

      assert length(txns) == 3

      ids = Enum.map(txns, & &1.end_to_end_id)
      assert "E2E-20260317-101" in ids
      assert "E2E-20260317-102" in ids
      assert "E2E-20260317-103" in ids
    end

    test "поля nullable присутствуют когда заданы" do
      assert {:ok, result} = Pacs008.parse(load("pacs008_valid_single.xml"))
      [txn] = result.transactions
      assert txn.debtor_name != nil
      assert txn.creditor_name != nil
      assert txn.remittance_info != nil
    end

    test "поля nullable равны nil когда отсутствуют" do
      assert {:ok, result} = Pacs008.parse(load("pacs008_valid_multi.xml"))
      # вторая транзакция не имеет debtor_name, creditor_name, remittance_info
      txn = Enum.at(result.transactions, 1)
      assert txn.debtor_name == nil
      assert txn.creditor_name == nil
      assert txn.remittance_info == nil
    end

    test "creation_dt парсится как DateTime" do
      assert {:ok, result} = Pacs008.parse(load("pacs008_valid_single.xml"))
      assert %DateTime{} = result.creation_dt
      assert result.creation_dt.year == 2026
      assert result.creation_dt.month == 3
      assert result.creation_dt.day == 17
    end

    test "ctrl_sum парсится как Decimal" do
      assert {:ok, result} = Pacs008.parse(load("pacs008_valid_single.xml"))
      assert %Decimal{} = result.ctrl_sum
    end
  end

  describe "parse/1 — ошибки XML" do
    @tag capture_log: true
    test "пустой binary" do
      assert {:error, :invalid_xml} = Pacs008.parse("")
    end

    @tag capture_log: true
    test "невалидный XML" do
      assert {:error, :invalid_xml} = Pacs008.parse("<broken>")
    end

    test "не binary" do
      assert {:error, :invalid_xml} = Pacs008.parse(123)
    end

    test "nil" do
      assert {:error, :invalid_xml} = Pacs008.parse(nil)
    end
  end

  describe "parse/1 — ошибки namespace" do
    test "неверный namespace (pacs.008.001.07)" do
      assert {:error, :unsupported_namespace} =
               Pacs008.parse(load("pacs008_wrong_namespace.xml"))
    end

    test "XML без namespace" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <Document>
        <FIToFICstmrCdtTrf><GrpHdr><MsgId>X</MsgId></GrpHdr></FIToFICstmrCdtTrf>
      </Document>
      """

      assert {:error, :unsupported_namespace} = Pacs008.parse(xml)
    end
  end

  describe "parse/1 — отсутствующие поля" do
    test "отсутствует IBAN дебитора" do
      assert {:error, {:missing_field, :debtor_iban}} =
               Pacs008.parse(load("pacs008_missing_iban.xml"))
    end

    test "отсутствует MsgId" do
      xml = valid_xml_without("MsgId")
      assert {:error, {:missing_field, :msg_id}} = Pacs008.parse(xml)
    end
  end

  describe "parse/1 — ошибки формата данных" do
    test "невалидная сумма транзакции" do
      assert {:error, {:invalid_amount, "abc"}} =
               Pacs008.parse(load("pacs008_invalid_amount.xml"))
    end
  end

  describe "property-based" do
    @tag capture_log: true
    property "случайный binary всегда возвращает {:error, _}" do
      check all bin <- binary() do
        result = Pacs008.parse(bin)

        assert match?({:error, :invalid_xml}, result) or
                 match?({:error, :unsupported_namespace}, result) or
                 match?({:error, {:missing_field, _}}, result) or
                 match?({:error, {:invalid_amount, _}}, result) or
                 match?({:error, {:invalid_date, _}}, result) or
                 match?({:error, {:nb_of_txs_mismatch, _, _}}, result)
      end
    end
  end

  # --- вспомогательные функции ---

  # Генерирует валидный XML без указанного тега в GrpHdr
  defp valid_xml_without("MsgId") do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">
      <FIToFICstmrCdtTrf>
        <GrpHdr>
          <CreDtTm>2026-03-17T10:00:00Z</CreDtTm>
          <NbOfTxs>1</NbOfTxs>
          <CtrlSum>100.00</CtrlSum>
          <IntrBkSttlmDt>2026-03-17</IntrBkSttlmDt>
        </GrpHdr>
        <CdtTrfTxInf>
          <PmtId><EndToEndId>E2E-001</EndToEndId></PmtId>
          <IntrBkSttlmAmt Ccy="RUB">100.00</IntrBkSttlmAmt>
          <DbtrAcct><Id><IBAN>RU0204452560040702810412345678901</IBAN></Id></DbtrAcct>
          <DbtrAgt><FinInstnId><BICFI>SABRRUMM</BICFI></FinInstnId></DbtrAgt>
          <CdtrAcct><Id><IBAN>RU0204452560040702810498765432100</IBAN></Id></CdtrAcct>
          <CdtrAgt><FinInstnId><BICFI>VTBRRUMM</BICFI></FinInstnId></CdtrAgt>
        </CdtTrfTxInf>
      </FIToFICstmrCdtTrf>
    </Document>
    """
  end
end
