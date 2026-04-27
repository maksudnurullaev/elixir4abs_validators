defmodule Elixir4absValidatorsWeb.HomeLive do
  use Elixir4absValidatorsWeb, :live_view

  alias Elixir4ABS.Rules.Registry

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, authenticated: false, password_error: false, password: "")}
  end

  @impl true
  def handle_event("check_password", %{"password" => input}, socket) do
    today = Date.utc_today() |> Calendar.strftime("%Y%m%d")

    if input == today do
      rulesets = Registry.all()
      features = build_features(rulesets)
      {:noreply, assign(socket, authenticated: true, features: features)}
    else
      {:noreply, assign(socket, password_error: true, password: "")}
    end
  end

  def handle_event("update_password", %{"password" => val}, socket) do
    {:noreply, assign(socket, password: val, password_error: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @authenticated do %>
      <div class="min-h-screen bg-gray-50">
        <%!-- Hero --%>
        <div class="bg-white border-b border-gray-200 px-6 py-12 text-center">
          <div class="inline-block bg-blue-50 text-blue-700 text-xs font-semibold px-3 py-1 rounded-full mb-4 tracking-wide uppercase">
            Elixir · Phoenix LiveView · BEAM
          </div>
          <h1 class="text-3xl font-bold text-gray-900 mb-3">Elixir4ABS Validators</h1>
          <p class="text-gray-500 max-w-xl mx-auto">
            Прототип инструментов валидации и визуализации бизнес-правил
            для автоматизированной банковской системы (АБС) на базе Elixir.
          </p>
        </div>

        <%!-- Feature cards --%>
        <div class="max-w-4xl mx-auto px-6 py-10 grid grid-cols-1 md:grid-cols-2 gap-6">
          <%= for feature <- @features do %>
            <a
              href={feature.href}
              class="group bg-white rounded-2xl border border-gray-200 p-6 flex flex-col hover:border-blue-400 hover:shadow-md transition"
            >
              <div class="flex items-start justify-between mb-3">
                <h2 class="text-lg font-semibold text-gray-800 group-hover:text-blue-700 transition leading-tight">
                  {feature.title}
                </h2>
                <span class="ml-3 shrink-0 text-xs bg-blue-50 text-blue-600 font-medium px-2 py-0.5 rounded-full">
                  {feature.badge}
                </span>
              </div>

              <p class="text-sm text-gray-500 mb-4 leading-relaxed">{feature.description}</p>

              <ul class="mt-auto space-y-1">
                <%= for item <- feature.items do %>
                  <li class="flex items-center gap-2 text-xs text-gray-400">
                    <span class="w-1.5 h-1.5 rounded-full bg-blue-300 shrink-0"></span>
                    {item}
                  </li>
                <% end %>
              </ul>

              <div class="mt-5 text-sm font-medium text-blue-600 group-hover:underline">
                Открыть →
              </div>
            </a>
          <% end %>
        </div>

        <%!-- Footer --%>
        <div class="text-center text-xs text-gray-400 pb-8">
          Elixir4ABS · валидаторы v0.1.0 ·
          <a
            href="https://github.com/maksudnurullaev/elixir4abs_validators"
            class="hover:text-gray-600 underline"
            target="_blank"
          >
            GitHub
          </a>
        </div>
      </div>
    <% else %>
      <div class="min-h-screen bg-gray-50 flex items-center justify-center">
        <div class="bg-white rounded-2xl border border-gray-200 shadow-sm p-10 w-full max-w-sm text-center">
          <div class="text-4xl mb-4">🚧</div>
          <h1 class="text-xl font-bold text-gray-800 mb-2">Page is under construction</h1>
          <p class="text-sm text-gray-500 mb-8">
            This page is not yet publicly available.<br />Enter the access password to continue.
          </p>

          <form phx-submit="check_password" phx-change="update_password" class="space-y-4">
            <input
              type="password"
              name="password"
              value={@password}
              placeholder="Password"
              autocomplete="off"
              class={[
                "w-full px-4 py-2 rounded-lg border text-sm text-gray-800 focus:outline-none focus:ring-2 focus:ring-blue-400",
                if(@password_error, do: "border-red-400 bg-red-50", else: "border-gray-300")
              ]}
            />
            <%= if @password_error do %>
              <p class="text-xs text-red-500 text-left">Incorrect password. Try again.</p>
            <% end %>
            <button
              type="submit"
              class="w-full bg-blue-600 hover:bg-blue-700 text-white text-sm font-medium py-2 rounded-lg transition"
            >
              Enter
            </button>
          </form>
        </div>
      </div>
    <% end %>
    """
  end

  defp build_features(rulesets) do
    [
      %{
        title: "Валидатор банковского счёта",
        description:
          "Проверка 20-значного расчётного счёта банков Узбекистана. " <>
            "Поддерживает два алгоритма ЦБ: Метод 1 (весовые коэффициенты) " <>
            "и Метод 2 (mod 11, межбанковский клиринг). " <>
            "Расшифровка каждого поля номера: баланс, валюта, контрольный ключ, лицевой счёт.",
        href: ~p"/validators/account",
        badge: "2 метода",
        items: [
          "Метод 1 — 7·1·3, mod 10",
          "Метод 2 — mod 11 (клиринг ЦБ)",
          "Расшифровка структуры счёта",
          "Идентификатор НИББД"
        ]
      },
      %{
        title: "SWIFT ISO 20022 — pacs.008",
        description:
          "Парсинг и валидация FI-to-FI Customer Credit Transfer. " <>
            "Разбирает XML-сообщение формата pacs.008.001.08, проверяет namespace, " <>
            "обязательные поля, форматы дат и сумм. " <>
            "Отображает заголовок и все транзакции с дебитором, кредитором и назначением платежа.",
        href: ~p"/validators/swift-pacs008",
        badge: "ISO 20022",
        items: [
          "Парсинг XML через SweetXml",
          "Проверка namespace pacs.008.001.08",
          "Валидация IBAN, BIC, суммы, даты",
          "Поддержка множества транзакций"
        ]
      },
      %{
        title: "Генератор QR-платежей",
        description:
          "Имитация генерации платёжных QR-кодов для продавцов банка. " <>
            "Модуль генерирует уникальный ID транзакции (timestamp + random), " <>
            "упаковывает данные (магазин, счёт МФО, сумму, TTL) в схему APEX://pay " <>
            "и рендерит SVG-QR. Покупатель сканирует через любое банковское приложение.",
        href: ~p"/validators/qr-payment",
        badge: "QR / P2M",
        items: [
          "Уникальный TXN ID · timestamp + 4 байта",
          "Схема APEX://pay?merchant=…",
          "SVG QR — обновление в реальном времени",
          "5 примеров продавцов · TTL · валюта"
        ]
      },
      %{
        title: "Таблицы решений",
        description:
          "Бизнес-правила банка, скомпилированные из Elixir-макросов в байткод BEAM. " <>
            "Просмотр таблиц и симуляция — без доступа к исходному коду. " <>
            "Сработавшая строка подсвечивается в таблице.",
        href: ~p"/rules",
        badge: "#{map_size(rulesets)} таблицы",
        items: Enum.map(rulesets, fn {_k, cfg} -> cfg.title end)
      }
    ]
  end
end
