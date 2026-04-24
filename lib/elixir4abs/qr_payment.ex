defmodule Elixir4ABS.QrPayment do
  @moduledoc """
  QR-платёж: генерация уникального идентификатора транзакции и упаковка
  платёжных данных (магазин, счёт, сумма, TTL) в SVG-QR код.

  Формат полезной нагрузки (UZB Pay QR):
    APEX://pay?merchant=...&acc=...&mfo=...&amount=...&ccy=...&txid=...&exp=...

  Покупатель сканирует QR через любое банковское приложение — деньги уходят
  напрямую со счёта на счёт без посредника.
  """

  @ttl_options [
    {300, "5 минут"},
    {600, "10 минут"},
    {1800, "30 минут"},
    {3600, "1 час"},
    {86400, "24 часа"}
  ]

  @currencies [
    {"860", "UZS — узбекский сум"},
    {"840", "USD — доллар США"},
    {"978", "EUR — евро"}
  ]

  def ttl_options, do: @ttl_options
  def currencies, do: @currencies

  # ── Transaction ID ──────────────────────────────────────────────────────────

  @doc """
  Генерирует уникальный идентификатор транзакции вида TXN-<unix>-<hex8>.
  Каждый вызов возвращает новое значение.
  """
  @spec generate_txid() :: String.t()
  def generate_txid do
    ts = DateTime.utc_now() |> DateTime.to_unix()
    suffix = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "TXN-#{ts}-#{suffix}"
  end

  # ── Payload ─────────────────────────────────────────────────────────────────

  @doc """
  Формирует строку платёжного запроса для кодирования в QR.
  Поля: merchant_id, acc, mfo, amount (в тийинах), ccy (ISO 4217), txid, exp (ISO 8601).
  """
  @spec build_payload(map()) :: String.t()
  def build_payload(%{
        merchant_id: merchant_id,
        account: account,
        mfo: mfo,
        amount: amount,
        currency: ccy,
        txid: txid,
        ttl: _ttl
      }) do
    params =
      URI.encode_query([
        {"merchant_id", merchant_id},
        {"acc", account},
        {"mfo", mfo},
        {"amount", to_string(amount)},
        {"ccy", ccy},
        # ,
        {"txid", txid}
        # {"exp",         exp} - не все банки поддерживают поле exp, поэтому пока убираем его из полезной нагрузки
      ])

    "APEX://pay?" <> params
  end

  @doc """
  Вычисляет дату и время истечения QR-кода и возвращает строку для отображения.
  Показывает время в зоне UTC+5 (Ташкент).
  """
  @spec format_expires_at(integer()) :: String.t()
  def format_expires_at(ttl_seconds) do
    dt = DateTime.utc_now() |> DateTime.add(ttl_seconds + 5 * 3600)
    "#{pad2(dt.hour)}:#{pad2(dt.minute)}"
  end

  defp pad2(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  # ── QR rendering ────────────────────────────────────────────────────────────

  @doc """
  Генерирует SVG-строку QR-кода из произвольной полезной нагрузки.
  Возвращает `{:ok, svg_string}` или `{:error, reason}`.
  """
  @spec to_svg(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def to_svg(payload, opts \\ []) do
    width = Keyword.get(opts, :width, 280)
    svg = payload |> EQRCode.encode() |> EQRCode.svg(width: width)
    {:ok, svg}
  rescue
    e -> {:error, e}
  end

  # ── Amount helpers ───────────────────────────────────────────────────────────

  @doc """
  Форматирует сумму с разрядными разделителями и запятой для тийинов.
  Принимает строку ("150000.50") или целое число (150000).
  Возвращает: "150 000,50" или "150 000".
  """
  @spec format_amount(String.t() | integer()) :: String.t()
  def format_amount(amount) when is_integer(amount),
    do: format_amount(Integer.to_string(amount))

  def format_amount(amount) when is_binary(amount) do
    case String.split(amount, ".") do
      [int_part, dec_part] -> format_int_digits(int_part) <> "," <> dec_part
      [int_part] -> format_int_digits(int_part)
    end
  end

  def format_amount(_), do: "0"

  defp format_int_digits(""), do: "0"

  defp format_int_digits(str) do
    str
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map_join(" ", &Enum.join/1)
    |> String.reverse()
  end

  # ── Currency label ───────────────────────────────────────────────────────────

  @doc "Возвращает краткое обозначение валюты по коду ISO 4217."
  @spec currency_label(String.t()) :: String.t()
  def currency_label("860"), do: "UZS"
  def currency_label("840"), do: "USD"
  def currency_label("978"), do: "EUR"
  def currency_label(code), do: code
end
