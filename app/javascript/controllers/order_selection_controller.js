import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "count", "master", "submitButton"]

  connect() {
    this.sync()
  }

  toggleAll(event) {
    const checked = event.target.checked

    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = checked
    })

    this.resetConfirmation()
    this.sync()
  }

  toggleOne(event) {
    const { checked, value } = event.target

    this.checkboxTargets
      .filter((checkbox) => checkbox.value === value)
      .forEach((checkbox) => {
        checkbox.checked = checked
      })

    this.resetConfirmation()
    this.sync()
  }

  sync() {
    const selectedCount = this.selectedIds.size
    const totalCount = this.totalIds.size

    this.countTargets.forEach((target) => {
      target.textContent = selectedCount.toString()
    })

    this.masterTargets.forEach((target) => {
      target.checked = totalCount > 0 && selectedCount === totalCount
      target.indeterminate = selectedCount > 0 && selectedCount < totalCount
    })

    if (!this.hasSubmitButtonTarget) return

    this.submitButtonTarget.disabled = selectedCount === 0
    this.submitButtonTarget.classList.toggle("cursor-not-allowed", selectedCount === 0)
    this.submitButtonTarget.classList.toggle("opacity-50", selectedCount === 0)
  }

  resetConfirmation() {
    const confirmController = this.application.getControllerForElementAndIdentifier(this.element, "confirm-submit")
    confirmController?.reset()
  }

  get selectedIds() {
    return new Set(
      this.checkboxTargets
        .filter((checkbox) => checkbox.checked)
        .map((checkbox) => checkbox.value)
    )
  }

  get totalIds() {
    return new Set(this.checkboxTargets.map((checkbox) => checkbox.value))
  }
}
