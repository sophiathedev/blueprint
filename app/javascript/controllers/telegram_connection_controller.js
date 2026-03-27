import { Controller } from "@hotwired/stimulus"

const DEFAULT_COUNTDOWN_SECONDS = 60

export default class extends Controller {
  static targets = ["connectButton", "connectLabel"]
  static values = {
    countdownSeconds: { type: Number, default: DEFAULT_COUNTDOWN_SECONDS },
    storageKey: String,
    statusUrl: String
  }

  connect() {
    this.syncCountdown()
  }

  disconnect() {
    this.stopTimer()
  }

  startCountdown() {
    const expiresAt = Date.now() + (this.countdownSecondsValue * 1000)
    this.writeExpiresAt(expiresAt)
    this.renderRemainingTime()
    this.startTimer()
  }

  syncCountdown() {
    if (!this.hasConnectButtonTarget || !this.hasConnectLabelTarget) return

    const expiresAt = this.readExpiresAt()
    if (!expiresAt || expiresAt <= Date.now()) {
      this.clearExpiresAt()
      this.enableButton()
      return
    }

    this.renderRemainingTime()
    this.startTimer()
  }

  startTimer() {
    this.stopTimer()
    this.timer = window.setInterval(() => this.renderRemainingTime(), 1000)
  }

  stopTimer() {
    if (!this.timer) return

    window.clearInterval(this.timer)
    this.timer = null
  }

  renderRemainingTime() {
    const expiresAt = this.readExpiresAt()
    const remainingSeconds = expiresAt ? Math.ceil((expiresAt - Date.now()) / 1000) : 0

    if (remainingSeconds <= 0) {
      this.clearExpiresAt()
      this.stopTimer()
      this.checkConnectionStatus()
      return
    }

    this.disableButton(remainingSeconds)
  }

  disableButton(remainingSeconds) {
    this.connectButtonTarget.disabled = true
    this.connectButtonTarget.classList.add("cursor-not-allowed", "opacity-70")
    this.connectLabelTarget.textContent = `Liên kết với Telegram (${remainingSeconds}s)`
  }

  enableButton() {
    this.connectButtonTarget.disabled = false
    this.connectButtonTarget.classList.remove("cursor-not-allowed", "opacity-70")
    this.connectLabelTarget.textContent = "Liên kết với Telegram"
  }

  async checkConnectionStatus() {
    if (!this.statusUrlValue) {
      this.enableButton()
      return
    }

    try {
      const response = await window.fetch(this.statusUrlValue, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })

      if (!response.ok) throw new Error(`Request failed with ${response.status}`)

      const payload = await response.json()

      if (payload.connected && payload.redirect_url) {
        window.location.href = payload.redirect_url
        return
      }
    } catch (_error) {
      // Fall back to re-enabling the button if the status check fails.
    }

    this.enableButton()
  }

  readExpiresAt() {
    const rawValue = window.localStorage.getItem(this.storageKey)
    if (!rawValue) return null

    const parsedValue = Number(rawValue)
    return Number.isFinite(parsedValue) ? parsedValue : null
  }

  writeExpiresAt(expiresAt) {
    window.localStorage.setItem(this.storageKey, String(expiresAt))
  }

  clearExpiresAt() {
    window.localStorage.removeItem(this.storageKey)
  }

  get storageKey() {
    return this.storageKeyValue || "telegram-connection-countdown"
  }
}
