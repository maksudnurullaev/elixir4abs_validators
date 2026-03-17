defmodule Elixir4absValidatorsWeb.SwiftPacs008Live do
  use Elixir4absValidatorsWeb, :live_view

  alias Elixir4ABS.Swift.Parser.Pacs008

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, xml: "", result: nil, error: nil)}
  end

  @impl true
  def handle_event("parse", %{"xml" => xml}, socket) do
    xml = String.trim(xml)

    case Pacs008.parse(xml) do
      {:ok, pacs} ->
        {:noreply, assign(socket, xml: xml, result: pacs, error: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, xml: xml, result: nil, error: format_error(reason))}
    end
  end

  @impl true
  def handle_event("clear", _params, socket) do
    {:noreply, assign(socket, xml: "", result: nil, error: nil)}
  end

  @impl true
  def handle_event("load_example", _params, socket) do
    {:noreply, assign(socket, xml: example_xml(), result: nil, error: nil)}
  end

  # --- helpers ---

  defp format_error(:invalid_xml),           do: "Невалидный XML — не удалось разобрать документ"
  defp format_error(:unsupported_namespace), do: "Неверный namespace — поддерживается только pacs.008.001.08"
  defp format_error({:missing_field, f}),    do: "Отсутствует обязательное поле: #{f}"
  defp format_error({:invalid_amount, v}),   do: "Неверный формат суммы: «#{v}»"
  defp format_error({:invalid_date, v}),     do: "Неверный формат даты: «#{v}»"
  defp format_error({:nb_of_txs_mismatch, exp, act}),
    do: "NbOfTxs расходится: в заголовке #{exp}, фактически транзакций #{act}"
  defp format_error(other), do: inspect(other)

  defp example_xml do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Document xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08">
      <FIToFICstmrCdtTrf>
        <GrpHdr>
          <MsgId>MSG-20260317-001</MsgId>
          <CreDtTm>2026-03-17T10:00:00Z</CreDtTm>
          <NbOfTxs>1</NbOfTxs>
          <CtrlSum>1000.00</CtrlSum>
          <IntrBkSttlmDt>2026-03-17</IntrBkSttlmDt>
        </GrpHdr>
        <CdtTrfTxInf>
          <PmtId>
            <EndToEndId>E2E-20260317-001</EndToEndId>
          </PmtId>
          <IntrBkSttlmAmt Ccy="RUB">1000.00</IntrBkSttlmAmt>
          <Dbtr><Nm>ООО Ромашка</Nm></Dbtr>
          <DbtrAcct><Id><IBAN>RU0204452560040702810412345678901</IBAN></Id></DbtrAcct>
          <DbtrAgt><FinInstnId><BICFI>SABRRUMM</BICFI></FinInstnId></DbtrAgt>
          <Cdtr><Nm>ИП Петров</Nm></Cdtr>
          <CdtrAcct><Id><IBAN>RU0204452560040702810498765432100</IBAN></Id></CdtrAcct>
          <CdtrAgt><FinInstnId><BICFI>VTBRRUMM</BICFI></FinInstnId></CdtrAgt>
          <RmtInf><Ustrd>Оплата по договору №123 от 01.03.2026</Ustrd></RmtInf>
        </CdtTrfTxInf>
      </FIToFICstmrCdtTrf>
    </Document>
    """ |> String.trim()
  end

  # --- template ---

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 p-4">
      <div class="max-w-3xl mx-auto">

        <a href={~p"/"} class="inline-block text-sm text-blue-600 hover:underline mb-4">← На главную</a>

        <div class="bg-white rounded-2xl shadow-md p-8">

          <h1 class="text-2xl font-bold text-gray-800 mb-1">SWIFT ISO 20022 — pacs.008</h1>
          <p class="text-sm text-gray-500 mb-6">
            Парсинг и валидация FI-to-FI Customer Credit Transfer (pacs.008.001.08)
          </p>

          <%!-- Input form --%>
          <form phx-submit="parse" class="space-y-3">
            <div>
              <div class="flex items-center justify-between mb-1">
                <label class="text-xs font-medium text-gray-600">XML сообщение</label>
                <button
                  type="button" phx-click="load_example"
                  class="text-xs text-blue-500 hover:underline"
                >загрузить пример</button>
              </div>
              <textarea
                name="xml"
                rows="12"
                value={@xml}
                placeholder="<?xml version=&quot;1.0&quot;?> <Document xmlns=&quot;urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08&quot;>…"
                class="w-full border border-gray-300 rounded-lg px-3 py-2 font-mono text-xs focus:outline-none focus:ring-2 focus:ring-blue-500 resize-y"
              ><%= @xml %></textarea>
            </div>

            <div class="flex gap-2">
              <button
                type="submit"
                class="flex-1 bg-blue-600 text-white font-semibold rounded-lg py-2 hover:bg-blue-700 transition"
              >
                Разобрать
              </button>
              <button
                type="button" phx-click="clear"
                class="px-4 border border-gray-300 rounded-lg text-sm text-gray-600 hover:bg-gray-50 transition"
              >
                Очистить
              </button>
            </div>
          </form>

          <%!-- Error banner --%>
          <%= if @error do %>
            <div class="mt-4 flex items-start gap-3 bg-red-50 border border-red-200 rounded-xl px-4 py-3">
              <span class="text-red-500 text-lg leading-none mt-0.5">✗</span>
              <p class="text-sm text-red-700"><%= @error %></p>
            </div>
          <% end %>

          <%!-- Success result --%>
          <%= if @result do %>
            <div class="mt-5 space-y-4">

              <%!-- Success banner --%>
              <div class="flex items-center gap-2 bg-green-50 border border-green-200 rounded-xl px-4 py-3">
                <span class="text-green-600 text-lg">✓</span>
                <span class="text-sm font-medium text-green-700">Сообщение разобрано успешно</span>
              </div>

              <%!-- Header fields --%>
              <div class="border border-gray-200 rounded-xl overflow-hidden">
                <div class="bg-gray-50 px-4 py-2 text-xs font-semibold text-gray-500 uppercase tracking-wide border-b border-gray-200">
                  Заголовок (GrpHdr)
                </div>
                <dl class="divide-y divide-gray-100 text-sm">
                  <div class="grid grid-cols-2 px-4 py-2.5">
                    <dt class="text-gray-500">MsgId</dt>
                    <dd class="font-mono text-gray-800"><%= @result.msg_id %></dd>
                  </div>
                  <div class="grid grid-cols-2 px-4 py-2.5">
                    <dt class="text-gray-500">CreDtTm</dt>
                    <dd class="font-mono text-gray-800"><%= DateTime.to_string(@result.creation_dt) %></dd>
                  </div>
                  <div class="grid grid-cols-2 px-4 py-2.5">
                    <dt class="text-gray-500">NbOfTxs</dt>
                    <dd class="font-mono text-gray-800"><%= @result.nb_of_txs %></dd>
                  </div>
                  <div class="grid grid-cols-2 px-4 py-2.5">
                    <dt class="text-gray-500">CtrlSum</dt>
                    <dd class="font-mono text-gray-800"><%= Decimal.to_string(@result.ctrl_sum) %></dd>
                  </div>
                  <div class="grid grid-cols-2 px-4 py-2.5">
                    <dt class="text-gray-500">IntrBkSttlmDt</dt>
                    <dd class="font-mono text-gray-800"><%= Date.to_string(@result.sttlm_dt) %></dd>
                  </div>
                </dl>
              </div>

              <%!-- Transactions --%>
              <%= for {txn, idx} <- Enum.with_index(@result.transactions, 1) do %>
                <div class="border border-gray-200 rounded-xl overflow-hidden">
                  <div class="bg-gray-50 px-4 py-2 text-xs font-semibold text-gray-500 uppercase tracking-wide border-b border-gray-200">
                    Транзакция <%= idx %> — <span class="font-mono normal-case"><%= txn.end_to_end_id %></span>
                  </div>
                  <dl class="divide-y divide-gray-100 text-sm">
                    <div class="grid grid-cols-2 px-4 py-2.5">
                      <dt class="text-gray-500">Сумма / Валюта</dt>
                      <dd class="font-mono text-gray-800">
                        <%= Decimal.to_string(txn.amount) %>
                        <span class="ml-1 text-xs bg-gray-100 px-1.5 py-0.5 rounded text-gray-600"><%= txn.currency %></span>
                      </dd>
                    </div>
                    <div class="grid grid-cols-2 px-4 py-2.5">
                      <dt class="text-gray-500">Дебитор</dt>
                      <dd class="text-gray-800">
                        <%= txn.debtor_name || "—" %>
                        <div class="font-mono text-xs text-gray-500 mt-0.5">
                          IBAN: <%= txn.debtor_iban %> · BIC: <%= txn.debtor_bic %>
                        </div>
                      </dd>
                    </div>
                    <div class="grid grid-cols-2 px-4 py-2.5">
                      <dt class="text-gray-500">Кредитор</dt>
                      <dd class="text-gray-800">
                        <%= txn.creditor_name || "—" %>
                        <div class="font-mono text-xs text-gray-500 mt-0.5">
                          IBAN: <%= txn.creditor_iban %> · BIC: <%= txn.creditor_bic %>
                        </div>
                      </dd>
                    </div>
                    <%= if txn.remittance_info do %>
                      <div class="grid grid-cols-2 px-4 py-2.5">
                        <dt class="text-gray-500">Назначение</dt>
                        <dd class="text-gray-800"><%= txn.remittance_info %></dd>
                      </div>
                    <% end %>
                  </dl>
                </div>
              <% end %>

            </div>
          <% end %>

        </div>
      </div>
    </div>
    """
  end
end
