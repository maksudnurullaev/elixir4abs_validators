import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Хук форматирования номера счёта: вставляет пробел каждые 4 цифры при вводе
const AccountNumberMask = {
  mounted() {
    this.el.addEventListener("input", (e) => {
      const selStart = e.target.selectionStart
      // считаем, сколько цифр стоит до курсора в текущем (ещё не отформатированном) значении
      const digitsBeforeCursor = e.target.value.slice(0, selStart).replace(/\D/g, "").length

      const raw = e.target.value.replace(/\D/g, "").slice(0, 20)
      const formatted = raw.match(/.{1,4}/g)?.join(" ") ?? ""
      e.target.value = formatted

      // находим позицию курсора в отформатированной строке:
      // идём по символам и отсчитываем нужное количество цифр
      let newCursor = formatted.length
      let counted = 0
      for (let i = 0; i < formatted.length; i++) {
        if (counted === digitsBeforeCursor) { newCursor = i; break }
        if (/\d/.test(formatted[i])) counted++
      }
      e.target.setSelectionRange(newCursor, newCursor)
    })
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: { AccountNumberMask }
})

liveSocket.connect()
window.liveSocket = liveSocket
