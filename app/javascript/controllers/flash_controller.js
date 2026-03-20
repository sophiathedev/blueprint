import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 5000 }
  }

  connect() {
    this.removeDuplicateToasts()

    requestAnimationFrame(() => {
      this.element.classList.remove("translate-x-4", "opacity-0")
    })

    this.timeoutId = window.setTimeout(() => this.close(), this.delayValue)
  }

  disconnect() {
    this.clearTimeout()
  }

  close() {
    this.clearTimeout()
    this.element.classList.add("pointer-events-none", "translate-x-4", "opacity-0")

    window.setTimeout(() => {
      this.element.remove()
    }, 220)
  }

  clearTimeout() {
    if (!this.timeoutId) return

    window.clearTimeout(this.timeoutId)
    this.timeoutId = null
  }

  removeDuplicateToasts() {
    const key = this.element.dataset.flashKey
    if (!key) return

    document.querySelectorAll(`[data-controller~="flash"][data-flash-key="${CSS.escape(key)}"]`).forEach((toast) => {
      if (toast === this.element) return

      toast.remove()
    })
  }
}
