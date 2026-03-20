import { Turbo } from "@hotwired/turbo-rails"
import { Controller } from "@hotwired/stimulus"
import { application } from "controllers/application"

export default class extends Controller {
  static values = { closeDelay: { type: Number, default: 300 } }

  connect() {
    this.submitting = false
  }

  handleSubmit(event) {
    if (this.submitting) {
      event.preventDefault()
      return
    }

    this.submitting = true
    this.toggleSubmitters(true)
  }

  beforeFetchResponse(event) {
    const { fetchResponse } = event.detail
    if (!fetchResponse?.succeeded) return

    const contentType = fetchResponse.response.headers.get("Content-Type") || ""
    if (!contentType.includes("turbo-stream")) return

    const modalController = this.modalController()
    if (!modalController) return

    event.preventDefault()

    fetchResponse.responseText.then((html) => {
      this.element.reset()
      modalController.close()

      window.setTimeout(() => {
        Turbo.renderStreamMessage(html)
        this.finishSubmission()
      }, this.closeDelayValue)
    })
  }

  submitEnd(event) {
    if (event.detail.success) return

    this.finishSubmission()
  }

  modalController() {
    const modalElement = this.element.closest("[data-controller~='modal']")
    if (!modalElement) return null

    return application.getControllerForElementAndIdentifier(modalElement, "modal")
  }

  finishSubmission() {
    this.submitting = false
    this.toggleSubmitters(false)
  }

  toggleSubmitters(disabled) {
    this.element.querySelectorAll("button[type='submit'], input[type='submit']").forEach((submitter) => {
      submitter.disabled = disabled
    })
  }
}
