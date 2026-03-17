import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = ["collapsed"]
  static targets = ["reopenButton"]

  connect() {
    this.restoreState()
    this.syncReopenButton()
  }

  toggle() {
    this.element.classList.toggle(this.collapsedClass)
    this.persistState()
    this.syncReopenButton()
  }

  open() {
    this.element.classList.remove(this.collapsedClass)
    this.persistState()
    this.syncReopenButton()
  }

  revealReopen() {
    if (!this.element.classList.contains(this.collapsedClass) || !this.hasReopenButtonTarget) return

    this.reopenButtonTarget.classList.remove("pointer-events-none", "opacity-0")
    this.reopenButtonTarget.classList.add("pointer-events-auto", "opacity-100")
  }

  hideReopen() {
    if (!this.hasReopenButtonTarget) return

    this.reopenButtonTarget.classList.remove("pointer-events-auto", "opacity-100")
    this.reopenButtonTarget.classList.add("pointer-events-none", "opacity-0")
  }

  restoreState() {
    const isCollapsed = window.localStorage.getItem(this.storageKey) === "true"

    this.syncDocumentState(isCollapsed)
    this.element.classList.toggle(this.collapsedClass, isCollapsed)
  }

  persistState() {
    window.localStorage.setItem(this.storageKey, this.isCollapsed.toString())
    this.syncDocumentState(this.isCollapsed)
  }

  syncReopenButton() {
    if (!this.isCollapsed) this.hideReopen()
  }

  get isCollapsed() {
    return this.element.classList.contains(this.collapsedClass)
  }

  get storageKey() {
    return "sidebar-layout-collapsed"
  }

  syncDocumentState(isCollapsed) {
    document.documentElement.dataset.sidebarLayoutCollapsed = isCollapsed.toString()
  }
}
