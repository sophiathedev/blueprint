import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
  static values = ["direction"]

  connect() {
    this.isOpen = false
  }

  toggle(event) {
    event.stopPropagation()
    this.isOpen ? this.close() : this.open()
  }

  open() {
    if (!this.hasMenuTarget) return

    this.isOpen = true
    this.menuTarget.classList.remove("pointer-events-none", "translate-y-1", "translate-x-1", "opacity-0")
  }

  close() {
    if (!this.hasMenuTarget || !this.isOpen) return

    this.isOpen = false
    this.resetConfirmButtons()
    this.menuTarget.classList.add("pointer-events-none", this.closedTransformClass, "opacity-0")
  }

  closeOnOutside(event) {
    if (this.element.contains(event.target)) return

    this.close()
  }

  confirmAction(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const label = button.querySelector("[data-dropdown-confirm-text]")
    const icon = button.querySelector("[data-dropdown-confirm-icon]")
    if (!label) return

    if (button.dataset.confirmed === "true") {
      button.form?.requestSubmit()
      return
    }

    this.resetConfirmButtons()
    button.dataset.confirmed = "true"
    label.textContent = button.dataset.confirmLabel
    if (icon) {
      icon.querySelector("[data-dropdown-icon-default]")?.classList.add("hidden")
      icon.querySelector("[data-dropdown-icon-confirm]")?.classList.remove("hidden")
    }
    button.classList.add("bg-rose-50")
  }

  get closedTransformClass() {
    return this.directionValue === "right_end" ? "translate-x-1" : "translate-y-1"
  }

  resetConfirmButtons() {
    this.element.querySelectorAll("[data-confirmed='true']").forEach((button) => {
      const label = button.querySelector("[data-dropdown-confirm-text]")
      const icon = button.querySelector("[data-dropdown-confirm-icon]")
      if (label) label.textContent = button.dataset.defaultLabel
      if (icon) {
        icon.querySelector("[data-dropdown-icon-default]")?.classList.remove("hidden")
        icon.querySelector("[data-dropdown-icon-confirm]")?.classList.add("hidden")
      }

      button.dataset.confirmed = "false"
      button.classList.remove("bg-rose-50")
    })
  }
}
