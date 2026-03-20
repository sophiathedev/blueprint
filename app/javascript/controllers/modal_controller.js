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
    const modalTargets = this.currentModalTargets(this.openValue ? "open" : "close")
    if (!modalTargets) return

    if (this.openValue) {
      this.showModal(modalTargets, skipAnimation)
      this.enableScrollLock()
      document.addEventListener("keydown", this.boundHandleKeydown)
    } else {
      this.hideModal(modalTargets, skipAnimation)
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

  showModal({ overlay, panel }, skipAnimation) {
    this.clearCloseTimeout()
    overlay.classList.remove("hidden", "pointer-events-none")

    if (skipAnimation) {
      this.disableTransitionTemporarily({ overlay, panel })
      this.applyOpenState({ overlay, panel })
      return
    }

    this.applyClosedState({ overlay, panel })
    overlay.getBoundingClientRect()

    requestAnimationFrame(() => {
      this.applyOpenState({ overlay, panel })
    })
  }

  hideModal({ overlay, panel }, skipAnimation) {
    this.clearCloseTimeout()

    if (skipAnimation) {
      this.disableTransitionTemporarily({ overlay, panel })
      this.applyClosedState({ overlay, panel })
      overlay.classList.add("hidden", "pointer-events-none")
      return
    }

    this.applyClosedState({ overlay, panel })
    overlay.classList.add("pointer-events-none")
    this.closeTimeout = window.setTimeout(() => {
      if (this.openValue) return

      overlay.classList.add("hidden")
    }, this.constructor.TRANSITION_DURATION)
  }

  applyOpenState({ overlay, panel }) {
    overlay.classList.remove("opacity-0")
    overlay.classList.add("opacity-100")
    if (!panel) return

    panel.classList.remove("translate-y-4", "scale-[0.97]", "opacity-0")
    panel.classList.add("translate-y-0", "scale-100", "opacity-100")
  }

  applyClosedState({ overlay, panel }) {
    overlay.classList.remove("opacity-100")
    overlay.classList.add("opacity-0")
    if (!panel) return

    panel.classList.remove("translate-y-0", "scale-100", "opacity-100")
    panel.classList.add("translate-y-4", "scale-[0.97]", "opacity-0")
  }

  disableTransitionTemporarily({ overlay, panel }) {
    overlay?.classList.add("transition-none")
    panel?.classList.add("transition-none")

    requestAnimationFrame(() => {
      overlay?.classList.remove("transition-none")
      panel?.classList.remove("transition-none")
    })
  }

  clearCloseTimeout() {
    if (!this.closeTimeout) return

    window.clearTimeout(this.closeTimeout)
    this.closeTimeout = null
  }

  currentModalTargets(mode) {
    if (!this.hasOverlayTarget) return null

    const visibleIndexes = this.overlayTargets
      .map((overlay, index) => ({ overlay, index }))
      .filter(({ overlay }) => !overlay.classList.contains("hidden"))
      .map(({ index }) => index)

    const targetIndex = visibleIndexes.at(-1) ?? 0

    return {
      overlay: this.overlayTargets[targetIndex],
      panel: this.panelTargets[targetIndex]
    }
  }
}
