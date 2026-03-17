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

window.openAnimatedDialog = openAnimatedDialog
window.closeAnimatedDialog = closeAnimatedDialog

document.addEventListener("turbo:load", openPendingDialogs)
document.addEventListener("DOMContentLoaded", openPendingDialogs)
