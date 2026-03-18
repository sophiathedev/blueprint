import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["defaultIcon", "successIcon"]
  static values = { text: String }

  connect() {
    this.resetTimer = null
  }

  disconnect() {
    this.clearResetTimer()
  }

  async copy() {
    if (!this.textValue) return

    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(this.textValue)
      } else {
        this.fallbackCopy()
      }

      this.showSuccessState()
    } catch (_error) {
      this.fallbackCopy()
      this.showSuccessState()
    }
  }

  fallbackCopy() {
    const input = document.createElement("textarea")
    input.value = this.textValue
    input.setAttribute("readonly", "")
    input.style.position = "absolute"
    input.style.left = "-9999px"
    document.body.appendChild(input)
    input.select()
    document.execCommand("copy")
    document.body.removeChild(input)
  }

  showSuccessState() {
    if (this.hasDefaultIconTarget) this.defaultIconTarget.classList.add("hidden")
    if (this.hasSuccessIconTarget) this.successIconTarget.classList.remove("hidden")

    this.clearResetTimer()
    this.resetTimer = window.setTimeout(() => {
      if (this.hasDefaultIconTarget) this.defaultIconTarget.classList.remove("hidden")
      if (this.hasSuccessIconTarget) this.successIconTarget.classList.add("hidden")
    }, 1400)
  }

  clearResetTimer() {
    if (!this.resetTimer) return

    window.clearTimeout(this.resetTimer)
    this.resetTimer = null
  }
}
