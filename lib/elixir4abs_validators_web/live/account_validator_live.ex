defmodule Elixir4absValidatorsWeb.AccountValidatorLive do
  use Elixir4absValidatorsWeb, :live_view

  alias Elixir4ABS.AccountValidator

  @examples [
    %{
      label: "Депозит ФЛ",
      mfo: "00444",
      account: "20208000312345678001",
      hint: "Asaka Bank · балансовый 20208 · UZS"
    },
    %{
      label: "Касса банка",
      mfo: "00444",
      account: "10101000000000000001",
      hint: "Asaka Bank · балансовый 10101 · UZS"
    },
    %{
      label: "Счёт ЮЛ",
      mfo: "00774",
      account: "23001000712345678001",
      hint: "Hamkorbank · балансовый 23001 · UZS"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, mfo: "", account: "", breakdown: nil, examples: @examples)}
  end

  @impl true
  def handle_event("use_example", %{"mfo" => mfo, "account" => account}, socket) do
    breakdown = build_breakdown(mfo, account)
    {:noreply, assign(socket, mfo: mfo, account: account, breakdown: breakdown)}
  end

  @impl true
  def handle_event("validate", %{"mfo" => mfo, "account" => account}, socket) do
    account = String.replace(account, " ", "")
    breakdown = build_breakdown(mfo, account)
    {:noreply, assign(socket, mfo: mfo, account: account, breakdown: breakdown)}
  end

  # ── Breakdown ──────────────────────────────────────────────────────────────

  defp build_breakdown(mfo, account)
       when byte_size(mfo) == 5 and byte_size(account) == 20 do
    if all_digits?(mfo) and all_digits?(account) do
      # CCCCCVVVKSSSSSSSSNNN
      # CCCCC (разряды  1– 5)
      balance_code = String.slice(account, 0, 5)
      # VVV   (разряды  6– 8)
      currency_code = String.slice(account, 5, 3)
      # K (разряд 9)
      key_digit = String.at(account, 8) |> String.to_integer()
      # SSSSSSSS (разряды 10–17)
      client_code = String.slice(account, 9, 8)
      # NNN      (разряды 18–20)
      seq = String.slice(account, 17, 3)

      acc_digits = digits_from_string(account)
      mfo_digits = digits_from_string(mfo)
      {prefix, [_k | suffix]} = Enum.split(acc_digits, 8)

      calculated_key = AccountValidator.calculate_k14(mfo_digits ++ prefix ++ suffix)

      %{
        mfo: mfo,
        balance_code: balance_code,
        balance_desc: balance_description(balance_code),
        currency_code: currency_code,
        currency_desc: currency_description(currency_code),
        currency_iso: currency_iso(currency_code),
        key_digit: key_digit,
        calculated_key: calculated_key,
        key_valid: key_digit == calculated_key,
        client_code: client_code,
        seq: seq
      }
    end
  end

  defp build_breakdown(_, _), do: nil

  # ── Balance account descriptions ───────────────────────────────────────────

  defp balance_description("10101"), do: "Касса банка — наличные денежные средства"

  defp balance_description("20208"),
    do: "Депозиты до востребования физических лиц (карточные счета)"

  defp balance_description("20210"), do: "Текущие счета физических лиц в иностранной валюте"
  defp balance_description("23001"), do: "Текущие счета юридических лиц (национальная валюта)"
  defp balance_description("23101"), do: "Текущие счета бюджетных организаций"
  defp balance_description("23120"), do: "Транзитные счета для операций с пластиковыми картами"
  defp balance_description(<<"204", _::binary>>), do: "Сберегательные вклады физических лиц"
  defp balance_description(<<"206", _::binary>>), do: "Срочные вклады физических лиц"

  defp balance_description(<<"226", _::binary>>),
    do: "Целевые средства (оплата авто, контракта и др.)"

  defp balance_description(code), do: "Балансовый счёт #{code} (план счетов ЦБ Узбекистана)"

  # ── Currency descriptions (ISO 4217) ──────────────────────────────────────

  defp currency_description("000"), do: "UZS — Узбекский сум"
  defp currency_description("840"), do: "USD — Доллар США"
  defp currency_description("978"), do: "EUR — Евро"
  defp currency_description("643"), do: "RUB — Российский рубль"
  defp currency_description("826"), do: "GBP — Британский фунт стерлингов"
  defp currency_description("392"), do: "JPY — Японская иена"
  defp currency_description("156"), do: "CNY — Китайский юань"
  defp currency_description("756"), do: "CHF — Швейцарский франк"
  defp currency_description(code), do: "ISO 4217: #{code}"

  defp currency_iso("000"), do: "UZS"
  defp currency_iso("840"), do: "USD"
  defp currency_iso("978"), do: "EUR"
  defp currency_iso("643"), do: "RUB"
  defp currency_iso("826"), do: "GBP"
  defp currency_iso("392"), do: "JPY"
  defp currency_iso("156"), do: "CNY"
  defp currency_iso("756"), do: "CHF"
  defp currency_iso(code), do: code

  # ── Helpers ────────────────────────────────────────────────────────────────

  # Форматирование по структуре CCCCCVVVKSSSSSSSSNNN → "CCCCC VVV K SSSSSSSS NNN"
  @account_groups [5, 3, 1, 8, 3]

  defp format_account(""), do: ""

  defp format_account(account) do
    digits = String.graphemes(account)

    {parts, _} =
      Enum.reduce(@account_groups, {[], digits}, fn size, {acc, rest} ->
        {chunk, remaining} = Enum.split(rest, size)
        if chunk == [], do: {acc, remaining}, else: {acc ++ [Enum.join(chunk)], remaining}
      end)

    Enum.join(parts, " ")
  end

  defp all_digits?(str), do: String.match?(str, ~r/^\d+$/)

  defp digits_from_string(str),
    do: str |> String.graphemes() |> Enum.map(&String.to_integer/1)

  # ── Template ───────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 p-4">
      <div class="w-full bg-white rounded-2xl shadow-md p-8">
        <a href={~p"/"} class="block text-sm text-blue-600 hover:underline mb-4">← На главную</a>

        <h1 class="text-2xl font-bold text-gray-800 text-center mb-1">
          Валидатор счётов УзБ
        </h1>
        <p class="text-sm text-gray-500 text-center mb-6">
          Расшифровка и проверка 20-значного банковского номера
        </p>

        <%!-- Примеры --%>
        <div class="mb-6">
          <p class="text-xs font-medium text-gray-500 mb-2">Примеры для проверки:</p>
          <div class="flex flex-wrap gap-2">
            <%= for ex <- @examples do %>
              <button
                type="button"
                phx-click="use_example"
                phx-value-mfo={ex.mfo}
                phx-value-account={ex.account}
                title={ex.hint}
                class="text-xs px-3 py-1.5 rounded-full border border-blue-200 bg-blue-50 text-blue-700 hover:bg-blue-100 hover:border-blue-400 transition"
              >
                {ex.label}
              </button>
            <% end %>
          </div>
        </div>

        <form phx-change="validate" phx-submit="validate" class="space-y-4">
          <div class="flex gap-3">
            <div class="w-36 shrink-0">
              <label class="block text-xs font-medium text-gray-600 mb-1">
                МФО <span class="text-gray-400">(5 цифр)</span>
              </label>
              <input
                type="text"
                name="mfo"
                value={@mfo}
                maxlength="5"
                placeholder="00444"
                autocomplete="off"
                class="w-full border border-gray-300 rounded-lg px-3 py-2 font-mono text-base tracking-widest focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div class="flex-1">
              <label class="block text-xs font-medium text-gray-600 mb-1">
                Номер счёта <span class="text-gray-400">(20 цифр)</span>
              </label>
              <input
                type="text"
                name="account"
                value={format_account(@account)}
                maxlength="24"
                placeholder="20208 000 K 12345678 001"
                autocomplete="off"
                phx-hook="AccountNumberMask"
                id="account-input"
                class="w-full border border-gray-300 rounded-lg px-3 py-2 font-mono text-base tracking-widest focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>

          <button
            type="submit"
            class="w-full bg-blue-600 text-white font-semibold rounded-lg py-2 hover:bg-blue-700 transition"
          >
            Проверить
          </button>
        </form>

        <%= if @breakdown do %>
          <div class="mt-6 border border-gray-200 rounded-xl overflow-hidden text-sm">
            <%!-- Segmented visual display: CCCCCVVVKSSSSSSSSNNN --%>
            <div class="bg-gray-50 px-4 py-3 font-mono text-center overflow-x-auto">
              <div class="text-xs text-gray-400 mb-1 tracking-widest select-none">
                CCCCC·VVV·K·SSSSSSSS·NNN
              </div>
              <div class="flex divide-x divide-gray-200 min-w-max mx-auto w-fit">
                <div class="pr-3">
                  <div class="text-xs text-gray-400 mb-0.5">1–5 · Баланс</div>
                  <div class="font-bold text-indigo-700">{@breakdown.balance_code}</div>
                </div>
                <div class="px-3">
                  <div class="text-xs text-gray-400 mb-0.5">6–8 · Валюта</div>
                  <div class="font-bold text-blue-700">
                    {@breakdown.currency_code}
                    <span class="text-xs font-normal text-blue-500">({@breakdown.currency_iso})</span>
                  </div>
                </div>
                <div class="px-3">
                  <div class="text-xs text-gray-400 mb-0.5">9 · Ключ</div>
                  <div class={"font-bold #{if @breakdown.key_valid, do: "text-green-600", else: "text-red-600"}"}>
                    {@breakdown.key_digit}
                  </div>
                </div>
                <div class="px-3">
                  <div class="text-xs text-gray-400 mb-0.5">10–17 · Клиент</div>
                  <div class="font-bold text-gray-800 tracking-wider">{@breakdown.client_code}</div>
                </div>
                <div class="pl-3">
                  <div class="text-xs text-gray-400 mb-0.5">18–20 · №</div>
                  <div class="font-bold text-gray-800">{@breakdown.seq}</div>
                </div>
              </div>
            </div>

            <%!-- Result banner --%>
            <div class={"px-4 py-2 font-semibold #{if @breakdown.key_valid, do: "bg-green-500 text-white", else: "bg-red-500 text-white"}"}>
              <%= if @breakdown.key_valid do %>
                ✓ Счёт корректен
              <% else %>
                ✗ Неверный контрольный ключ — ожидался {@breakdown.calculated_key}
              <% end %>
            </div>

            <%!-- Field details --%>
            <dl class="divide-y divide-gray-100">
              <div class="px-4 py-3">
                <dt class="font-medium text-gray-700">
                  МФО — код филиала банка
                  <code class="ml-2 bg-gray-100 px-1 rounded text-xs">{@breakdown.mfo}</code>
                </dt>
                <dd class="mt-0.5 text-gray-500">
                  Идентифицирует конкретный филиал банка в системе ЦБ Узбекистана.
                  Используется при расчёте контрольного ключа.
                </dd>
              </div>

              <div class="px-4 py-3">
                <dt class="font-medium text-gray-700">
                  CCCCC · Разряды 1–5 — Балансовый счёт
                  <code class="ml-2 bg-gray-100 px-1 rounded text-xs">{@breakdown.balance_code}</code>
                </dt>
                <dd class="mt-0.5 text-gray-500">{@breakdown.balance_desc}</dd>
              </div>

              <div class="px-4 py-3">
                <dt class="font-medium text-gray-700">
                  VVV · Разряды 6–8 — Код валюты
                  <code class="ml-2 bg-gray-100 px-1 rounded text-xs">
                    {@breakdown.currency_code}
                  </code>
                </dt>
                <dd class="mt-0.5 text-gray-500">{@breakdown.currency_desc}</dd>
              </div>

              <div class="px-4 py-3">
                <dt class="font-medium text-gray-700">
                  K · Разряд 9 — Контрольный ключ
                  <code class={"ml-2 px-1 rounded text-xs #{if @breakdown.key_valid, do: "bg-green-100 text-green-700", else: "bg-red-100 text-red-700"}"}>
                    {@breakdown.key_digit}
                  </code>
                  <%= if @breakdown.key_valid do %>
                    <span class="ml-1 text-green-600 text-xs">✓ верный</span>
                  <% else %>
                    <span class="ml-1 text-red-600 text-xs">
                      ✗ неверный (должен быть <strong><%= @breakdown.calculated_key %></strong>)
                    </span>
                  <% end %>
                </dt>
                <dd class="mt-0.5 text-gray-500">
                  Рассчитан по <strong>Методу 2</strong> (сумма произведений соседних пар, mod 11)
                  на основе МФО + CCCCC + VVV + SSSSSSSS + NNN.
                  Защищает от ошибок при вводе номера счёта.
                </dd>
              </div>

              <div class="px-4 py-3">
                <dt class="font-medium text-gray-700">
                  SSSSSSSS · Разряды 10–17 — Уникальный код клиента
                  <code class="ml-2 bg-gray-100 px-1 rounded text-xs">{@breakdown.client_code}</code>
                </dt>
                <dd class="mt-0.5 text-gray-500">
                  Уникальный 8-значный идентификатор клиента внутри банка.
                  Один и тот же клиент имеет одинаковый код SSSSSSSS во всех своих счетах.
                </dd>
              </div>

              <div class="px-4 py-3">
                <dt class="font-medium text-gray-700">
                  NNN · Разряды 18–20 — Порядковый номер счёта
                  <code class="ml-2 bg-gray-100 px-1 rounded text-xs">{@breakdown.seq}</code>
                </dt>
                <dd class="mt-0.5 text-gray-500">
                  Порядковый номер конкретного счёта клиента в рамках данного балансового счёта и валюты.
                  Позволяет клиенту иметь несколько счетов одного типа.
                </dd>
              </div>
            </dl>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
