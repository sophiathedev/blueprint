import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "label", "menu", "panel", "trigger", "search", "searchWrapper", "option", "optionsWrapper", "emptyState"]
  static values = {
    submitOnChoose: { type: Boolean, default: false },
    searchDelay: { type: Number, default: 500 }
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
  }

  disconnect() {
    window.removeEventListener("floating-ui:open", this.handleFloatingOpen)
    window.removeEventListener("resize", this.handleViewportChange)
    window.removeEventListener("scroll", this.handleViewportChange, true)
    this.clearFilterTimeout()
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
      this.filter()
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

    this.close()
    if (this.submitOnChooseValue) {
      this.inputTarget.form?.requestSubmit()
    }
  }

  filterWithDebounce() {
    this.clearFilterTimeout()
    this.filterTimeout = window.setTimeout(() => this.filter(), this.searchDelayValue)
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
}
