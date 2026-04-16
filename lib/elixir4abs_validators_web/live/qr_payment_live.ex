defmodule Elixir4absValidatorsWeb.QrPaymentLive do
  use Elixir4absValidatorsWeb, :live_view

  alias Elixir4ABS.QrPayment

  # ── Справочник продавцов ─────────────────────────────────────────────────────

  @merchants [
    %{
      merchant_id: "MRC-KORZINKA",
      label:       "Korzinka Supermarket",
      mfo:         "00774",
      account:     "23001000712345678001",
      amount:      "150000",
      currency:    "860",
      hint:        "Розничная сеть супермаркетов · Hamkorbank · UZS"
    },
    %{
      merchant_id: "MRC-DORIDARM",
      label:       "Dori-Darmon Pharmacy",
      mfo:         "00444",
      account:     "23001000312345678002",
      amount:      "35500",
      currency:    "860",
      hint:        "Государственная аптечная сеть · Asaka Bank · UZS"
    },
    %{
      merchant_id: "MRC-SAMARKAND",
      label:       "Restoran Samarkand",
      mfo:         "01007",
      account:     "23001000912345678003",
      amount:      "280000",
      currency:    "860",
      hint:        "Ресторан национальной кухни · NBU · UZS"
    },
    %{
      merchant_id: "MRC-UZUM",
      label:       "Uzum Online Shop",
      mfo:         "00878",
      account:     "23001001012345678004",
      amount:      "99900",
      currency:    "860",
      hint:        "Интернет-магазин · Kapital Bank · UZS"
    },
    %{
      merchant_id: "MRC-TAXI",
      label:       "Taxi Express UZ",
      mfo:         "00555",
      account:     "20208000512345678005",
      amount:      "45000",
      currency:    "860",
      hint:        "Служба такси · Ipak Yuli · UZS"
    }
  ]

  # Фиксированный TTL — 5 минут
  @ttl 300

  # ── Mount ────────────────────────────────────────────────────────────────────

  @impl true
  def mount(_params, _session, socket) do
    first = hd(@merchants)

    socket =
      socket
      |> assign(
        merchants:   @merchants,
        ccy_opts:    QrPayment.currencies(),
        merchant_id: first.merchant_id,
        mfo:         first.mfo,
        account:     first.account,
        amount:      first.amount,
        currency:    first.currency,
        txid:        QrPayment.generate_txid(),
        qr_svg:      nil,
        payload:     nil,
        expires_at:  nil,
        error:       nil
      )
      |> generate_qr()

    {:ok, socket}
  end

  # ── Events ───────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("regenerate_txid", _params, socket) do
    {:noreply, socket |> assign(txid: QrPayment.generate_txid()) |> generate_qr()}
  end

  @impl true
  def handle_event("update", params, socket) do
    new_mid = Map.get(params, "merchant_id", socket.assigns.merchant_id)

    # Если продавец изменился — подгружаем его данные; иначе берём из формы
    base =
      if new_mid != socket.assigns.merchant_id do
        case Enum.find(@merchants, &(&1.merchant_id == new_mid)) do
          nil -> %{}
          m   -> %{mfo: m.mfo, account: m.account, amount: m.amount, currency: m.currency}
        end
      else
        amount = params |> Map.get("amount", "0") |> normalize_amount()

        %{
          mfo:      Map.get(params, "mfo",      socket.assigns.mfo),
          account:  Map.get(params, "account",  socket.assigns.account) |> String.replace(" ", ""),
          amount:   amount,
          currency: Map.get(params, "currency", socket.assigns.currency)
        }
      end

    socket =
      socket
      |> assign(Map.put(base, :merchant_id, new_mid))
      |> generate_qr()

    {:noreply, socket}
  end

  # ── QR generation ────────────────────────────────────────────────────────────

  defp generate_qr(socket) do
    a = socket.assigns

    payload =
      QrPayment.build_payload(%{
        merchant_id: a.merchant_id,
        account:     a.account,
        mfo:         a.mfo,
        amount:      a.amount,
        currency:    a.currency,
        txid:        a.txid,
        ttl:         @ttl
      })

    expires_at = QrPayment.format_expires_at(@ttl)

    case QrPayment.to_svg(payload) do
      {:ok, svg} ->
        assign(socket, qr_svg: svg, payload: payload, expires_at: expires_at, error: nil)

      {:error, reason} ->
        assign(socket, qr_svg: nil, payload: payload, expires_at: expires_at, error: inspect(reason))
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────

  # Принимает строку от пользователя, оставляет только цифры + десятичный разделитель.
  # Запятая или точка — тийины. "150.000,50" → "150000.50", "99900,50" → "99900.50"
  defp normalize_amount(str) do
    clean = String.replace(str, ~r/[^\d.,]/, "")

    result =
      cond do
        String.contains?(clean, ",") ->
          # запятая = десятичный разделитель; точки = разряды (убираем)
          clean |> String.replace(".", "") |> String.replace(",", ".")

        String.contains?(clean, ".") ->
          dot_count = clean |> String.graphemes() |> Enum.count(&(&1 == "."))
          if dot_count == 1 do
            clean                        # одна точка — десятичный разделитель
          else
            String.replace(clean, ".", "") # несколько точек — разряды (убираем)
          end

        true ->
          clean
      end

    if result in ["", "."], do: "0", else: result
  end

  defp merchant_label(merchants, merchant_id) do
    case Enum.find(merchants, &(&1.merchant_id == merchant_id)) do
      nil -> merchant_id
      m   -> m.label
    end
  end

  defp parse_payload_pairs(payload) do
    case String.split(payload, "?", parts: 2) do
      [_scheme, qs] -> URI.decode_query(qs) |> Enum.to_list()
      _             -> []
    end
  end

  # ── Template ─────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-8 px-4">
      <div class="w-full">

        <a href={~p"/"} class="text-sm text-blue-600 hover:underline">← На главную</a>

        <h1 class="text-2xl font-bold text-gray-800 mt-3 mb-1">
          Генератор QR-платежей
        </h1>
        <p class="text-sm text-gray-500 mb-6">
          Имитация генерации платёжных QR-кодов для продавцов ·
          покупатель сканирует через банковское приложение и деньги уходят напрямую со счёта на счёт
        </p>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">

          <%!-- LEFT: форма --%>
          <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6">
            <h2 class="text-sm font-semibold text-gray-700 mb-4">Параметры платежа</h2>

            <form phx-change="update" phx-submit="update" class="space-y-4">

              <%!-- Список продавцов --%>
              <div>
                <label class="block text-xs font-medium text-gray-600 mb-1">
                  Продавец
                </label>
                <select
                  name="merchant_id"
                  class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                >
                  <%= for m <- @merchants do %>
                    <option value={m.merchant_id} selected={m.merchant_id == @merchant_id}
                            title={m.hint}>
                      <%= m.label %>
                    </option>
                  <% end %>
                </select>
                <p class="text-xs text-gray-400 mt-1 font-mono"><%= @merchant_id %></p>
              </div>

              <div class="flex gap-3">
                <div class="w-32 shrink-0">
                  <label class="block text-xs font-medium text-gray-600 mb-1">МФО</label>
                  <input
                    type="text" name="mfo" value={@mfo} maxlength="5"
                    autocomplete="off"
                    class="w-full border border-gray-300 rounded-lg px-3 py-2 font-mono text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                  />
                </div>
                <div class="flex-1">
                  <label class="block text-xs font-medium text-gray-600 mb-1">
                    Расчётный счёт (20 цифр)
                  </label>
                  <input
                    type="text" name="account" value={@account} maxlength="20"
                    autocomplete="off"
                    class="w-full border border-gray-300 rounded-lg px-3 py-2 font-mono text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                  />
                </div>
              </div>

              <div class="flex gap-3">
                <div class="flex-1">
                  <label class="block text-xs font-medium text-gray-600 mb-1">Сумма</label>
                  <input
                    type="text" name="amount" value={@amount}
                    placeholder="150000,50"
                    class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                  />
                </div>
                <div class="w-36 shrink-0">
                  <label class="block text-xs font-medium text-gray-600 mb-1">Валюта</label>
                  <select
                    name="currency"
                    class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                  >
                    <%= for {code, label} <- @ccy_opts do %>
                      <option value={code} selected={code == @currency}><%= label %></option>
                    <% end %>
                  </select>
                </div>
              </div>

              <%!-- Действителен до --%>
              <div class="rounded-lg bg-amber-50 border border-amber-200 px-4 py-3">
                <p class="text-xs font-medium text-amber-700">Действителен до:</p>
                <p class="text-sm font-semibold text-amber-900 mt-0.5 font-mono">
                  <%= @expires_at %>
                </p>
              </div>

              <%!-- ID транзакции --%>
              <div>
                <label class="block text-xs font-medium text-gray-600 mb-1">
                  ID транзакции
                </label>
                <div class="flex gap-2 items-center">
                  <code class="flex-1 bg-gray-50 border border-gray-200 rounded-lg px-3 py-2 text-xs font-mono text-gray-700 truncate">
                    <%= @txid %>
                  </code>
                  <button
                    type="button"
                    phx-click="regenerate_txid"
                    title="Сгенерировать новый ID"
                    class="shrink-0 text-xs px-3 py-2 rounded-lg border border-gray-300 bg-white hover:bg-gray-50 text-gray-600 transition"
                  >
                    ↺
                  </button>
                </div>
                <p class="text-xs text-gray-400 mt-1">timestamp + 4 байта random</p>
              </div>

            </form>
          </div>

          <%!-- RIGHT: QR + payload --%>
          <div class="flex flex-col gap-4">

            <%!-- QR-код --%>
            <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6 flex flex-col items-center">
              <%= if @error do %>
                <div class="text-red-500 text-sm"><%= @error %></div>
              <% else %>
                <div class="rounded-xl overflow-hidden border border-gray-100">
                  <%= Phoenix.HTML.raw(@qr_svg) %>
                </div>
                <p class="mt-3 text-xs font-semibold text-emerald-700 text-center">
                  <%= merchant_label(@merchants, @merchant_id) %>
                </p>
                <p class="text-xs text-gray-400 text-center mt-0.5">
                  <%= QrPayment.format_amount(@amount) %> <%= QrPayment.currency_label(@currency) %>
                </p>
              <% end %>
            </div>

            <%!-- Разбивка payload --%>
            <%= if @payload do %>
              <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-5">
                <h3 class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">
                  Полезная нагрузка QR
                </h3>
                <code class="block text-xs font-mono text-gray-700 bg-gray-50 rounded-lg p-3 break-all leading-relaxed">
                  <%= @payload %>
                </code>
                <div class="mt-3 grid grid-cols-2 gap-x-4 gap-y-2 text-xs text-gray-500">
                  <%= for {k, v} <- parse_payload_pairs(@payload) do %>
                    <div class="flex gap-1">
                      <span class="font-medium text-gray-700"><%= k %>:</span>
                      <span class="truncate"><%= v %></span>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>

          </div>
        </div>

        <%!-- Как это работает --%>
        <div class="mt-6 bg-blue-50 border border-blue-100 rounded-2xl p-5 text-sm text-blue-800">
          <p class="font-semibold mb-2">Как это работает</p>
          <ol class="list-decimal list-inside space-y-1 text-xs text-blue-700">
            <li>Продавец выбирает себя из справочника — система подставляет МФО и счёт</li>
            <li>Генерируется уникальный TXN ID и вычисляется срок действия QR</li>
            <li>Покупатель сканирует QR любым банковским приложением</li>
            <li>Приложение декодирует <code class="bg-blue-100 px-1 rounded">APEX://pay?merchant_id=…</code> и предзаполняет перевод</li>
            <li>Покупатель подтверждает — деньги уходят напрямую со счёта на счёт</li>
          </ol>
        </div>

      </div>
    </div>
    """
  end
end
