defmodule Elixir4absValidatorsWeb.RulesIndexLive do
  use Elixir4absValidatorsWeb, :live_view

  alias Elixir4ABS.Rules.Registry

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, rulesets: Registry.all())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 p-6">
      <div class="w-full">
        <a href={~p"/"} class="block text-sm text-blue-600 hover:underline mb-4">← На главную</a>
        <h1 class="text-2xl font-bold text-gray-800 mb-1">Таблицы решений</h1>
        <p class="text-sm text-gray-500 mb-6">
          Бизнес-правила банка — просмотр и симуляция. Изменение только через деплой (git).
        </p>

        <div class="space-y-3">
          <%= for {key, cfg} <- @rulesets do %>
            <a
              href={~p"/rules/#{key}"}
              class="block bg-white rounded-xl border border-gray-200 px-5 py-4 hover:border-blue-400 hover:shadow-sm transition"
            >
              <div class="flex items-center justify-between">
                <div>
                  <div class="font-semibold text-gray-800">{cfg.title}</div>
                  <div class="text-sm text-gray-500 mt-0.5">{cfg.description}</div>
                </div>
                <div class="text-xs text-gray-400 font-mono bg-gray-50 px-2 py-1 rounded">
                  {length(rule_count(cfg.module))} правил
                </div>
              </div>
            </a>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp rule_count(module), do: module.__dt_rules_meta__()
end
