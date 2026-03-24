import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["statusLabel", "progressWrapper", "progressRing", "progressValue", "lastSyncedAt", "nextSyncAt", "errorBox", "errorText", "cancelButton"]
  static values = {
    url: String,
    interval: { type: Number, default: 2000 }
  }

  connect() {
    this.poll()
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.stopPolling()
    this.timer = window.setInterval(() => this.poll(), this.intervalValue)
  }

  stopPolling() {
    if (!this.timer) return

    window.clearInterval(this.timer)
    this.timer = null
  }

  async poll() {
    if (!this.hasUrlValue) return

    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("_ts", `${Date.now()}`)

      const response = await fetch(url.toString(), {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
        cache: "no-store"
      })
      if (!response.ok) return

      const data = await response.json()
      this.render(data)
    } catch (_error) {
    }
  }

  render(data) {
    if (this.hasStatusLabelTarget) this.statusLabelTarget.textContent = data.status_label
    if (this.hasLastSyncedAtTarget) this.lastSyncedAtTarget.textContent = data.last_synced_at || "Chưa có"
    if (this.hasNextSyncAtTarget) this.nextSyncAtTarget.textContent = data.next_sync_at || "Chưa lên lịch"

    if (this.hasErrorBoxTarget && this.hasErrorTextTarget) {
      if (data.error) {
        this.errorTextTarget.textContent = data.error
        this.errorBoxTarget.classList.remove("hidden")
      } else {
        this.errorTextTarget.textContent = ""
        this.errorBoxTarget.classList.add("hidden")
      }
    }

    if (this.hasCancelButtonTarget) {
      this.cancelButtonTarget.classList.toggle("hidden", !data.cancellable)
    }

    const syncing = data.status === "syncing"

    if (this.hasProgressWrapperTarget) {
      this.progressWrapperTarget.classList.toggle("hidden", !syncing)
    }

    if (this.hasProgressValueTarget) {
      this.progressValueTarget.classList.toggle("hidden", !syncing)
    }

    this.renderProgress(data.progress || 0)
  }

  renderProgress(progress) {
    const normalizedProgress = Math.max(0, Math.min(100, Number(progress) || 0))
    const radius = 7
    const circumference = 2 * Math.PI * radius
    const offset = circumference - (normalizedProgress / 100) * circumference

    if (this.hasProgressRingTarget) {
      this.progressRingTarget.style.strokeDasharray = `${circumference}`
      this.progressRingTarget.style.strokeDashoffset = `${offset}`
    }

    if (this.hasProgressValueTarget) {
      this.progressValueTarget.textContent = `${normalizedProgress}%`
    }
  }
}
