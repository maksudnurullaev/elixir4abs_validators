defmodule Elixir4ABS.ContractPayment do
  @base_url "https://billing.mystudent.uz"

  def base_url, do: @base_url

  # ── HMAC-SHA256 ───────────────────────────────────────────────────────────────

  def sign(data, secret_key) when is_binary(data) and is_binary(secret_key) do
    :crypto.mac(:hmac, :sha256, secret_key, data)
    |> Base.encode16(case: :lower)
  end

  # ── Header building ───────────────────────────────────────────────────────────

  def build_headers(signed_data, api_key, secret_key) do
    ts = System.system_time(:second)
    sig = sign(signed_data, secret_key)

    [
      {"X-Api-Key", api_key},
      {"X-Signature", sig},
      {"X-Timestamp", Integer.to_string(ts)},
      {"Content-Type", "application/json"}
    ]
  end

  # ── Request builders ──────────────────────────────────────────────────────────

  def build_get_contract(pinfl, contract_type_id, api_key, secret_key) do
    qs =
      if contract_type_id == 1,
        do: "?pinfl=#{pinfl}",
        else: "?pinfl=#{pinfl}&contractTypeId=#{contract_type_id}"

    url = @base_url <> "/PaymentGateway/GetContract" <> qs
    %{method: "GET", url: url, headers: build_headers(qs, api_key, secret_key), body: nil}
  end

  def build_create_payment(p, api_key, secret_key) do
    body_map = %{
      "transactionId" => p.txn_id,
      "action" => 1,
      "detail" => %{
        "pinfl" => p.pinfl,
        "amount" => parse_decimal(p.amount),
        "fullName" => p.full_name,
        "contractNumber" => p.contract_number,
        "universityCode" => p.university_code,
        "organizationAccount" => p.org_account,
        "paymentDate" => p.payment_date,
        "contractTypeId" => parse_int(p.contract_type_id, 1)
      }
    }

    body_compact = Jason.encode!(body_map)

    %{
      method: "POST",
      url: @base_url <> "/PaymentGateway/HandlePayment",
      headers: build_headers(body_compact, api_key, secret_key),
      body: Jason.encode!(body_map, pretty: true),
      body_compact: body_compact
    }
  end

  def build_action(txn_id, action, api_key, secret_key) do
    body_map = %{"transactionId" => txn_id, "action" => action, "detail" => nil}
    body_compact = Jason.encode!(body_map)

    %{
      method: "POST",
      url: @base_url <> "/PaymentGateway/HandlePayment",
      headers: build_headers(body_compact, api_key, secret_key),
      body: Jason.encode!(body_map, pretty: true),
      body_compact: body_compact
    }
  end

  def build_get_status(txn_id, api_key, secret_key) do
    qs = "?transactionId=#{URI.encode_www_form(txn_id)}"
    url = @base_url <> "/PaymentGateway/GetPaymentStatus" <> qs
    %{method: "GET", url: url, headers: build_headers(qs, api_key, secret_key), body: nil}
  end

  # ── HTTP execution ────────────────────────────────────────────────────────────

  def execute(%{method: "GET", url: url, headers: headers}) do
    ensure_started()
    erl_headers = headers |> without_content_type() |> to_erl_headers()

    case :httpc.request(
           :get,
           {String.to_charlist(url), erl_headers},
           [{:ssl, [{:verify, :verify_none}]}, {:timeout, 15_000}],
           [{:body_format, :binary}]
         ) do
      {:ok, {{_, status, _}, _, body}} -> {:ok, %{status: status, body: body}}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  def execute(%{method: "POST", url: url, headers: headers, body_compact: body_compact}) do
    ensure_started()
    erl_headers = headers |> without_content_type() |> to_erl_headers()

    case :httpc.request(
           :post,
           {String.to_charlist(url), erl_headers, ~c"application/json", body_compact},
           [{:ssl, [{:verify, :verify_none}]}, {:timeout, 15_000}],
           [{:body_format, :binary}]
         ) do
      {:ok, {{_, status, _}, _, body}} -> {:ok, %{status: status, body: body}}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp ensure_started do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)
    :ok
  end

  defp without_content_type(headers),
    do: Enum.reject(headers, fn {k, _} -> k == "Content-Type" end)

  defp to_erl_headers(headers) do
    Enum.map(headers, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────

  def generate_txn_id do
    d = Date.utc_today()
    date_str = "#{d.year}#{pad2(d.month)}#{pad2(d.day)}"
    suffix = :rand.uniform(99_999) |> Integer.to_string() |> String.pad_leading(5, "0")
    "APEX-TXN-#{date_str}-#{suffix}"
  end

  def default_payment_date do
    dt = DateTime.utc_now() |> DateTime.add(5 * 3600)
    "#{dt.year}-#{pad2(dt.month)}-#{pad2(dt.day)}T#{pad2(dt.hour)}:#{pad2(dt.minute)}:00"
  end

  def format_body(nil), do: ""
  def format_body(""), do: ""

  def format_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, map} -> Jason.encode!(map, pretty: true)
      _ -> body
    end
  end

  defp parse_decimal(str) when is_binary(str) do
    case Float.parse(String.replace(str, ",", ".")) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  defp parse_decimal(n) when is_number(n), do: n * 1.0
  defp parse_decimal(_), do: 0.0

  defp parse_int(str, default) when is_binary(str) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_int(n, _) when is_integer(n), do: n
  defp parse_int(_, default), do: default

  defp pad2(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")
end
