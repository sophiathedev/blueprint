import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "label", "menu", "trigger"]

  connect() {
    this.isOpen = false
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    this.isOpen ? this.close() : this.open()
  }

  open() {
    if (!this.hasMenuTarget) return

    this.isOpen = true
    this.triggerTarget.setAttribute("aria-expanded", "true")
    this.menuTarget.classList.remove("pointer-events-none", "translate-y-1", "opacity-0")
  }

  close() {
    if (!this.hasMenuTarget) return

    this.isOpen = false
    this.triggerTarget.setAttribute("aria-expanded", "false")
    this.menuTarget.classList.add("pointer-events-none", "translate-y-1", "opacity-0")
  }

  closeOnOutside(event) {
    if (this.element.contains(event.target)) return

    this.close()
  }

  choose(event) {
    event.preventDefault()

    const button = event.currentTarget
    const { value, label } = button.dataset

    if (this.hasInputTarget) this.inputTarget.value = value
    if (this.hasLabelTarget) this.labelTarget.textContent = label

    this.element.querySelectorAll("[role='option']").forEach((option) => {
      const active = option === button
      option.setAttribute("aria-selected", active ? "true" : "false")
      option.classList.toggle("bg-primary-50", active)
      option.classList.toggle("font-semibold", active)
      option.classList.toggle("text-primary-800", active)
      option.classList.toggle("text-black", !active)
      option.classList.toggle("hover:bg-stone-100", !active)

      const icon = option.querySelector("[data-select-field-check]")
      if (icon) icon.classList.toggle("invisible", !active)
    })

    this.close()
  }
}
