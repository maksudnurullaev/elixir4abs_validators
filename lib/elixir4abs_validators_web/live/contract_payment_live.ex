defmodule Elixir4absValidatorsWeb.ContractPaymentLive do
  use Elixir4absValidatorsWeb, :live_view

  alias Elixir4ABS.ContractPayment

  @tabs ~w(get_contract create_payment action get_status)a

  # ── Mount ─────────────────────────────────────────────────────────────────────

  @impl true
  def mount(_params, _session, socket) do
    txn_id = ContractPayment.generate_txn_id()

    socket =
      socket
      |> assign(
        tab: :get_contract,
        api_key: System.get_env("TIU_API_KEY", ""),
        secret_key: System.get_env("TIU_SECRET_KEY", ""),
        creds_open: true,
        # GetContract
        gc_pinfl: "12345678901234",
        gc_type: "1",
        # CreatePayment
        cp_txn_id: txn_id,
        cp_pinfl: "12345678901234",
        cp_amount: "5000000",
        cp_full_name: "Aliyev Jasur Karimovich",
        cp_contract: "C-2024-001",
        cp_uni_code: "UNI001",
        cp_org_account: "40702840900000001234",
        cp_date: ContractPayment.default_payment_date(),
        cp_type: "1",
        # Action
        ac_txn_id: txn_id,
        ac_action: "2",
        # GetStatus
        gs_txn_id: txn_id,
        # UI state
        tabs: @tabs,
        preview: nil,
        loading: false,
        response: nil,
        error: nil
      )
      |> rebuild_preview()

    {:ok, socket}
  end

  # ── Events ────────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("switch_tab", %{"tab" => tab_str}, socket) do
    tab = Enum.find(@tabs, :get_contract, &(to_string(&1) == tab_str))
    socket = socket |> assign(tab: tab, response: nil, error: nil) |> rebuild_preview()
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_creds", _, socket) do
    {:noreply, assign(socket, creds_open: !socket.assigns.creds_open)}
  end

  @impl true
  def handle_event("update_creds", params, socket) do
    socket =
      socket
      |> assign(
        api_key: Map.get(params, "api_key", socket.assigns.api_key),
        secret_key: Map.get(params, "secret_key", socket.assigns.secret_key)
      )
      |> rebuild_preview()

    {:noreply, socket}
  end

  @impl true
  def handle_event("rebuild", params, socket) do
    socket = socket |> update_tab_assigns(params) |> rebuild_preview()
    {:noreply, socket}
  end

  @impl true
  def handle_event("regen_txn", _, socket) do
    new_id = ContractPayment.generate_txn_id()

    socket =
      case socket.assigns.tab do
        :create_payment -> assign(socket, cp_txn_id: new_id, ac_txn_id: new_id, gs_txn_id: new_id)
        :action -> assign(socket, ac_txn_id: new_id)
        :get_status -> assign(socket, gs_txn_id: new_id)
        _ -> assign(socket, cp_txn_id: new_id, ac_txn_id: new_id, gs_txn_id: new_id)
      end
      |> rebuild_preview()

    {:noreply, socket}
  end

  @impl true
  def handle_event("execute", _, socket) do
    request = build_request_from_assigns(socket.assigns)

    socket =
      socket
      |> assign(loading: true, response: nil, error: nil, preview: request)
      |> start_async(:api_call, fn -> ContractPayment.execute(request) end)

    {:noreply, socket}
  end

  # ── Async ─────────────────────────────────────────────────────────────────────

  @impl true
  def handle_async(:api_call, {:ok, {:ok, response}}, socket) do
    {:noreply, assign(socket, loading: false, response: response)}
  end

  @impl true
  def handle_async(:api_call, {:ok, {:error, reason}}, socket) do
    {:noreply, assign(socket, loading: false, error: reason)}
  end

  @impl true
  def handle_async(:api_call, {:exit, reason}, socket) do
    {:noreply, assign(socket, loading: false, error: "Процесс завершился с ошибкой: #{inspect(reason)}")}
  end

  # ── Private helpers ───────────────────────────────────────────────────────────

  defp update_tab_assigns(socket, params) do
    a = socket.assigns

    case a.tab do
      :get_contract ->
        assign(socket,
          gc_pinfl: Map.get(params, "pinfl", a.gc_pinfl),
          gc_type: Map.get(params, "type", a.gc_type)
        )

      :create_payment ->
        assign(socket,
          cp_txn_id: Map.get(params, "txn_id", a.cp_txn_id),
          cp_pinfl: Map.get(params, "pinfl", a.cp_pinfl),
          cp_amount: Map.get(params, "amount", a.cp_amount),
          cp_full_name: Map.get(params, "full_name", a.cp_full_name),
          cp_contract: Map.get(params, "contract", a.cp_contract),
          cp_uni_code: Map.get(params, "uni_code", a.cp_uni_code),
          cp_org_account: Map.get(params, "org_account", a.cp_org_account),
          cp_date: Map.get(params, "date", a.cp_date),
          cp_type: Map.get(params, "type", a.cp_type)
        )

      :action ->
        assign(socket,
          ac_txn_id: Map.get(params, "txn_id", a.ac_txn_id),
          ac_action: Map.get(params, "action", a.ac_action)
        )

      :get_status ->
        assign(socket, gs_txn_id: Map.get(params, "txn_id", a.gs_txn_id))
    end
  end

  defp rebuild_preview(socket) do
    assign(socket, preview: build_request_from_assigns(socket.assigns))
  end

  defp build_request_from_assigns(a) do
    case a.tab do
      :get_contract ->
        ContractPayment.build_get_contract(a.gc_pinfl, parse_int(a.gc_type, 1), a.api_key, a.secret_key)

      :create_payment ->
        ContractPayment.build_create_payment(
          %{
            txn_id: a.cp_txn_id,
            pinfl: a.cp_pinfl,
            amount: a.cp_amount,
            full_name: a.cp_full_name,
            contract_number: a.cp_contract,
            university_code: a.cp_uni_code,
            org_account: a.cp_org_account,
            payment_date: a.cp_date,
            contract_type_id: a.cp_type
          },
          a.api_key,
          a.secret_key
        )

      :action ->
        ContractPayment.build_action(a.ac_txn_id, parse_int(a.ac_action, 2), a.api_key, a.secret_key)

      :get_status ->
        ContractPayment.build_get_status(a.gs_txn_id, a.api_key, a.secret_key)
    end
  end

  defp parse_int(str, default) when is_binary(str) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_int(n, _) when is_integer(n), do: n
  defp parse_int(_, default), do: default

  defp format_request_preview(nil), do: "Заполните форму..."

  defp format_request_preview(%{method: method, url: url, headers: headers, body: body}) do
    uri = URI.parse(url)
    path_qs = (uri.path || "/") <> if(uri.query, do: "?#{uri.query}", else: "")
    header_lines = Enum.map_join(headers, "\n", fn {k, v} -> "#{k}: #{v}" end)
    base = "#{method} #{path_qs} HTTP/1.1\nHost: #{uri.host}\n#{header_lines}"
    if body, do: base <> "\n\n" <> body, else: base
  end

  defp status_color(status) when status >= 200 and status < 300, do: "text-green-400"
  defp status_color(status) when status >= 400 and status < 500, do: "text-amber-400"
  defp status_color(status) when status >= 500, do: "text-red-400"
  defp status_color(_), do: "text-gray-400"

  defp tab_label(:get_contract), do: "GetContract"
  defp tab_label(:create_payment), do: "CreatePayment"
  defp tab_label(:action), do: "Confirm / Cancel"
  defp tab_label(:get_status), do: "GetPaymentStatus"

  defp tab_desc(:get_contract), do: "GET /PaymentGateway/GetContract — данные контракта студента по ПИНФЛ"
  defp tab_desc(:create_payment), do: "POST /PaymentGateway/HandlePayment (action=1) — создание платежа"
  defp tab_desc(:action), do: "POST /PaymentGateway/HandlePayment (action=2/-2) — подтверждение или отмена"
  defp tab_desc(:get_status), do: "GET /PaymentGateway/GetPaymentStatus — статус платежа по ID транзакции"

  # ── Template ──────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-8 px-4">
      <div class="max-w-6xl mx-auto">

        <a href={~p"/"} class="text-sm text-blue-600 hover:underline">← На главную</a>
        <h1 class="text-2xl font-bold text-gray-800 mt-3 mb-1">TIU Contract Payments — APEX</h1>
        <p class="text-sm text-gray-500 mb-5">
          Интерактивный тест API <code class="bg-gray-100 px-1 rounded">billing.mystudent.uz</code>
          · HMAC-SHA256 аутентификация
        </p>

        <%!-- Credentials panel --%>
        <div class="bg-white border border-gray-200 rounded-2xl mb-5 overflow-hidden">
          <button
            phx-click="toggle_creds"
            class="w-full flex items-center justify-between px-5 py-3 text-sm font-medium text-gray-700 hover:bg-gray-50 transition"
          >
            <span class="flex items-center gap-2">
              <span class={"w-2 h-2 rounded-full #{if @api_key != "" and @secret_key != "", do: "bg-green-400", else: "bg-amber-400"}"}>
              </span>
              Реквизиты APEX (API Key + Secret Key)
            </span>
            <span class="text-gray-400 text-xs">{if @creds_open, do: "▲", else: "▼"}</span>
          </button>

          <%= if @creds_open do %>
            <div class="border-t border-gray-100 px-5 py-4">
              <form phx-change="update_creds" class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label class="block text-xs font-medium text-gray-600 mb-1">
                    X-Api-Key
                  </label>
                  <input
                    type="text"
                    name="api_key"
                    value={@api_key}
                    placeholder="01ee4f9f..."
                    autocomplete="off"
                    class="w-full border border-gray-300 rounded-lg px-3 py-2 font-mono text-xs focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
                <div>
                  <label class="block text-xs font-medium text-gray-600 mb-1">
                    Secret Key (HMAC)
                  </label>
                  <input
                    type="password"
                    name="secret_key"
                    value={@secret_key}
                    placeholder="1018b851..."
                    autocomplete="new-password"
                    class="w-full border border-gray-300 rounded-lg px-3 py-2 font-mono text-xs focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
              </form>
              <%= if @api_key == "" or @secret_key == "" do %>
                <p class="mt-2 text-xs text-amber-600">
                  Заполните реквизиты для корректной подписи запросов. Поля можно задать через
                  переменные среды <code class="bg-amber-50 px-1 rounded">TIU_API_KEY</code>
                  и <code class="bg-amber-50 px-1 rounded">TIU_SECRET_KEY</code>.
                </p>
              <% end %>
            </div>
          <% end %>
        </div>

        <%!-- Tab bar --%>
        <div class="flex flex-wrap gap-2 mb-2">
          <%= for t <- @tabs do %>
            <button
              phx-click="switch_tab"
              phx-value-tab={to_string(t)}
              class={[
                "px-4 py-2 text-sm rounded-lg font-medium transition",
                if(t == @tab,
                  do: "bg-blue-600 text-white shadow-sm",
                  else: "bg-white border border-gray-200 text-gray-600 hover:bg-gray-50"
                )
              ]}
            >
              {tab_label(t)}
            </button>
          <% end %>
        </div>
        <p class="text-xs text-gray-400 mb-5">{tab_desc(@tab)}</p>

        <%!-- Main grid --%>
        <div class="grid grid-cols-1 lg:grid-cols-5 gap-5">

          <%!-- LEFT: Input form (2/5) --%>
          <div class="lg:col-span-2">
            <div class="bg-white border border-gray-200 rounded-2xl p-5">
              <h2 class="text-sm font-semibold text-gray-700 mb-4">Параметры запроса</h2>

              <%= if @tab == :get_contract do %>
                <form phx-change="rebuild" class="space-y-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-600 mb-1">
                      ПИНФЛ студента <span class="text-gray-400">(14 цифр)</span>
                    </label>
                    <input
                      type="text" name="pinfl" value={@gc_pinfl} maxlength="14"
                      autocomplete="off"
                      class="w-full border border-gray-300 rounded-lg px-3 py-2 font-mono text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-600 mb-1">
                      Тип контракта
                    </label>
                    <select
                      name="type"
                      class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="1" selected={@gc_type == "1"}>1 — CONTRACT (по умолчанию)</option>
                      <option value="2" selected={@gc_type == "2"}>2 — CREDIT (образовательный кредит)</option>
                    </select>
                  </div>
                </form>
              <% end %>

              <%= if @tab == :create_payment do %>
                <form phx-change="rebuild" class="space-y-3">
                  <div>
                    <label class="block text-xs font-medium text-gray-600 mb-1">
                      ID транзакции
                    </label>
                    <div class="flex gap-2">
                      <input
                        type="text" name="txn_id" value={@cp_txn_id}
                        autocomplete="off"
                        class="flex-1 border border-gray-300 rounded-lg px-3 py-2 font-mono text-xs focus:outline-none focus:ring-2 focus:ring-blue-500"
                      />
                      <button
                        type="button" phx-click="regen_txn"
                        title="Новый ID"
                        class="px-3 py-2 border border-gray-300 rounded-lg text-gray-500 hover:bg-gray-50 transition text-sm"
                      >
                        ↺
                      </button>
                    </div>
                  </div>
                  <div class="grid grid-cols-2 gap-2">
                    <div>
                      <label class="block text-xs font-medium text-gray-600 mb-1">ПИНФЛ</label>
                      <input
                        type="text" name="pinfl" value={@cp_pinfl} maxlength="14"
                        autocomplete="off"
                        class="w-full border border-gray-300 rounded-lg px-3 py-2 font-mono text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                      />
                    </div>
                    <div>
                      <label class="block text-xs font-medium text-gray-600 mb-1">Сумма (сум)</label>
                      <input
                        type="text" name="amount" value={@cp_amount}
                        class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                      />
                    </div>
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-600 mb-1">ФИО плательщика</label>
                    <input
                      type="text" name="full_name" value={@cp_full_name}
                      class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                  <div class="grid grid-cols-2 gap-2">
                    <div>
                      <label class="block text-xs font-medium text-gray-600 mb-1">Номер контракта</label>
                      <input
                        type="text" name="contract" value={@cp_contract}
                        class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                      />
                    </div>
                    <div>
                      <label class="block text-xs font-medium text-gray-600 mb-1">Код универ.</label>
                      <input
                        type="text" name="uni_code" value={@cp_uni_code}
                        class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                      />
                    </div>
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-600 mb-1">Счёт организации</label>
                    <input
                      type="text" name="org_account" value={@cp_org_account} maxlength="20"
                      class="w-full border border-gray-300 rounded-lg px-3 py-2 font-mono text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                  <div class="grid grid-cols-2 gap-2">
                    <div>
                      <label class="block text-xs font-medium text-gray-600 mb-1">Дата платежа</label>
                      <input
                        type="text" name="date" value={@cp_date}
                        placeholder="YYYY-MM-DDTHH:MM:SS"
                        class="w-full border border-gray-300 rounded-lg px-3 py-2 font-mono text-xs focus:outline-none focus:ring-2 focus:ring-blue-500"
                      />
                    </div>
                    <div>
                      <label class="block text-xs font-medium text-gray-600 mb-1">Тип контракта</label>
                      <select
                        name="type"
                        class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                      >
                        <option value="1" selected={@cp_type == "1"}>1 — CONTRACT</option>
                        <option value="2" selected={@cp_type == "2"}>2 — CREDIT</option>
                      </select>
                    </div>
                  </div>
                </form>
              <% end %>

              <%= if @tab == :action do %>
                <form phx-change="rebuild" class="space-y-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-600 mb-1">ID транзакции</label>
                    <div class="flex gap-2">
                      <input
                        type="text" name="txn_id" value={@ac_txn_id}
                        autocomplete="off"
                        class="flex-1 border border-gray-300 rounded-lg px-3 py-2 font-mono text-xs focus:outline-none focus:ring-2 focus:ring-blue-500"
                      />
                      <button
                        type="button" phx-click="regen_txn"
                        title="Новый ID"
                        class="px-3 py-2 border border-gray-300 rounded-lg text-gray-500 hover:bg-gray-50 transition text-sm"
                      >
                        ↺
                      </button>
                    </div>
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-600 mb-1">Операция</label>
                    <select
                      name="action"
                      class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="2" selected={@ac_action == "2"}>
                        action=2 — Подтверждение платежа
                      </option>
                      <option value="-2" selected={@ac_action == "-2"}>
                        action=-2 — Отмена платежа
                      </option>
                    </select>
                  </div>
                  <%= if @ac_action == "-2" do %>
                    <div class="bg-amber-50 border border-amber-200 rounded-lg px-4 py-3 text-xs text-amber-700">
                      Отмена возможна только для платежей в статусе
                      <strong>ACCEPTED</strong> (status_id=2).
                      Для переведённых платежей API вернёт 400.
                    </div>
                  <% end %>
                  <%= if @ac_action == "2" do %>
                    <div class="bg-blue-50 border border-blue-100 rounded-lg px-4 py-3 text-xs text-blue-700">
                      Подтверждение выполняется <strong>асинхронно</strong>.
                      Проверьте итоговый статус через вкладку GetPaymentStatus.
                    </div>
                  <% end %>
                </form>
              <% end %>

              <%= if @tab == :get_status do %>
                <form phx-change="rebuild" class="space-y-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-600 mb-1">ID транзакции</label>
                    <div class="flex gap-2">
                      <input
                        type="text" name="txn_id" value={@gs_txn_id}
                        autocomplete="off"
                        class="flex-1 border border-gray-300 rounded-lg px-3 py-2 font-mono text-xs focus:outline-none focus:ring-2 focus:ring-blue-500"
                      />
                      <button
                        type="button" phx-click="regen_txn"
                        title="Новый ID"
                        class="px-3 py-2 border border-gray-300 rounded-lg text-gray-500 hover:bg-gray-50 transition text-sm"
                      >
                        ↺
                      </button>
                    </div>
                  </div>
                </form>

                <div class="mt-4 bg-gray-50 rounded-lg p-3 text-xs text-gray-500">
                  <p class="font-medium text-gray-600 mb-2">Статусы платежа:</p>
                  <div class="space-y-1">
                    <div><code class="bg-gray-100 px-1 rounded">1</code> — Создан (внутренний)</div>
                    <div><code class="bg-blue-100 text-blue-700 px-1 rounded">2</code> — ACCEPTED · Принят, ожидает подтверждения</div>
                    <div><code class="bg-green-100 text-green-700 px-1 rounded">3</code> — TRANSFERRED · Средства зачислены</div>
                    <div><code class="bg-amber-100 text-amber-700 px-1 rounded">4</code> — RETURNED · Отменён</div>
                    <div><code class="bg-red-100 text-red-700 px-1 rounded">5</code> — FAILED · Ошибка</div>
                  </div>
                </div>
              <% end %>

              <button
                type="button"
                phx-click="execute"
                disabled={@loading}
                class={[
                  "mt-5 w-full py-2.5 px-4 rounded-lg text-sm font-semibold transition",
                  if(@loading,
                    do: "bg-gray-200 text-gray-400 cursor-not-allowed",
                    else: "bg-blue-600 text-white hover:bg-blue-700 active:bg-blue-800"
                  )
                ]}
              >
                <%= if @loading do %>
                  <span class="inline-flex items-center gap-2">
                    <span class="animate-spin">⟳</span> Отправка...
                  </span>
                <% else %>
                  Отправить запрос →
                <% end %>
              </button>
            </div>
          </div>

          <%!-- RIGHT: Preview + Response (3/5) --%>
          <div class="lg:col-span-3 flex flex-col gap-4">

            <%!-- Request preview --%>
            <div class="bg-gray-900 rounded-2xl overflow-hidden">
              <div class="flex items-center justify-between px-5 py-3 border-b border-gray-700">
                <span class="text-xs text-gray-400 uppercase tracking-wide font-medium">HTTP запрос</span>
                <%= if @preview do %>
                  <span class="text-xs font-mono px-2 py-0.5 rounded bg-blue-800 text-blue-200">
                    {@preview.method}
                  </span>
                <% end %>
              </div>
              <pre class="text-xs font-mono text-green-300 px-5 py-4 whitespace-pre-wrap break-all overflow-y-auto max-h-80 leading-relaxed"><%= format_request_preview(@preview) %></pre>
            </div>

            <%!-- Response --%>
            <%= if @response || @error do %>
              <div class="bg-white border border-gray-200 rounded-2xl overflow-hidden">
                <div class="flex items-center gap-3 px-5 py-3 border-b border-gray-100">
                  <span class="text-sm font-semibold text-gray-700">Ответ сервера</span>
                  <%= if @response do %>
                    <span class={"text-sm font-mono font-bold #{status_color(@response.status)}"}>
                      HTTP {@response.status}
                    </span>
                  <% end %>
                </div>
                <%= if @error do %>
                  <div class="px-5 py-4 text-sm text-red-600 font-mono">{@error}</div>
                <% end %>
                <%= if @response do %>
                  <pre class="text-xs font-mono text-gray-700 bg-gray-50 px-5 py-4 overflow-y-auto max-h-64 whitespace-pre-wrap leading-relaxed"><%= ContractPayment.format_body(@response.body) %></pre>
                <% end %>
              </div>
            <% end %>

            <%!-- Happy path hint --%>
            <%= if is_nil(@response) and not @loading do %>
              <div class="bg-blue-50 border border-blue-100 rounded-2xl p-5 text-xs text-blue-700">
                <p class="font-semibold text-blue-800 mb-2">Happy path интеграции:</p>
                <ol class="list-decimal list-inside space-y-1">
                  <li>
                    <strong>GetContract</strong> — получить данные контракта по ПИНФЛ
                  </li>
                  <li>
                    <strong>CreatePayment</strong> — создать платёж (action=1) → статус ACCEPTED
                  </li>
                  <li>
                    <strong>Confirm</strong> — подтвердить (action=2) → обработка асинхронно
                  </li>
                  <li>
                    <strong>GetPaymentStatus</strong> — проверить, что статус стал TRANSFERRED (3)
                  </li>
                </ol>
              </div>
            <% end %>

          </div>
        </div>

      </div>
    </div>
    """
  end
end
