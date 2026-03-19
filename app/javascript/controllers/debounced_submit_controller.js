import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 300 }
  }

  connect() {
    this.submitTimeout = null
  }

  disconnect() {
    this.clearTimeout()
  }

  submit() {
    this.clearTimeout()
    this.submitTimeout = window.setTimeout(() => {
      this.element.requestSubmit()
    }, this.delayValue)
  }

  clearTimeout() {
    if (!this.submitTimeout) return

    window.clearTimeout(this.submitTimeout)
    this.submitTimeout = null
  }
}
