import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["input", "row", "table", "noResults"]
  static values = {
    delay: { type: Number, default: 500 },
    mode: { type: String, default: "client" }
  }

  connect() {
    this.submitTimeout = null
    this.handlePopState = this.restoreFromUrl.bind(this)
    this.handleRefresh = () => this.filterRows({ syncUrl: false })
    window.addEventListener("popstate", this.handlePopState)
    this.element.addEventListener("search-form:refresh", this.handleRefresh)
    this.restoreFromUrl()
  }

  disconnect() {
    this.clearSubmitTimeout()
    window.removeEventListener("popstate", this.handlePopState)
    this.element.removeEventListener("search-form:refresh", this.handleRefresh)
  }

  submitWithDebounce() {
    this.clearSubmitTimeout()
    this.submitTimeout = window.setTimeout(() => {
      this.modeValue === "server" ? this.submitQuery() : this.filterRows()
    }, this.delayValue)
  }

  clearSubmitTimeout() {
    if (!this.submitTimeout) return

    window.clearTimeout(this.submitTimeout)
    this.submitTimeout = null
  }

  filterRows({ syncUrl = true } = {}) {
    if (this.modeValue === "server") {
      if (syncUrl) this.submitQuery()
      return
    }

    if (!this.hasInputTarget) return

    const query = this.inputTarget.value.trim().toLowerCase()
    let visibleCount = 0

    this.rowTargets.forEach((row) => {
      const searchText = (row.dataset.searchText || row.dataset.searchName || "").toLowerCase()
      const matches = query === "" || searchText.includes(query)

      row.classList.toggle("hidden", !matches)
      if (matches) visibleCount += 1
    })

    if (this.hasTableTarget) {
      this.tableTarget.classList.toggle("hidden", visibleCount === 0)
    }

    if (this.hasNoResultsTarget) {
      this.noResultsTarget.classList.toggle("hidden", visibleCount > 0)
    }

    if (syncUrl) this.syncUrl(query)
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

  submitQuery() {
    if (!this.hasInputTarget) return

    const query = this.inputTarget.value.trim()
    const url = new URL(window.location.href)

    if (query === "") {
      url.searchParams.delete("q")
    } else {
      url.searchParams.set("q", query)
    }

    url.searchParams.delete("page")
    Turbo.visit(url.toString())
  }

  restoreFromUrl() {
    if (!this.hasInputTarget) return

    const url = new URL(window.location.href)
    this.inputTarget.value = url.searchParams.get("q") || ""

    if (this.modeValue === "client") {
      this.filterRows({ syncUrl: false })
    }
  }
}
