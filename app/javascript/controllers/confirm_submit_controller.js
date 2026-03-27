import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "text", "defaultIcon", "confirmIcon"]
  static values = {
    defaultLabel: String,
    confirmLabel: String
  }

  connect() {
    this.confirmed = false
  }

  submit(event) {
    event.preventDefault()

    if (this.confirmed) {
      this.element.requestSubmit()
      return
    }

    this.confirmed = true
    this.render()
  }

  reset() {
    if (!this.confirmed) return

    this.confirmed = false
    this.render()
  }

  closeOnOutside(event) {
    if (this.element.contains(event.target)) return

    this.reset()
  }

  render() {
    if (!(this.hasTextTarget && this.hasButtonTarget)) return

    this.textTarget.textContent = this.confirmed ? this.confirmLabelValue : this.defaultLabelValue
    this.buttonTarget.classList.toggle("bg-rose-50", this.confirmed)
    this.buttonTarget.classList.toggle("border-rose-300", this.confirmed)

    if (!(this.hasDefaultIconTarget && this.hasConfirmIconTarget)) return

    this.defaultIconTarget.classList.toggle("hidden", this.confirmed)
    this.confirmIconTarget.classList.toggle("hidden", !this.confirmed)
  }
}
