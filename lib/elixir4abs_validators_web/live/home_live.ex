defmodule Elixir4absValidatorsWeb.HomeLive do
  use Elixir4absValidatorsWeb, :live_view

  alias Elixir4ABS.Rules.Registry

  @impl true
  def mount(_params, _session, socket) do
    rulesets = Registry.all()

    features = [
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
        title: "TIU Contract Payments — APEX",
        description:
          "Интерактивный тестировщик API billing.mystudent.uz для оплаты образовательных контрактов. " <>
            "Строит HMAC-SHA256 подписанные запросы в реальном времени и выполняет их напрямую. " <>
            "Покрывает полный happy path: GetContract → CreatePayment → Confirm → GetStatus.",
        href: ~p"/validators/contract-payment",
        badge: "TIU / APEX",
        items: [
          "HMAC-SHA256 · X-Api-Key · X-Timestamp",
          "GetContract — контракт студента по ПИНФЛ",
          "HandlePayment — создание, подтверждение, отмена",
          "GetPaymentStatus — статусы 1..5 (ACCEPTED→TRANSFERRED)"
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

    {:ok, assign(socket, features: features)}
  end

  @impl true
  def render(assigns) do
    ~H"""
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
    """
  end
end
