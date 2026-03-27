// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

const openAnimatedDialog = (dialog) => {
  if (!dialog || dialog.open) return

  dialog.dataset.state = "opening"
  dialog.showModal()
  dialog.getBoundingClientRect()

  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      dialog.dataset.state = "open"
    })
  })
}

const closeAnimatedDialog = (dialog) => {
  if (!dialog || !dialog.open || dialog.dataset.state === "closing") return

  dialog.dataset.state = "closing"

  window.setTimeout(() => {
    dialog.close()
    dialog.dataset.state = "closed"
  }, 220)
}

const openPendingDialogs = () => {
  document.querySelectorAll("dialog[data-auto-open='true']").forEach((dialog) => {
    openAnimatedDialog(dialog)
    dialog.querySelector("[data-autofocus-modal]")?.focus()
    dialog.dataset.autoOpen = "false"
  })
}

const googleSheetsStatusPollers = new WeakMap()
const GOOGLE_SHEETS_LINK_PLACEHOLDER = "Chưa có link. Hãy bấm Sync ngay để hệ thống tự tạo."

const renderGoogleSheetsSyncStatus = (element, data) => {
  const statusLabel = element.querySelector('[data-google-sheets-sync-status-target="statusLabel"]')
  const progressWrapper = element.querySelector('[data-google-sheets-sync-status-target="progressWrapper"]')
  const progressRing = element.querySelector('[data-google-sheets-sync-status-target="progressRing"]')
  const progressValue = element.querySelector('[data-google-sheets-sync-status-target="progressValue"]')
  const lastSyncedAt = element.querySelector('[data-google-sheets-sync-status-target="lastSyncedAt"]')
  const nextSyncAt = element.querySelector('[data-google-sheets-sync-status-target="nextSyncAt"]')
  const errorBox = element.querySelector('[data-google-sheets-sync-status-target="errorBox"]')
  const errorText = element.querySelector('[data-google-sheets-sync-status-target="errorText"]')
  const cancelButton = element.querySelector('[data-google-sheets-sync-status-target="cancelButton"]')
  const spreadsheetLinkInput = element.querySelector('[data-google-sheets-sync-status-target="spreadsheetLinkInput"]')
  const spreadsheetLinkAction = element.querySelector('[data-google-sheets-sync-status-target="spreadsheetLinkAction"]')

  if (statusLabel) statusLabel.textContent = data.status_label
  if (lastSyncedAt) lastSyncedAt.textContent = data.last_synced_at || "Chưa có"
  if (nextSyncAt) nextSyncAt.textContent = data.next_sync_at || "Chưa lên lịch"
  if (spreadsheetLinkInput) spreadsheetLinkInput.value = data.spreadsheet_link || GOOGLE_SHEETS_LINK_PLACEHOLDER

  if (spreadsheetLinkAction) {
    if (data.spreadsheet_link) {
      spreadsheetLinkAction.href = data.spreadsheet_link
      spreadsheetLinkAction.removeAttribute("aria-disabled")
      spreadsheetLinkAction.removeAttribute("tabindex")
      spreadsheetLinkAction.classList.remove("pointer-events-none", "text-black/45")
      spreadsheetLinkAction.classList.add("text-black", "hover:bg-stone-100")
    } else {
      spreadsheetLinkAction.removeAttribute("href")
      spreadsheetLinkAction.setAttribute("aria-disabled", "true")
      spreadsheetLinkAction.setAttribute("tabindex", "-1")
      spreadsheetLinkAction.classList.add("pointer-events-none", "text-black/45")
      spreadsheetLinkAction.classList.remove("text-black", "hover:bg-stone-100")
    }
  }

  if (errorBox && errorText) {
    if (data.error) {
      errorText.textContent = data.error
      errorBox.classList.remove("hidden")
    } else {
      errorText.textContent = ""
      errorBox.classList.add("hidden")
    }
  }

  if (cancelButton) {
    cancelButton.classList.toggle("hidden", !data.cancellable)
  }

  const syncing = data.status === "syncing"
  progressWrapper?.classList.toggle("hidden", !syncing)
  progressValue?.classList.toggle("hidden", !syncing)

  const normalizedProgress = Math.max(0, Math.min(100, Number(data.progress) || 0))
  const radius = 7
  const circumference = 2 * Math.PI * radius
  const offset = circumference - (normalizedProgress / 100) * circumference

  if (progressRing) {
    progressRing.style.strokeDasharray = `${circumference}`
    progressRing.style.strokeDashoffset = `${offset}`
  }

  if (progressValue) {
    progressValue.textContent = `${normalizedProgress}%`
  }
}

const startGoogleSheetsStatusPolling = () => {
  document.querySelectorAll("[data-google-sheets-sync-status-url-value]").forEach((element) => {
    const existingPoller = googleSheetsStatusPollers.get(element)
    if (existingPoller) return

    const poll = async () => {
      const urlValue = element.dataset.googleSheetsSyncStatusUrlValue
      if (!urlValue) return

      try {
        const url = new URL(urlValue, window.location.origin)
        url.searchParams.set("_ts", `${Date.now()}`)

        const response = await fetch(url.toString(), {
          headers: { Accept: "application/json" },
          credentials: "same-origin",
          cache: "no-store"
        })

        if (!response.ok) return

        const data = await response.json()
        renderGoogleSheetsSyncStatus(element, data)
      } catch (_error) {
      }
    }

    poll()
    const timer = window.setInterval(poll, 2000)
    googleSheetsStatusPollers.set(element, timer)
  })
}

const stopGoogleSheetsStatusPolling = () => {
  document.querySelectorAll("[data-google-sheets-sync-status-url-value]").forEach((element) => {
    const timer = googleSheetsStatusPollers.get(element)
    if (!timer) return

    window.clearInterval(timer)
    googleSheetsStatusPollers.delete(element)
  })
}

window.openAnimatedDialog = openAnimatedDialog
window.closeAnimatedDialog = closeAnimatedDialog

document.addEventListener("turbo:load", () => {
  openPendingDialogs()
  startGoogleSheetsStatusPolling()
})
document.addEventListener("DOMContentLoaded", () => {
  openPendingDialogs()
  startGoogleSheetsStatusPolling()
})
document.addEventListener("turbo:before-cache", stopGoogleSheetsStatusPolling)
