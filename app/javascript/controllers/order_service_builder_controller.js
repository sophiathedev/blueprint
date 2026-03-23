import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["partnerName"]

  serviceChanged(event) {
    if (!this.hasPartnerNameTarget) return

    this.partnerNameTarget.value = event.detail?.dataset?.partnerName || ""
  }
}
