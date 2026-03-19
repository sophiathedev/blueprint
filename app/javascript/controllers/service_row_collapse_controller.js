import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "frame", "icon", "trigger"]
  static values = {
    last: { type: Boolean, default: false },
    loaded: { type: Boolean, default: false },
    open: { type: Boolean, default: false },
    src: String
  }

  connect() {
    this.sync()
  }

  lastValueChanged() {
    this.sync()
  }

  toggle(event) {
    if (this.shouldIgnoreClick(event)) return

    this.openValue = !this.openValue
    if (this.openValue) this.loadFrame()
    this.sync()
  }

  toggleWithKeyboard(event) {
    if (event.key !== "Enter" && event.key !== " ") return

    event.preventDefault()
    this.toggle(event)
  }

  loadFrame() {
    if (this.loadedValue || !this.hasFrameTarget || !this.hasSrcValue) return

    this.frameTarget.src = this.srcValue
    this.loadedValue = true
  }

  sync() {
    if (this.hasContentTarget) {
      this.contentTarget.classList.toggle("hidden", !this.openValue)
    }

    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("rotate-90", this.openValue)
    }

    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", String(this.openValue))
      this.triggerTarget.classList.toggle("rounded-b-[24px]", this.lastValue && !this.openValue)
    }

    if (this.hasContentTarget) {
      this.contentTarget.classList.toggle("rounded-b-[24px]", this.lastValue && this.openValue)
    }
  }

  shouldIgnoreClick(event) {
    const interactiveSelector = [
      "a",
      "button",
      "input",
      "select",
      "textarea",
      "label",
      "form",
      "[contenteditable='true']"
    ].join(", ")

    return Boolean(event.target.closest(interactiveSelector))
  }
}
