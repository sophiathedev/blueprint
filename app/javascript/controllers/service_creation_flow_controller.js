import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { promptOpen: Boolean, serviceId: String, clearParams: Array }
  static targets = ["promptOverlay", "promptPanel", "taskOverlay", "taskPanel"]
  static TRANSITION_DURATION = 300

  connect() {
    this.showTimeout = null
    this.hideTimeout = null
    this.boundBeforeCache = this.beforeCache.bind(this)
    this.clearModalParamsFromUrl()
    document.addEventListener("turbo:before-cache", this.boundBeforeCache)

    if (this.promptOpenValue && this.hasPromptOverlayTarget && this.hasPromptPanelTarget) {
      if (!this.promptAlreadyAnimated()) {
        this.markPromptAnimated()
        this.showModal(this.promptOverlayTarget, this.promptPanelTarget)
      } else {
        this.promptOverlayTarget.classList.remove("hidden", "pointer-events-none", "opacity-0")
        this.promptOverlayTarget.classList.add("flex", "opacity-100")
        this.promptPanelTarget.classList.remove("translate-y-4", "scale-[0.97]", "opacity-0")
        this.promptPanelTarget.classList.add("translate-y-0", "scale-100", "opacity-100")
        this.enableScrollLock()
      }
    } else {
      this.syncScrollLock()
    }
  }

  disconnect() {
    this.clearTimers()
    this.disableScrollLock()
    document.removeEventListener("turbo:before-cache", this.boundBeforeCache)
  }

  openTaskModal(event) {
    event.preventDefault()
    this.hideModal(this.promptOverlayTarget, this.promptPanelTarget)
    this.showTimeout = window.setTimeout(() => {
      this.showModal(this.taskOverlayTarget, this.taskPanelTarget)
    }, 180)
  }

  closePrompt(event) {
    event?.preventDefault()
    if (!this.hasPromptOverlayTarget || this.promptOverlayTarget.classList.contains("hidden")) return

    this.hideModal(this.promptOverlayTarget, this.promptPanelTarget)
  }

  closeTask(event) {
    event?.preventDefault()
    if (!this.hasTaskOverlayTarget || this.taskOverlayTarget.classList.contains("hidden")) return

    this.hideModal(this.taskOverlayTarget, this.taskPanelTarget)
  }

  closePromptOnBackdrop(event) {
    if (this.promptPanelTarget.contains(event.target)) return
    this.closePrompt(event)
  }

  closeTaskOnBackdrop(event) {
    if (this.taskPanelTarget.contains(event.target)) return
    this.closeTask(event)
  }

  showModal(overlay, panel) {
    this.clearTimers()
    overlay.classList.remove("hidden", "pointer-events-none")
    overlay.classList.add("flex")
    this.applyClosedState(overlay, panel)
    overlay.getBoundingClientRect()

    requestAnimationFrame(() => {
      overlay.classList.remove("opacity-0")
      overlay.classList.add("opacity-100")
      panel.classList.remove("translate-y-4", "scale-[0.97]", "opacity-0")
      panel.classList.add("translate-y-0", "scale-100", "opacity-100")
      this.enableScrollLock()
      panel.querySelector("[data-autofocus-modal]")?.focus()
    })
  }

  hideModal(overlay, panel) {
    this.clearTimers()
    this.applyClosedState(overlay, panel)
    overlay.classList.add("pointer-events-none")

    this.hideTimeout = window.setTimeout(() => {
      overlay.classList.add("hidden")
      overlay.classList.remove("flex")
      this.syncScrollLock()
    }, this.constructor.TRANSITION_DURATION)
  }

  applyClosedState(overlay, panel) {
    overlay.classList.remove("opacity-100")
    overlay.classList.add("opacity-0")
    panel.classList.remove("translate-y-0", "scale-100", "opacity-100")
    panel.classList.add("translate-y-4", "scale-[0.97]", "opacity-0")
  }

  syncScrollLock() {
    const overlays = []
    if (this.hasPromptOverlayTarget) overlays.push(this.promptOverlayTarget)
    if (this.hasTaskOverlayTarget) overlays.push(this.taskOverlayTarget)

    const hasVisibleOverlay = overlays
      .some((overlay) => !overlay.classList.contains("hidden"))

    if (hasVisibleOverlay) {
      this.enableScrollLock()
    } else {
      this.disableScrollLock()
    }
  }

  enableScrollLock() {
    document.body.classList.add("overflow-hidden")
  }

  disableScrollLock() {
    document.body.classList.remove("overflow-hidden")
  }

  clearTimers() {
    if (this.showTimeout) {
      window.clearTimeout(this.showTimeout)
      this.showTimeout = null
    }

    if (this.hideTimeout) {
      window.clearTimeout(this.hideTimeout)
      this.hideTimeout = null
    }
  }

  promptAlreadyAnimated() {
    if (!this.serviceIdValue) return false

    window.__serviceCreationAnimatedIds ||= new Set()
    return window.__serviceCreationAnimatedIds.has(this.serviceIdValue)
  }

  markPromptAnimated() {
    if (!this.serviceIdValue) return

    window.__serviceCreationAnimatedIds ||= new Set()
    window.__serviceCreationAnimatedIds.add(this.serviceIdValue)
  }

  clearModalParamsFromUrl() {
    if (!this.hasClearParamsValue || this.clearParamsValue.length === 0) return

    const url = new URL(window.location.href)
    const hadAnyModalParam = this.clearParamsValue.some((paramName) => url.searchParams.has(paramName))

    if (!hadAnyModalParam) return

    this.clearParamsValue.forEach((paramName) => url.searchParams.delete(paramName))

    const nextUrl = `${url.pathname}${url.search}${url.hash}`
    window.history.replaceState({}, "", nextUrl)
  }

  beforeCache() {
    this.clearTimers()
    this.promptOpenValue = false

    if (this.hasPromptOverlayTarget && this.hasPromptPanelTarget) {
      this.applyClosedState(this.promptOverlayTarget, this.promptPanelTarget)
      this.promptOverlayTarget.classList.add("hidden", "pointer-events-none")
      this.promptOverlayTarget.classList.remove("flex")
    }

    if (this.hasTaskOverlayTarget && this.hasTaskPanelTarget) {
      this.applyClosedState(this.taskOverlayTarget, this.taskPanelTarget)
      this.taskOverlayTarget.classList.add("hidden", "pointer-events-none")
      this.taskOverlayTarget.classList.remove("flex")
    }

    this.disableScrollLock()
  }
}
