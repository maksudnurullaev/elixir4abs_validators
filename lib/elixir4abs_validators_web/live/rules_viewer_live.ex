defmodule Elixir4absValidatorsWeb.RulesViewerLive do
  use Elixir4absValidatorsWeb, :live_view

  alias Elixir4ABS.Rules.Registry

  @impl true
  def mount(%{"ruleset" => key}, _session, socket) do
    case Registry.get(key) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Таблица решений «#{key}» не найдена.")
         |> push_navigate(to: ~p"/")}

      config ->
        n_inputs = length(config.inputs)
        {:ok,
         assign(socket,
           ruleset_key: key,
           config: config,
           rules: load_rules(config.module),
           n_inputs: n_inputs,
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
    |> Enum.with_index()
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

  defp coerce(v, :select),       do: v
  defp coerce("true",  :boolean), do: true
  defp coerce(_,       :boolean), do: false

  defp run_simulation(module, facts, rules, input_configs) do
    if Enum.any?(Map.values(facts), &is_nil/1) do
      {{:error, "Заполните все поля корректно"}, nil}
    else
      result =
        case apply(module, :decide, [facts]) do
          {:error, :no_match} -> {:error, "Ни одно правило не подошло"}
          map                 -> {:ok, map}
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

  defp matches?(_val, :any),      do: true
  defp matches?(val, {lo, :inf}), do: val >= lo
  defp matches?(val, {lo, hi}),   do: val >= lo and val <= hi
  defp matches?(val, expected),   do: val == expected

  defp format_cell({lo, :inf}), do: "≥ #{lo}"
  defp format_cell({lo, hi}),   do: "#{lo} – #{hi}"
  defp format_cell(:any),       do: "любой"
  defp format_cell(nil),        do: "—"
  defp format_cell(v),          do: to_string(v)

  # ── Template ─────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 p-6">
      <div class="w-full space-y-6">

        <%!-- Header --%>
        <div>
          <a href={~p"/rules"} class="text-sm text-blue-600 hover:underline">← Все таблицы</a>
          <h1 class="text-2xl font-bold text-gray-800 mt-1"><%= @config.title %></h1>
          <p class="text-sm text-gray-500"><%= @config.description %></p>
        </div>

        <%!-- Legend --%>
        <div class="flex gap-4 text-xs text-gray-500">
          <span class="flex items-center gap-1.5">
            <span class="inline-block w-3 h-3 rounded-sm bg-blue-100 border border-blue-300"></span>
            Условия (входные параметры)
          </span>
          <span class="flex items-center gap-1.5">
            <span class="inline-block w-3 h-3 rounded-sm bg-amber-100 border border-amber-300"></span>
            Действия (выходные значения)
          </span>
          <span class="flex items-center gap-1.5">
            <span class="font-bold text-green-600 text-sm">✓</span>
            действие активно
          </span>
          <span class="flex items-center gap-1.5">
            <span class="text-gray-300 text-sm font-bold">—</span>
            действие неактивно
          </span>
        </div>

        <%!-- Rules table --%>
        <div class="bg-white rounded-xl border border-gray-200 overflow-x-auto shadow-sm">
          <table class="w-full text-sm border-collapse">

            <%!-- Group header: Условия / Действия --%>
            <thead>
              <tr>
                <th class="w-8 bg-gray-50 border-b border-gray-200"></th>
                <th
                  colspan={@n_inputs}
                  class="py-1.5 text-center text-xs font-bold uppercase tracking-wider bg-blue-50 text-blue-600 border-b border-blue-200"
                >
                  Условия
                </th>
                <th
                  colspan={length(@config.columns) - @n_inputs}
                  class="py-1.5 text-center text-xs font-bold uppercase tracking-wider bg-amber-50 text-amber-600 border-l-2 border-amber-300 border-b border-amber-200"
                >
                  Действия
                </th>
              </tr>

              <%!-- Column headers --%>
              <tr>
                <th class="px-3 py-2 text-left text-xs font-medium text-gray-400 bg-gray-50 border-b border-gray-200 w-8">
                  #
                </th>
                <%= for {col, i} <- Enum.with_index(@config.columns) do %>
                  <th class={[
                    "px-3 py-2 text-left text-xs font-semibold border-b whitespace-nowrap",
                    if i < @n_inputs do
                      "bg-blue-50 text-blue-700 border-blue-200"
                    else
                      ["bg-amber-50 text-amber-700 border-amber-200",
                       if(i == @n_inputs, do: "border-l-2 border-l-amber-300")]
                    end
                  ]}>
                    <%= col %>
                  </th>
                <% end %>
              </tr>
            </thead>

            <%!-- Rules body --%>
            <tbody class="divide-y divide-gray-100">
              <%= for {spec, idx} <- @rules do %>
                <% matched = @sim_matched == idx %>
                <tr class={if matched, do: "bg-green-50", else: "hover:bg-gray-50/60 transition-colors"}>

                  <%!-- Row number / match indicator --%>
                  <td class="px-3 py-2.5 text-center border-r border-gray-100">
                    <%= if matched do %>
                      <span class="inline-flex items-center justify-center w-5 h-5 rounded-full bg-green-500 text-white text-xs font-bold">→</span>
                    <% else %>
                      <span class="text-gray-400 text-xs font-mono"><%= idx + 1 %></span>
                    <% end %>
                  </td>

                  <%!-- Condition and action cells --%>
                  <%= for {cell, i} <- Enum.with_index(spec) do %>
                    <% is_action = i >= @n_inputs %>
                    <% is_separator = i == @n_inputs %>
                    <td class={[
                      "px-3 py-2.5",
                      if(is_separator, do: "border-l-2 border-amber-200"),
                      if(matched, do: "", else: if(is_action, do: "bg-amber-50/30", else: "bg-blue-50/20"))
                    ]}>
                      <%= cond do %>
                        <% is_action and is_boolean(cell) -> %>
                          <%= if cell do %>
                            <span class="inline-flex items-center justify-center w-6 h-6 rounded-full bg-green-100 text-green-700 font-bold text-xs select-none">✓</span>
                          <% else %>
                            <span class="text-gray-300 text-lg leading-none select-none font-bold">—</span>
                          <% end %>
                        <% not is_action and is_boolean(cell) -> %>
                          <span class={"font-mono text-xs font-semibold #{if cell, do: "text-blue-700", else: "text-gray-500"}"}>
                            <%= if cell, do: "да", else: "нет" %>
                          </span>
                        <% cell == :any -> %>
                          <span class="text-gray-400 text-xs italic">любой</span>
                        <% true -> %>
                          <span class={"font-mono text-xs #{if is_action, do: "text-gray-700 font-medium", else: "text-blue-900"}"}>
                            <%= format_cell(cell) %>
                          </span>
                      <% end %>
                    </td>
                  <% end %>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%!-- Simulator --%>
        <div class="bg-white rounded-xl border border-gray-200 p-5 shadow-sm">
          <div class="flex items-center gap-2 mb-4">
            <h2 class="font-semibold text-gray-700">Симулятор</h2>
            <span class="text-xs text-gray-400">— введите значения и нажмите «Проверить»</span>
          </div>

          <.form for={%{}} phx-submit="simulate">
            <div class="flex flex-wrap gap-4 items-end">
              <%= for cfg <- @config.inputs do %>
                <div>
                  <label class="block text-xs font-semibold text-blue-700 mb-1">
                    <%= cfg.label %>
                  </label>
                  <%= if cfg.type in [:select, :boolean] do %>
                    <select
                      name={"inputs[#{cfg.name}]"}
                      class="border border-blue-200 bg-blue-50 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
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
                      class="border border-blue-200 bg-blue-50 rounded-lg px-3 py-2 text-sm w-36 focus:outline-none focus:ring-2 focus:ring-blue-400"
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
              "mt-4 rounded-lg border",
              case @sim_result do
                {:ok, _}    -> "bg-green-50 border-green-200"
                {:error, _} -> "bg-red-50 border-red-200 text-red-700 px-4 py-3 text-sm"
              end
            ]}>
              <%= case @sim_result do %>
                <% {:ok, result} -> %>
                  <div class="px-4 py-2 border-b border-green-200 text-xs font-semibold text-green-700 uppercase tracking-wider flex items-center gap-2">
                    Действия
                    <%= if @sim_matched do %>
                      <span class="ml-auto text-xs text-gray-400 normal-case font-normal">→ правило #<%= @sim_matched + 1 %></span>
                    <% end %>
                  </div>
                  <div class="px-4 py-3 flex flex-wrap gap-3">
                    <%= for {key, val} <- result do %>
                      <span class={[
                        "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium border",
                        if is_boolean(val) do
                          if val,
                            do: "bg-green-100 text-green-800 border-green-200",
                            else: "bg-gray-100 text-gray-400 border-gray-200"
                        else
                          "bg-amber-100 text-amber-800 border-amber-200"
                        end
                      ]}>
                        <%= if is_boolean(val) do %>
                          <span class={if val, do: "font-bold", else: ""}><%= if val, do: "✓", else: "—" %></span>
                        <% end %>
                        <%= key %>
                        <%= if not is_boolean(val) do %>
                          <strong class="ml-0.5"><%= format_cell(val) %></strong>
                        <% end %>
                      </span>
                    <% end %>
                  </div>
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
