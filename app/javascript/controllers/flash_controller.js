import { Controller } from "@hotwired/stimulus"
import { application } from "controllers/application"

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 5000 }
  }

  connect() {
    if (this.skipIfDuplicateToastExists()) return

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

  skipIfDuplicateToastExists() {
    const key = this.element.dataset.flashKey
    if (!key) return false

    const existingToast = Array.from(
      document.querySelectorAll(`[data-controller~="flash"][data-flash-key="${CSS.escape(key)}"]`)
    ).find((toast) => toast !== this.element)

    if (!existingToast) return false

    const existingController = application.getControllerForElementAndIdentifier(existingToast, "flash")
    existingController?.restartTimer()
    this.element.remove()
    return true
  }

  restartTimer() {
    this.clearTimeout()
    this.timeoutId = window.setTimeout(() => this.close(), this.delayValue)
  }
}
