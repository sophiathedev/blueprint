import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "panel"]
  static values = { open: { type: Boolean, default: false } }

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    this.sync()
  }

  disconnect() {
    this.disableScrollLock()
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  open() {
    this.openValue = true
    this.focusAutofocusField()
  }

  close() {
    this.openValue = false
  }

  closeOnBackdrop(event) {
    if (this.hasPanelTarget && this.panelTarget.contains(event.target)) return

    this.close()
  }

  openValueChanged() {
    this.sync()
    if (this.openValue) this.focusAutofocusField()
  }

  sync() {
    if (!this.hasOverlayTarget) return

    this.overlayTarget.classList.toggle("pointer-events-none", !this.openValue)
    this.overlayTarget.classList.toggle("opacity-0", !this.openValue)
    this.overlayTarget.classList.toggle("opacity-100", this.openValue)

    if (this.hasPanelTarget) {
      this.panelTarget.classList.toggle("translate-y-4", !this.openValue)
      this.panelTarget.classList.toggle("scale-[0.98]", !this.openValue)
      this.panelTarget.classList.toggle("opacity-0", !this.openValue)
      this.panelTarget.classList.toggle("translate-y-0", this.openValue)
      this.panelTarget.classList.toggle("scale-100", this.openValue)
      this.panelTarget.classList.toggle("opacity-100", this.openValue)
    }

    if (this.openValue) {
      this.enableScrollLock()
      document.addEventListener("keydown", this.boundHandleKeydown)
    } else {
      this.disableScrollLock()
      document.removeEventListener("keydown", this.boundHandleKeydown)
    }
  }

  handleKeydown(event) {
    if (event.key !== "Escape") return

    this.close()
  }

  enableScrollLock() {
    document.body.classList.add("overflow-hidden")
  }

  disableScrollLock() {
    document.body.classList.remove("overflow-hidden")
  }

  focusAutofocusField() {
    window.setTimeout(() => {
      this.element.querySelector("[data-autofocus-modal]")?.focus()
    }, 180)
  }
}
