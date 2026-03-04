defmodule Elixir4absValidatorsWeb.RulesViewerLive do
  use Elixir4absValidatorsWeb, :live_view

  alias Elixir4ABS.Rules.Registry

  @impl true
  def mount(%{"ruleset" => key}, _session, socket) do
    case Registry.get(key) do
      nil ->
        {:ok, push_navigate(socket, to: ~p"/rules")}

      config ->
        {:ok,
         assign(socket,
           ruleset_key: key,
           config: config,
           rules: load_rules(config.module),
           inputs: initial_inputs(config.inputs),
           sim_result: nil,
           sim_matched: nil
         )}
    end
  end

  @impl true
  def handle_event("simulate", %{"inputs" => raw}, socket) do
    config = socket.assigns.config
    facts  = parse_inputs(raw, config.inputs)

    {result, matched} = run_simulation(config.module, facts, socket.assigns.rules, config.inputs)

    {:noreply, assign(socket, inputs: raw, sim_result: result, sim_matched: matched)}
  end

  # ── Helpers ─────────────────────────────────────────────────────────────────

  defp load_rules(module) do
    module.__dt_rules_meta__()
    |> Enum.with_index()   # {spec, 0-based index}
  end

  defp initial_inputs(input_configs) do
    Map.new(input_configs, fn cfg ->
      default = if cfg.type in [:select, :boolean], do: hd(cfg.options), else: ""
      {cfg.name, default}
    end)
  end

  defp parse_inputs(raw, input_configs) do
    Map.new(input_configs, fn cfg ->
      value = raw |> Map.get(cfg.name, "") |> coerce(cfg.type)
      {String.to_existing_atom(cfg.name), value}
    end)
  end

  defp coerce(v, :float) do
    case Float.parse(String.replace(v || "", ",", ".")) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp coerce(v, :integer) do
    case Integer.parse(v || "") do
      {i, _} -> i
      :error -> nil
    end
  end

  defp coerce(v, :select),  do: v
  defp coerce("true",  :boolean), do: true
  defp coerce(_,       :boolean), do: false

  defp run_simulation(module, facts, rules, input_configs) do
    if Enum.any?(Map.values(facts), &is_nil/1) do
      {{:error, "Заполните все поля корректно"}, nil}
    else
      result =
        try do
          {:ok, apply(module, :decide, [facts])}
        rescue
          FunctionClauseError -> {:error, "Ни одно правило не подошло"}
        end

      input_names = Enum.map(input_configs, &String.to_existing_atom(&1.name))
      n_inputs = length(input_names)

      matched =
        Enum.find_index(rules, fn {spec, _i} ->
          conditions = Enum.take(spec, n_inputs)

          Enum.zip(input_names, conditions)
          |> Enum.all?(fn {field, cond} -> matches?(Map.get(facts, field), cond) end)
        end)

      {result, matched}
    end
  end

  defp matches?(_val, :any),       do: true
  defp matches?(val, {lo, :inf}),  do: val >= lo
  defp matches?(val, {lo, hi}),    do: val >= lo and val <= hi
  defp matches?(val, expected),    do: val == expected

  defp format_cell({lo, :inf}),  do: "≥ #{lo}"
  defp format_cell({lo, hi}),    do: "#{lo} – #{hi}"
  defp format_cell(:any),        do: "любой"
  defp format_cell(nil),         do: "—"
  defp format_cell(v),           do: to_string(v)

  # ── Template ─────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 p-6">
      <div class="max-w-5xl mx-auto space-y-6">

        <%!-- Header --%>
        <div>
          <a href={~p"/rules"} class="text-sm text-blue-600 hover:underline">← Все таблицы</a>
          <h1 class="text-2xl font-bold text-gray-800 mt-1"><%= @config.title %></h1>
          <p class="text-sm text-gray-500"><%= @config.description %></p>
        </div>

        <%!-- Rules table --%>
        <div class="bg-white rounded-xl border border-gray-200 overflow-x-auto">
          <table class="w-full text-sm">
            <thead class="bg-gray-50 border-b border-gray-200">
              <tr>
                <th class="px-4 py-2 text-left font-medium text-gray-500 w-8">#</th>
                <%= for col <- @config.columns do %>
                  <th class="px-4 py-2 text-left font-medium text-gray-600"><%= col %></th>
                <% end %>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <%= for {spec, idx} <- @rules do %>
                <tr class={if @sim_matched == idx, do: "bg-green-50", else: "hover:bg-gray-50"}>
                  <td class="px-4 py-2 text-gray-400 font-mono text-xs">
                    <%= if @sim_matched == idx do %>
                      <span class="text-green-600 font-bold">→</span>
                    <% else %>
                      <%= idx + 1 %>
                    <% end %>
                  </td>
                  <%= for cell <- spec do %>
                    <td class="px-4 py-2 font-mono text-gray-700"><%= format_cell(cell) %></td>
                  <% end %>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%!-- Simulator --%>
        <div class="bg-white rounded-xl border border-gray-200 p-5">
          <h2 class="font-semibold text-gray-700 mb-4">Симулятор</h2>

          <.form for={%{}} phx-submit="simulate">
            <div class="flex flex-wrap gap-4 items-end">
              <%= for cfg <- @config.inputs do %>
                <div>
                  <label class="block text-xs font-medium text-gray-600 mb-1">
                    <%= cfg.label %>
                  </label>
                  <%= if cfg.type in [:select, :boolean] do %>
                    <select
                      name={"inputs[#{cfg.name}]"}
                      class="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                    >
                      <%= for opt <- cfg.options do %>
                        <option value={opt} selected={Map.get(@inputs, cfg.name) == opt}>
                          <%= opt %>
                        </option>
                      <% end %>
                    </select>
                  <% else %>
                    <input
                      type="number"
                      name={"inputs[#{cfg.name}]"}
                      value={Map.get(@inputs, cfg.name)}
                      step={Map.get(cfg, :step, "1")}
                      min={Map.get(cfg, :min)}
                      max={Map.get(cfg, :max)}
                      class="border border-gray-300 rounded-lg px-3 py-2 text-sm w-36 focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  <% end %>
                </div>
              <% end %>

              <button
                type="submit"
                class="px-5 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                Проверить
              </button>
            </div>
          </.form>

          <%= if @sim_result do %>
            <div class={[
              "mt-4 rounded-lg px-4 py-3 text-sm border",
              case @sim_result do
                {:ok, _}    -> "bg-green-50 border-green-200 text-green-800"
                {:error, _} -> "bg-red-50 border-red-200 text-red-800"
              end
            ]}>
              <%= case @sim_result do %>
                <% {:ok, result} -> %>
                  <span class="font-semibold">Результат:</span>
                  <%= for {key, val} <- result do %>
                    <span class="ml-3 font-mono">
                      <span class="text-gray-500"><%= key %>:</span>
                      <strong><%= format_cell(val) %></strong>
                    </span>
                  <% end %>
                  <%= if @sim_matched do %>
                    <span class="ml-3 text-gray-400">→ строка #<%= @sim_matched + 1 %></span>
                  <% end %>
                <% {:error, msg} -> %>
                  <%= msg %>
              <% end %>
            </div>
          <% end %>
        </div>

      </div>
    </div>
    """
  end
end
