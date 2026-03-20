import { Turbo } from "@hotwired/turbo-rails"
import { Controller } from "@hotwired/stimulus"
import { application } from "controllers/application"

export default class extends Controller {
  static values = {
    closeDelay: { type: Number, default: 300 },
    closeMode: { type: String, default: "modal" }
  }

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

    const closer = this.modalCloser()
    if (!closer) return

    event.preventDefault()

    fetchResponse.responseText.then((html) => {
      this.element.reset()
      closer.close()

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

  modalCloser() {
    if (this.closeModeValue === "service-creation-task") {
      return this.serviceCreationTaskCloser()
    }

    const modalElement = this.element.closest("[data-controller~='modal']")
    if (modalElement) {
      const modalController = application.getControllerForElementAndIdentifier(modalElement, "modal")
      if (modalController) {
        return {
          close: () => modalController.close()
        }
      }
    }

    return this.serviceCreationTaskCloser()
  }

  serviceCreationTaskCloser() {
    const serviceCreationFlowElement = this.element.closest("[data-controller~='service-creation-flow']")
    if (!serviceCreationFlowElement) return null

    const serviceCreationFlowController = application.getControllerForElementAndIdentifier(
      serviceCreationFlowElement,
      "service-creation-flow"
    )
    if (!serviceCreationFlowController) return null

    return {
      close: () => serviceCreationFlowController.closeTask()
    }
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
