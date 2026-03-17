import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "row", "table", "noResults"]

  connect() {
    this.submitTimeout = null
    this.filterRows()
  }

  disconnect() {
    this.clearSubmitTimeout()
  }

  submitWithDebounce() {
    this.clearSubmitTimeout()
    this.submitTimeout = window.setTimeout(() => {
      this.filterRows()
    }, 300)
  }

  clearSubmitTimeout() {
    if (!this.submitTimeout) return

    window.clearTimeout(this.submitTimeout)
    this.submitTimeout = null
  }

  filterRows() {
    if (!this.hasInputTarget) return

    const query = this.inputTarget.value.trim().toLowerCase()
    let visibleCount = 0

    this.rowTargets.forEach((row) => {
      const name = (row.dataset.searchName || "").toLowerCase()
      const matches = query === "" || name.includes(query)

      row.classList.toggle("hidden", !matches)
      if (matches) visibleCount += 1
    })

    if (this.hasTableTarget) {
      this.tableTarget.classList.toggle("hidden", visibleCount === 0)
    }

    if (this.hasNoResultsTarget) {
      this.noResultsTarget.classList.toggle("hidden", visibleCount > 0)
    }

    this.syncUrl(query)
  }

  syncUrl(query) {
    const url = new URL(window.location.href)

    if (query === "") {
      url.searchParams.delete("q")
    } else {
      url.searchParams.set("q", query)
    }

    window.history.replaceState({}, "", url)
  }
}
