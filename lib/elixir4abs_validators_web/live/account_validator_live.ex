defmodule Elixir4absValidatorsWeb.AccountValidatorLive do
  use Elixir4absValidatorsWeb, :live_view

  alias Elixir4ABS.AccountValidator

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, mfo: "", account: "", method: "m2", breakdown: nil)}
  end

  @impl true
  def handle_event("validate", %{"mfo" => mfo, "account" => account, "method" => method}, socket) do
    breakdown = build_breakdown(mfo, account, method)
    {:noreply, assign(socket, mfo: mfo, account: account, method: method, breakdown: breakdown)}
  end

  # ── Breakdown ──────────────────────────────────────────────────────────────

  defp build_breakdown(mfo, account, method)
       when byte_size(mfo) == 5 and byte_size(account) == 20 do
    if all_digits?(mfo) and all_digits?(account) do
      balance_code  = String.slice(account, 0, 5)
      currency_code = String.slice(account, 5, 3)
      key_digit     = String.at(account, 8) |> String.to_integer()
      unique        = String.slice(account, 9, 11)

      acc_digits = digits_from_string(account)
      mfo_digits = digits_from_string(mfo)
      {prefix, [_k | suffix]} = Enum.split(acc_digits, 8)

      calculated_key =
        case method do
          "m1" ->
            AccountValidator.calculate_key_m1(mfo_digits ++ prefix ++ [0] ++ suffix)
          _ ->
            AccountValidator.calculate_k14(mfo_digits ++ prefix ++ suffix)
        end

      %{
        mfo:            mfo,
        balance_code:   balance_code,
        balance_desc:   balance_description(balance_code),
        currency_code:  currency_code,
        currency_desc:  currency_description(currency_code),
        key_digit:      key_digit,
        calculated_key: calculated_key,
        key_valid:      key_digit == calculated_key,
        unique:         unique,
        nibd:           String.slice(unique, 0, 8),
        seq:            String.slice(unique, 8, 3)
      }
    end
  end

  defp build_breakdown(_, _, _), do: nil

  # ── Balance account descriptions ───────────────────────────────────────────

  defp balance_description("10101"), do: "Касса банка — наличные денежные средства"
  defp balance_description("20208"), do: "Депозиты до востребования физических лиц (карточные счета)"
  defp balance_description("20210"), do: "Текущие счета физических лиц в иностранной валюте"
  defp balance_description("23001"), do: "Текущие счета юридических лиц (национальная валюта)"
  defp balance_description("23101"), do: "Текущие счета бюджетных организаций"
  defp balance_description("23120"), do: "Транзитные счета для операций с пластиковыми картами"
  defp balance_description(<<"204", _::binary>>), do: "Сберегательные вклады физических лиц"
  defp balance_description(<<"206", _::binary>>), do: "Срочные вклады физических лиц"
  defp balance_description(<<"226", _::binary>>), do: "Целевые средства (оплата авто, контракта и др.)"
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

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp all_digits?(str), do: String.match?(str, ~r/^\d+$/)

  defp digits_from_string(str),
    do: str |> String.graphemes() |> Enum.map(&String.to_integer/1)

  # ── Template ───────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center p-4">
      <div class="w-full max-w-lg bg-white rounded-2xl shadow-md p-8">

        <a href={~p"/"} class="block text-sm text-blue-600 hover:underline mb-4">← На главную</a>

        <h1 class="text-2xl font-bold text-gray-800 text-center mb-1">
          Валидатор счётов УзБ
        </h1>
        <p class="text-sm text-gray-500 text-center mb-8">
          Расшифровка и проверка 20-значного банковского номера
        </p>

        <form phx-change="validate" class="space-y-4">
          <div class="flex gap-3">
            <div class="w-36 shrink-0">
              <label class="block text-xs font-medium text-gray-600 mb-1">
                МФО <span class="text-gray-400">(5 цифр)</span>
              </label>
              <input
                type="text" name="mfo" value={@mfo} maxlength="5"
                placeholder="00444" autocomplete="off"
                class="w-full border border-gray-300 rounded-lg px-3 py-2 font-mono text-base tracking-widest focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div class="flex-1">
              <label class="block text-xs font-medium text-gray-600 mb-1">
                Номер счёта <span class="text-gray-400">(20 цифр)</span>
              </label>
              <input
                type="text" name="account" value={@account} maxlength="20"
                placeholder="20208000X12345678001" autocomplete="off"
                class="w-full border border-gray-300 rounded-lg px-3 py-2 font-mono text-base tracking-widest focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>

          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">Алгоритм проверки</label>
            <select name="method" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
              <option value="m2" selected={@method == "m2"}>
                Метод 2 — mod 11 (межбанковский клиринг ЦБ)
              </option>
              <option value="m1" selected={@method == "m1"}>
                Метод 1 — весовые коэф. 7·1·3, mod 10
              </option>
            </select>
          </div>
        </form>

        <%= if @breakdown do %>
          <div class="mt-6 border border-gray-200 rounded-xl overflow-hidden text-sm">

            <%!-- Segmented visual display --%>
            <div class="bg-gray-50 px-4 py-3 flex font-mono divide-x divide-gray-200 text-center">
              <div class="pr-4">
                <div class="text-xs text-gray-400 mb-1">МФО</div>
                <div class="font-bold text-blue-600"><%= @breakdown.mfo %></div>
              </div>
              <div class="px-4">
                <div class="text-xs text-gray-400 mb-1">Баланс 1–5</div>
                <div class="font-bold text-gray-800"><%= @breakdown.balance_code %></div>
              </div>
              <div class="px-4">
                <div class="text-xs text-gray-400 mb-1">Валюта 6–8</div>
                <div class="font-bold text-gray-800"><%= @breakdown.currency_code %></div>
              </div>
              <div class="px-4">
                <div class="text-xs text-gray-400 mb-1">Ключ 9</div>
                <div class={"font-bold #{if @breakdown.key_valid, do: "text-green-600", else: "text-red-600"}"}>
                  <%= @breakdown.key_digit %>
                </div>
              </div>
              <div class="pl-4 flex-1">
                <div class="text-xs text-gray-400 mb-1">Лицевой 10–20</div>
                <div class="font-bold text-gray-800 tracking-wider"><%= @breakdown.unique %></div>
              </div>
            </div>

            <%!-- Result banner --%>
            <div class={"px-4 py-2 font-semibold #{if @breakdown.key_valid, do: "bg-green-500 text-white", else: "bg-red-500 text-white"}"}>
              <%= if @breakdown.key_valid do %>
                ✓ Счёт корректен
              <% else %>
                ✗ Неверный контрольный ключ — ожидался <%= @breakdown.calculated_key %>
              <% end %>
            </div>

            <%!-- Field details --%>
            <dl class="divide-y divide-gray-100">

              <div class="px-4 py-3">
                <dt class="font-medium text-gray-700">
                  МФО — код филиала банка
                  <code class="ml-2 bg-gray-100 px-1 rounded text-xs"><%= @breakdown.mfo %></code>
                </dt>
                <dd class="mt-0.5 text-gray-500">
                  Идентифицирует конкретный филиал банка в системе ЦБ Узбекистана.
                </dd>
              </div>

              <div class="px-4 py-3">
                <dt class="font-medium text-gray-700">
                  Разряды 1–5 — Балансовый счёт
                  <code class="ml-2 bg-gray-100 px-1 rounded text-xs"><%= @breakdown.balance_code %></code>
                </dt>
                <dd class="mt-0.5 text-gray-500"><%= @breakdown.balance_desc %></dd>
              </div>

              <div class="px-4 py-3">
                <dt class="font-medium text-gray-700">
                  Разряды 6–8 — Код валюты
                  <code class="ml-2 bg-gray-100 px-1 rounded text-xs"><%= @breakdown.currency_code %></code>
                </dt>
                <dd class="mt-0.5 text-gray-500"><%= @breakdown.currency_desc %></dd>
              </div>

              <div class="px-4 py-3">
                <dt class="font-medium text-gray-700">
                  Разряд 9 — Контрольный ключ
                  <code class={"ml-2 px-1 rounded text-xs #{if @breakdown.key_valid, do: "bg-green-100 text-green-700", else: "bg-red-100 text-red-700"}"}>
                    <%= @breakdown.key_digit %>
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
                  Рассчитан по
                  <%= if @method == "m1" do %>
                    <strong>Методу 1</strong> — весовые коэффициенты 7·1·3 (mod 10).
                  <% else %>
                    <strong>Методу 2</strong> — сумма произведений соседних пар, mod 11.
                  <% end %>
                  Защищает от ошибок при вводе номера.
                </dd>
              </div>

              <div class="px-4 py-3">
                <dt class="font-medium text-gray-700">
                  Разряды 10–20 — Лицевой счёт
                  <code class="ml-2 bg-gray-100 px-1 rounded text-xs"><%= @breakdown.unique %></code>
                </dt>
                <dd class="mt-1 text-gray-500 space-y-1">
                  <div>
                    Идентификатор НИББД (10–17):
                    <code class="bg-gray-100 px-1 rounded text-xs"><%= @breakdown.nibd %></code>
                    — уникальный регистрационный номер клиента в базе данных.
                  </div>
                  <div>
                    Порядковый номер счёта (18–20):
                    <code class="bg-gray-100 px-1 rounded text-xs"><%= @breakdown.seq %></code>
                    — номер счёта клиента внутри данного филиала.
                  </div>
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
