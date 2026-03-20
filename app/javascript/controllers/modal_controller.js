import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static TRANSITION_DURATION = 300
  static targets = ["overlay", "panel"]
  static values = { open: { type: Boolean, default: false } }

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    this.closeTimeout = null
    this.sync({ skipAnimation: true })
  }

  disconnect() {
    this.clearCloseTimeout()
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

  sync({ skipAnimation = false } = {}) {
    if (!this.hasOverlayTarget) return

    if (this.openValue) {
      this.showModal(skipAnimation)
      this.enableScrollLock()
      document.addEventListener("keydown", this.boundHandleKeydown)
    } else {
      this.hideModal(skipAnimation)
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

  showModal(skipAnimation) {
    this.clearCloseTimeout()
    this.overlayTarget.classList.remove("hidden", "pointer-events-none")

    if (skipAnimation) {
      this.disableTransitionTemporarily()
      this.applyOpenState()
      return
    }

    this.applyClosedState()
    this.overlayTarget.getBoundingClientRect()

    requestAnimationFrame(() => {
      this.applyOpenState()
    })
  }

  hideModal(skipAnimation) {
    this.clearCloseTimeout()

    if (skipAnimation) {
      this.disableTransitionTemporarily()
      this.applyClosedState()
      this.overlayTarget.classList.add("hidden", "pointer-events-none")
      return
    }

    this.applyClosedState()
    this.overlayTarget.classList.add("pointer-events-none")
    this.closeTimeout = window.setTimeout(() => {
      if (this.openValue) return

      this.overlayTarget.classList.add("hidden")
    }, this.constructor.TRANSITION_DURATION)
  }

  applyOpenState() {
    this.overlayTarget.classList.remove("opacity-0")
    this.overlayTarget.classList.add("opacity-100")

    if (!this.hasPanelTarget) return

    this.panelTarget.classList.remove("translate-y-4", "scale-[0.97]", "opacity-0")
    this.panelTarget.classList.add("translate-y-0", "scale-100", "opacity-100")
  }

  applyClosedState() {
    this.overlayTarget.classList.remove("opacity-100")
    this.overlayTarget.classList.add("opacity-0")

    if (!this.hasPanelTarget) return

    this.panelTarget.classList.remove("translate-y-0", "scale-100", "opacity-100")
    this.panelTarget.classList.add("translate-y-4", "scale-[0.97]", "opacity-0")
  }

  disableTransitionTemporarily() {
    this.overlayTarget?.classList.add("transition-none")
    this.panelTarget?.classList.add("transition-none")

    requestAnimationFrame(() => {
      this.overlayTarget?.classList.remove("transition-none")
      this.panelTarget?.classList.remove("transition-none")
    })
  }

  clearCloseTimeout() {
    if (!this.closeTimeout) return

    window.clearTimeout(this.closeTimeout)
    this.closeTimeout = null
  }
}
