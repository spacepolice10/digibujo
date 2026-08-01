import { Controller } from "@hotwired/stimulus"

const GREETINGS = [
  "Hello",
  "Привет",
  "Hola",
  "Bonjour",
  "Ciao",
  "Hallo",
  "Olá",
  "Hej",
  "Hei",
  "Cześć",
  "Ahoj",
  "Merhaba",
  "Γεια",
  "שלום",
  "مرحبا",
  "नमस्ते",
  "你好",
  "こんにちは",
  "안녕하세요",
  "Xin chào"
]

// Cycles "hello" across languages with a light fade on the auth welcome heading.
export default class extends Controller {
  static targets = ["word"]
  static values = {
    interval: { type: Number, default: 2600 }
  }

  connect() {
    this.index = 0
    this.wordTarget.textContent = GREETINGS[0]

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.timer = window.setInterval(() => this.#advance(), this.intervalValue)
  }

  disconnect() {
    window.clearInterval(this.timer)
    window.clearTimeout(this.swapTimer)
  }

  #advance() {
    const el = this.wordTarget
    el.classList.remove("session--hello-in")
    el.classList.add("session--hello-out")

    window.clearTimeout(this.swapTimer)
    this.swapTimer = window.setTimeout(() => {
      this.index = (this.index + 1) % GREETINGS.length
      el.textContent = GREETINGS[this.index]
      el.classList.remove("session--hello-out")
      el.classList.add("session--hello-in")
    }, 220)
  }
}
