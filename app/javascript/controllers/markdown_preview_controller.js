import { Controller } from "@hotwired/stimulus"
import DOMPurify from "dompurify"
import { marked } from "marked"

export default class extends Controller {
  static values = {
    content: String
  }

  connect() {
    marked.setOptions({
      breaks: true,
      gfm: true
    })

    this.element.innerHTML = DOMPurify.sanitize(marked.parse(this.contentValue || ""), {
      USE_PROFILES: { html: true }
    })
  }
}
