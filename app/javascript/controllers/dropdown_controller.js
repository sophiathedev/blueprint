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
    this.menuTarget.classList.add("pointer-events-none", this.closedTransformClass, "opacity-0")
  }

  closeOnOutside(event) {
    if (this.element.contains(event.target)) return

    this.close()
  }

  get closedTransformClass() {
    return this.directionValue === "right_end" ? "translate-x-1" : "translate-y-1"
  }
}
