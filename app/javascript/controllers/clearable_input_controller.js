import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "clear"]

  connect() {
    this.sync()
  }

  sync() {
    if (!this.hasInputTarget || !this.hasClearTarget) return

    const hasValue = this.inputTarget.value.length > 0
    this.clearTarget.classList.toggle("hidden", !hasValue)
  }

  clear(event) {
    event.preventDefault()
    if (!this.hasInputTarget) return

    this.inputTarget.value = ""
    this.sync()
    this.inputTarget.focus()
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
