defmodule Elixir4ABS.DecisionTable do
  @moduledoc """
  Макрос для объявления таблиц решений (Decision Tables).

  Правила компилируются в функциональные клаузы BEAM с pattern matching —
  нулевой оверхед в рантайме (~0.05 µs на вызов).
  Атрибут `__dt_rules_meta__` сохраняет метаданные каждого правила
  для LiveView-просмотрщика (RulesViewerLive).

  ## Пример использования

      defmodule MyApp.Rules.CreditScoring do
        use Elixir4ABS.DecisionTable

        decision_table :decide,
          inputs:  [:ddn_ratio, :credit_score],
          outputs: [:decision, :rate] do
          #           ddn_ratio     credit_score   decision   rate
          rule       [{0.0, 0.5},   {700, :inf},   :approve,  18.5]
          rule       [{0.0, 0.5},   {600, 699},    :approve,  22.0]
          rule       [{0.7, :inf},  :any,          :reject,   nil ]
        end
      end

      MyApp.Rules.CreditScoring.decide(%{ddn_ratio: 0.3, credit_score: 750})
      #=> %{decision: :approve, rate: 18.5}
  """

  defmacro __using__(_opts) do
    quote do
      import Elixir4ABS.DecisionTable, only: [decision_table: 3, rule: 1]
      Module.register_attribute(__MODULE__, :__dt_rules__,      accumulate: true)
      Module.register_attribute(__MODULE__, :__dt_rules_meta__, accumulate: true)
      @before_compile Elixir4ABS.DecisionTable
    end
  end

  @doc """
  Объявляет таблицу решений с именем функции `name`.

  Опции:
  - `inputs`  — список атомов входных полей (условия)
  - `outputs` — список атомов выходных полей (действия)
  """
  defmacro decision_table(name, opts, do: block) do
    inputs  = Keyword.fetch!(opts, :inputs)
    outputs = Keyword.fetch!(opts, :outputs)

    quote do
      Module.put_attribute(__MODULE__, :__dt_name__,    unquote(name))
      Module.put_attribute(__MODULE__, :__dt_inputs__,  unquote(inputs))
      Module.put_attribute(__MODULE__, :__dt_outputs__, unquote(outputs))
      unquote(block)
    end
  end

  @doc """
  Объявляет одно правило как список: сначала значения условий, затем действий.

  Поддерживаемые форматы условий:
  - `{lo, hi}`   — диапазон (включительно); `:inf` означает «без верхней границы»
  - `:any`       — любое значение (условие пропускается)
  - scalar value — точное совпадение (`==`)
  """
  defmacro rule(spec) when is_list(spec) do
    quote do
      @__dt_rules__      unquote(spec)
      @__dt_rules_meta__ unquote(spec)
    end
  end

  # Генерируем функциональные клаузы после того как собраны все правила.
  @doc false
  defmacro __before_compile__(env) do
    rules   = env.module |> Module.get_attribute(:__dt_rules__) |> Enum.reverse()
    name    = Module.get_attribute(env.module, :__dt_name__)
    inputs  = Module.get_attribute(env.module, :__dt_inputs__)
    outputs = Module.get_attribute(env.module, :__dt_outputs__)

    clauses = Enum.map(rules, &build_clause(name, inputs, outputs, &1))
    escaped = Macro.escape(rules)

    quote do
      unquote_splicing(clauses)

      @doc false
      def __dt_rules_meta__, do: unquote(escaped)
    end
  end

  # ── AST-генерация клаузы ────────────────────────────────────────────────────

  defp build_clause(fn_name, inputs, outputs, rule) do
    n = length(inputs)
    {cond_vals, action_vals} = Enum.split(rule, n)

    field_conds = Enum.zip(inputs, cond_vals)

    # Для :any используем анонимную переменную _ (нет предупреждения об unused)
    pattern_pairs =
      Enum.map(field_conds, fn {field, cond} ->
        var = if cond == :any, do: {:_, [], nil}, else: Macro.var(field, nil)
        {field, var}
      end)

    pattern = {:%{}, [], pattern_pairs}

    guards =
      field_conds
      |> Enum.reject(fn {_, cond} -> cond == :any end)
      |> Enum.flat_map(fn {field, cond} ->
        build_condition_guard(Macro.var(field, nil), cond)
      end)

    result = {:%{}, [], Enum.zip(outputs, action_vals)}

    if guards == [] do
      quote do
        def unquote(fn_name)(unquote(pattern)), do: unquote(result)
      end
    else
      guard = Enum.reduce(guards, fn g, acc -> quote(do: unquote(acc) and unquote(g)) end)

      quote do
        def unquote(fn_name)(unquote(pattern)) when unquote(guard), do: unquote(result)
      end
    end
  end

  defp build_condition_guard(var, {lo, :inf}),
    do: [quote(do: unquote(var) >= unquote(lo))]

  defp build_condition_guard(var, {lo, hi}),
    do: [quote(do: unquote(var) >= unquote(lo) and unquote(var) <= unquote(hi))]

  defp build_condition_guard(var, val),
    do: [quote(do: unquote(var) == unquote(val))]
end
