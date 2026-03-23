import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "label", "menu", "panel", "trigger", "search", "searchWrapper", "option", "optionsWrapper", "emptyState"]
  static values = {
    submitOnChoose: { type: Boolean, default: false },
    searchDelay: { type: Number, default: 500 },
    remoteSearchUrl: String
  }

  connect() {
    this.isOpen = false
    this.opensUpward = false
    this.handleFloatingOpen = this.closeWhenAnotherOpens.bind(this)
    this.handleViewportChange = this.repositionMenu.bind(this)
    window.addEventListener("floating-ui:open", this.handleFloatingOpen)
    window.addEventListener("resize", this.handleViewportChange)
    window.addEventListener("scroll", this.handleViewportChange, true)
    this.filterTimeout = null
    this.abortController = null
  }

  disconnect() {
    window.removeEventListener("floating-ui:open", this.handleFloatingOpen)
    window.removeEventListener("resize", this.handleViewportChange)
    window.removeEventListener("scroll", this.handleViewportChange, true)
    this.clearFilterTimeout()
    this.abortController?.abort()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    this.isOpen ? this.close() : this.open()
  }

  open() {
    if (!this.hasMenuTarget) return

    window.dispatchEvent(new CustomEvent("floating-ui:open", { detail: { source: this.element } }))
    this.isOpen = true
    this.triggerTarget.setAttribute("aria-expanded", "true")
    this.repositionMenu()
    this.menuTarget.classList.remove("pointer-events-none", "opacity-0")
    if (this.hasSearchTarget) {
      this.searchTarget.value = ""
      if (this.hasRemoteSearchUrlValue) {
        this.fetchOptions("")
      } else {
        this.filter()
      }
      requestAnimationFrame(() => this.searchTarget.focus())
    }
  }

  close() {
    if (!this.hasMenuTarget) return

    this.isOpen = false
    this.triggerTarget.setAttribute("aria-expanded", "false")
    this.menuTarget.classList.add("pointer-events-none", "opacity-0")
  }

  closeOnOutside(event) {
    if (this.element.contains(event.target)) return

    this.close()
  }

  choose(event) {
    event.preventDefault()

    const button = event.currentTarget
    const { value, label } = button.dataset

    if (this.hasInputTarget) this.inputTarget.value = value
    if (this.hasLabelTarget) this.labelTarget.textContent = label

    this.element.querySelectorAll("[role='option']").forEach((option) => {
      const active = option === button
      option.setAttribute("aria-selected", active ? "true" : "false")
      option.classList.toggle("bg-primary-50", active)
      option.classList.toggle("font-semibold", active)
      option.classList.toggle("text-primary-800", active)
      option.classList.toggle("text-black", !active)
      option.classList.toggle("hover:bg-stone-100", !active)

      const icon = option.querySelector("[data-select-field-check]")
      if (icon) icon.classList.toggle("invisible", !active)
    })

    this.element.dispatchEvent(new CustomEvent("select-field:change", {
      bubbles: true,
      detail: { value, label, dataset: { ...button.dataset } }
    }))

    this.close()
    if (this.submitOnChooseValue) {
      this.inputTarget.form?.requestSubmit()
    }
  }

  filterWithDebounce() {
    this.clearFilterTimeout()
    this.filterTimeout = window.setTimeout(() => {
      if (this.hasRemoteSearchUrlValue) {
        this.fetchOptions(this.searchTarget?.value || "")
      } else {
        this.filter()
      }
    }, this.searchDelayValue)
  }

  filter() {
    if (!this.hasSearchTarget) return

    const query = this.searchTarget.value.trim().toLowerCase()
    let visibleCount = 0

    this.optionTargets.forEach((option) => {
      const label = option.dataset.label.toLowerCase()
      const matches = query === "" || label.includes(query)
      option.classList.toggle("hidden", !matches)
      if (matches) visibleCount += 1
    })

    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.toggle("hidden", visibleCount > 0)
    }
  }

  focusFirstOption(event) {
    if (!this.hasOptionTarget) return

    event.preventDefault()
    this.optionTargets.find((option) => !option.classList.contains("hidden"))?.focus()
  }

  closeWhenAnotherOpens(event) {
    if (event.detail?.source === this.element) return

    this.close()
  }

  repositionMenu() {
    if (!this.isOpen || !this.hasMenuTarget || !this.hasTriggerTarget || !this.hasPanelTarget) return

    this.applyDirection(this.shouldOpenUpward())
  }

  shouldOpenUpward() {
    const triggerRect = this.triggerTarget.getBoundingClientRect()
    const viewportHeight = window.innerHeight
    const gap = 8
    const menuHeight = this.panelTarget.offsetHeight
    const spaceBelow = viewportHeight - triggerRect.bottom
    const spaceAbove = triggerRect.top

    return spaceBelow < menuHeight + gap && spaceAbove > spaceBelow
  }

  applyDirection(openUpward) {
    this.opensUpward = openUpward

    this.menuTarget.classList.toggle("top-full", !openUpward)
    this.menuTarget.classList.toggle("mt-2", !openUpward)
    this.menuTarget.classList.toggle("bottom-full", openUpward)
    this.menuTarget.classList.toggle("mb-2", openUpward)

    if (this.hasPanelTarget) {
      this.panelTarget.classList.toggle("flex-col", !openUpward)
      this.panelTarget.classList.toggle("flex-col-reverse", openUpward)
    }

    if (this.hasSearchWrapperTarget) {
      this.searchWrapperTarget.classList.toggle("pb-2", !openUpward)
      this.searchWrapperTarget.classList.toggle("pt-2", openUpward)
    }
  }

  clearFilterTimeout() {
    if (!this.filterTimeout) return

    window.clearTimeout(this.filterTimeout)
    this.filterTimeout = null
  }

  async fetchOptions(query) {
    if (!this.hasRemoteSearchUrlValue || !this.hasOptionsWrapperTarget) return

    this.abortController?.abort()
    this.abortController = new AbortController()

    const url = new URL(this.remoteSearchUrlValue, window.location.origin)
    if (query.trim() !== "") url.searchParams.set("q", query.trim())

    try {
      const response = await fetch(url.toString(), {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal
      })
      if (!response.ok) return

      const options = await response.json()
      this.renderRemoteOptions(options)
    } catch (error) {
      if (error.name !== "AbortError") console.error(error)
    }
  }

  renderRemoteOptions(options) {
    this.optionTargets.forEach((option) => option.remove())

    const selectedValue = this.hasInputTarget ? this.inputTarget.value : ""
    const emptyAnchor = this.hasEmptyStateTarget ? this.emptyStateTarget : null

    options.forEach((option) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = this.optionClasses(option.value === selectedValue)
      button.dataset.action = "click->select-field#choose"
      button.dataset.value = option.value
      button.dataset.label = option.label
      button.dataset.selectFieldTarget = "option"
      button.setAttribute("role", "option")
      button.setAttribute("aria-selected", option.value === selectedValue ? "true" : "false")

      Object.entries(option.data || {}).forEach(([key, value]) => {
        button.dataset[this.datasetKey(key)] = value
      })

      const label = document.createElement("span")
      label.className = "truncate"
      label.textContent = option.label

      const check = document.createElement("span")
      check.dataset.selectFieldCheck = ""
      check.className = option.value === selectedValue ? "text-primary-700" : "invisible"
      check.textContent = "✓"

      button.append(label, check)

      if (emptyAnchor) {
        this.optionsWrapperTarget.insertBefore(button, emptyAnchor)
      } else {
        this.optionsWrapperTarget.append(button)
      }
    })

    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.toggle("hidden", options.length > 0)
    }
  }

  optionClasses(selected) {
    return [
      "flex w-full items-center justify-between gap-3 rounded-xl px-3 py-2 text-sm transition-colors",
      selected ? "bg-primary-50 font-semibold text-primary-800" : "text-black hover:bg-stone-100"
    ].join(" ")
  }

  datasetKey(key) {
    return key.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase())
  }
}
