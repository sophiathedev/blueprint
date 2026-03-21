import { Turbo } from "@hotwired/turbo-rails"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    preloadOffset: { type: Number, default: 50 }
  }

  connect() {
    this.loading = false
    this.observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) this.load()
    }, { rootMargin: `${this.preloadOffsetValue}px 0px` })

    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  async load() {
    if (this.loading || !this.hasUrlValue) return

    this.loading = true

    try {
      const response = await fetch(this.urlValue, {
        headers: {
          Accept: "text/vnd.turbo-stream.html"
        }
      })

      if (!response.ok) throw new Error(`Unable to load more services: ${response.status}`)

      Turbo.renderStreamMessage(await response.text())
      window.requestAnimationFrame(() => {
        this.refreshLastRow()
        this.reapplySearchFilter()
      })
    } catch (error) {
      console.error(error)
    } finally {
      this.loading = false
    }
  }

  refreshLastRow() {
    const rows = Array.from(document.querySelectorAll("[data-service-row-item]"))

    rows.forEach((row, index) => {
      row.dataset.serviceRowCollapseLastValue = String(index === rows.length - 1)
    })
  }

  reapplySearchFilter() {
    const searchContainers = document.querySelectorAll("[data-controller~='search-form']")

    searchContainers.forEach((container) => {
      container.dispatchEvent(new CustomEvent("search-form:refresh", { bubbles: true }))
    })
  }
}
