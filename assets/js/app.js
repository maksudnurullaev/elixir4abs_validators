import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Форматирование номера счёта по структуре CCCCCVVVKSSSSSSSSNNN:
// группы [5, 3, 1, 8, 3] разделяются пробелами → "CCCCC VVV K SSSSSSSS NNN"
const ACCOUNT_GROUPS = [5, 3, 1, 8, 3]

function formatAccount(digits) {
  let result = ""
  let pos = 0
  for (let i = 0; i < ACCOUNT_GROUPS.length; i++) {
    const chunk = digits.slice(pos, pos + ACCOUNT_GROUPS[i])
    if (chunk.length === 0) break
    if (i > 0) result += " "
    result += chunk
    pos += ACCOUNT_GROUPS[i]
  }
  return result
}

const AccountNumberMask = {
  mounted() {
    this.el.addEventListener("input", (e) => {
      const selStart = e.target.selectionStart
      // сколько цифр стоит до курсора до форматирования
      const digitsBeforeCursor = e.target.value.slice(0, selStart).replace(/\D/g, "").length

      const raw = e.target.value.replace(/\D/g, "").slice(0, 20)
      const formatted = formatAccount(raw)
      e.target.value = formatted

      // восстанавливаем позицию курсора: отсчитываем нужное количество цифр
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
