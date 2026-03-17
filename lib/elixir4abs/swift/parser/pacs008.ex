defmodule Elixir4ABS.Swift.Parser.Pacs008 do
  @moduledoc """
  Парсер SWIFT ISO 20022 pacs.008.001.08 (FI-to-FI Customer Credit Transfer).
  Stateless — никакого GenServer, только чистые функции.

  Публичный API: одна функция `parse/1`.
  Pipeline: валидация XML → извлечение header → извлечение транзакций → сборка структуры.
  """

  import SweetXml

  @namespace "urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08"

  defstruct [
    :msg_id,
    :creation_dt,
    :nb_of_txs,
    :ctrl_sum,
    :sttlm_dt,
    transactions: []
  ]

  @type t :: %__MODULE__{
          msg_id: String.t(),
          creation_dt: DateTime.t(),
          nb_of_txs: pos_integer(),
          ctrl_sum: Decimal.t(),
          sttlm_dt: Date.t(),
          transactions: [map()]
        }

  @spec parse(binary()) ::
          {:ok, t()}
          | {:error, :invalid_xml}
          | {:error, :unsupported_namespace}
          | {:error, {:missing_field, atom()}}
          | {:error, {:invalid_amount, String.t()}}
          | {:error, {:invalid_date, String.t()}}
          | {:error, {:nb_of_txs_mismatch, pos_integer(), non_neg_integer()}}

  def parse(xml) when is_binary(xml) do
    with :ok <- validate_not_empty(xml),
         {:ok, doc} <- parse_xml(xml),
         :ok <- validate_namespace(xml),
         {:ok, header} <- extract_header(doc),
         {:ok, txns} <- extract_transactions(doc),
         :ok <- validate_tx_count(header.nb_of_txs, txns),
         {:ok, result} <- build_struct(header, txns) do
      {:ok, result}
    end
  end

  def parse(_), do: {:error, :invalid_xml}

  # --- приватные функции ---

  defp validate_not_empty(""), do: {:error, :invalid_xml}
  defp validate_not_empty(_), do: :ok

  defp parse_xml(xml) do
    doc = SweetXml.parse(xml)
    {:ok, doc}
  rescue
    _ -> {:error, :invalid_xml}
  catch
    :exit, _ -> {:error, :invalid_xml}
  end

  # xmlns — это декларация пространства имён, а не обычный атрибут XML,
  # поэтому XPath не может её прочитать. Проверяем прямо в бинарной строке.
  defp validate_namespace(xml) when is_binary(xml) do
    if String.contains?(xml, @namespace) do
      :ok
    else
      {:error, :unsupported_namespace}
    end
  end

  defp extract_header(doc) do
    raw = %{
      msg_id: xpath(doc, ~x"//GrpHdr/MsgId/text()"s),
      creation: xpath(doc, ~x"//GrpHdr/CreDtTm/text()"s),
      nb_of_txs: xpath(doc, ~x"//GrpHdr/NbOfTxs/text()"s),
      ctrl_sum: xpath(doc, ~x"//GrpHdr/CtrlSum/text()"s),
      sttlm_dt: xpath(doc, ~x"//GrpHdr/IntrBkSttlmDt/text()"s)
    }

    with :ok <- require_field(raw.msg_id, :msg_id),
         :ok <- require_field(raw.sttlm_dt, :sttlm_dt),
         {:ok, dt} <- parse_datetime(raw.creation),
         {:ok, date} <- parse_date(raw.sttlm_dt),
         {:ok, sum} <- parse_decimal(raw.ctrl_sum),
         {:ok, nb} <- parse_integer(raw.nb_of_txs) do
      {:ok, %{raw | creation: dt, sttlm_dt: date, ctrl_sum: sum, nb_of_txs: nb}}
    end
  end

  defp extract_transactions(doc) do
    nodes = xpath(doc, ~x"//CdtTrfTxInf"l)

    result =
      Enum.reduce_while(nodes, {:ok, []}, fn node, {:ok, acc} ->
        case extract_single_transaction(node) do
          {:ok, txn} -> {:cont, {:ok, [txn | acc]}}
          {:error, _} = e -> {:halt, e}
        end
      end)

    case result do
      {:ok, txns} -> {:ok, Enum.reverse(txns)}
      error -> error
    end
  end

  defp extract_single_transaction(node) do
    raw = %{
      end_to_end_id: xpath(node, ~x"./PmtId/EndToEndId/text()"s),
      amount: xpath(node, ~x"./IntrBkSttlmAmt/text()"s),
      currency: xpath(node, ~x"./IntrBkSttlmAmt/@Ccy"s),
      debtor_name: nilify(xpath(node, ~x"./Dbtr/Nm/text()"so)),
      debtor_iban: xpath(node, ~x"./DbtrAcct/Id/IBAN/text()"s),
      debtor_bic: xpath(node, ~x"./DbtrAgt/FinInstnId/BICFI/text()"s),
      creditor_name: nilify(xpath(node, ~x"./Cdtr/Nm/text()"so)),
      creditor_iban: xpath(node, ~x"./CdtrAcct/Id/IBAN/text()"s),
      creditor_bic: xpath(node, ~x"./CdtrAgt/FinInstnId/BICFI/text()"s),
      remittance_info: nilify(xpath(node, ~x"./RmtInf/Ustrd/text()"so))
    }

    with :ok <- require_field(raw.end_to_end_id, :end_to_end_id),
         :ok <- require_field(raw.debtor_iban, :debtor_iban),
         :ok <- require_field(raw.debtor_bic, :debtor_bic),
         :ok <- require_field(raw.creditor_iban, :creditor_iban),
         :ok <- require_field(raw.creditor_bic, :creditor_bic),
         {:ok, amt} <- parse_decimal(raw.amount) do
      {:ok, %{raw | amount: amt}}
    end
  end

  defp validate_tx_count(expected, txns) do
    actual = length(txns)

    if expected == actual do
      :ok
    else
      {:error, {:nb_of_txs_mismatch, expected, actual}}
    end
  end

  defp build_struct(header, txns) do
    result = %__MODULE__{
      msg_id: header.msg_id,
      creation_dt: header.creation,
      nb_of_txs: header.nb_of_txs,
      ctrl_sum: header.ctrl_sum,
      sttlm_dt: header.sttlm_dt,
      transactions: txns
    }

    {:ok, result}
  end

  defp nilify(nil), do: nil
  defp nilify(""), do: nil
  defp nilify(val), do: val

  defp require_field("", field), do: {:error, {:missing_field, field}}
  defp require_field(nil, field), do: {:error, {:missing_field, field}}
  defp require_field(_, _), do: :ok

  defp parse_decimal(str) do
    case Decimal.parse(str) do
      {dec, ""} -> {:ok, dec}
      _ -> {:error, {:invalid_amount, str}}
    end
  end

  defp parse_datetime(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> {:ok, dt}
      _ -> {:error, {:invalid_date, str}}
    end
  end

  defp parse_date(str) do
    case Date.from_iso8601(str) do
      {:ok, d} -> {:ok, d}
      _ -> {:error, {:invalid_date, str}}
    end
  end

  defp parse_integer(str) do
    case Integer.parse(str) do
      {n, ""} when n > 0 -> {:ok, n}
      _ -> {:error, {:missing_field, :nb_of_txs}}
    end
  end
end
