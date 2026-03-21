import { Controller } from "@hotwired/stimulus"
import DOMPurify from "dompurify"
import { marked } from "marked"

export default class extends Controller {
  static targets = [
    "editPanel",
    "previewPanel",
    "editTab",
    "previewTab",
    "previewAction",
    "previewActionButton",
    "input",
    "preview",
    "fullscreenModal",
    "modalInput",
    "modalPreview"
  ]

  connect() {
    this.previewLoaded = false
    this.modalPreviewLoaded = false
    marked.setOptions({
      breaks: true,
      gfm: true
    })
    this.showEdit()
  }

  showEdit() {
    this.editPanelTarget.classList.remove("hidden")
    this.previewPanelTarget.classList.add("hidden")
    this.setActiveTab(this.editTabTarget, true)
    this.setActiveTab(this.previewTabTarget, false)
  }

  showPreview() {
    this.editPanelTarget.classList.add("hidden")
    this.previewPanelTarget.classList.remove("hidden")
    this.setActiveTab(this.editTabTarget, false)
    this.setActiveTab(this.previewTabTarget, true)
    this.loadPreview()
  }

  handleInput() {
    this.syncInputsFrom(this.activeInput)
    this.previewLoaded = false
    this.modalPreviewLoaded = false

    if (!this.previewPanelTarget.classList.contains("hidden")) {
      this.loadPreview()
    }

    if (this.hasModalPreviewTarget && this.isFullscreenOpen()) {
      this.loadModalPreview()
    }
  }

  handlePaste(event) {
    const input = event.currentTarget
    const pastedText = event.clipboardData?.getData("text/plain")?.trim()

    if (!input || !this.isPasteableUrl(pastedText)) return

    event.preventDefault()

    const start = input.selectionStart ?? input.value.length
    const end = input.selectionEnd ?? input.value.length
    const selectedText = input.value.slice(start, end).trim()
    const replacement = selectedText
      ? `[${selectedText}](${pastedText})`
      : `[${pastedText}](${pastedText})`
    const selectionOffset = selectedText ? replacement.length : pastedText.length + 1

    this.applyReplacement(input, start, end, replacement, selectionOffset, selectionOffset)
  }

  insertHelper(event) {
    const helper = event.currentTarget.dataset.markdownHelper
    if (!helper) return

    const input = this.activeInput
    const start = input.selectionStart ?? input.value.length
    const end = input.selectionEnd ?? input.value.length
    const selectedText = input.value.slice(start, end)

    const strategies = {
      heading1: () => this.prefixLines(start, end, selectedText, "# "),
      heading2: () => this.prefixLines(start, end, selectedText, "## "),
      heading3: () => this.prefixLines(start, end, selectedText, "### "),
      heading4: () => this.prefixLines(start, end, selectedText, "#### "),
      heading5: () => this.prefixLines(start, end, selectedText, "##### "),
      heading6: () => this.prefixLines(start, end, selectedText, "###### "),
      bold: () => this.wrapSelection(start, end, selectedText, "**", "**"),
      italic: () => this.wrapSelection(start, end, selectedText, "*", "*"),
      list: () => this.prefixLines(start, end, selectedText, "- "),
      quote: () => this.prefixLines(start, end, selectedText, "> "),
      link: () => this.insertLink(start, end, selectedText),
      code: () => this.wrapSelection(start, end, selectedText, "`", "`")
    }

    const strategy = strategies[helper]
    if (!strategy) return

    strategy()
    this.handleInput()
    input.focus()
  }

  async loadPreview() {
    if (this.previewLoaded && this.lastRenderedValue === this.inputTarget.value) return

    this.previewTarget.innerHTML = this.renderMarkdown(this.inputTarget.value)
    this.lastRenderedValue = this.inputTarget.value
    this.previewLoaded = true
  }

  loadModalPreview() {
    if (!this.hasModalPreviewTarget) return
    if (this.modalPreviewLoaded && this.lastModalRenderedValue === this.modalInputTarget.value) return

    this.modalPreviewTarget.innerHTML = this.renderMarkdown(this.modalInputTarget.value)
    this.lastModalRenderedValue = this.modalInputTarget.value
    this.modalPreviewLoaded = true
  }

  openFullscreen() {
    if (!this.hasFullscreenModalTarget || !this.hasModalInputTarget) return

    this.modalInputTarget.value = this.inputTarget.value
    this.syncInputsFrom(this.modalInputTarget)
    this.fullscreenModalTarget.classList.remove("hidden", "pointer-events-none", "opacity-0")
    this.fullscreenModalTarget.classList.add("opacity-100")
    this.modalPreviewLoaded = false
    this.loadModalPreview()
    this.modalInputTarget.focus()
  }

  closeFullscreen() {
    if (!this.hasFullscreenModalTarget) return

    this.syncInputsFrom(this.modalInputTarget)
    this.fullscreenModalTarget.classList.add("hidden", "pointer-events-none", "opacity-0")
    this.fullscreenModalTarget.classList.remove("opacity-100")
  }

  setActiveTab(element, active) {
    element.classList.toggle("bg-primary-500", active)
    element.classList.toggle("text-white", active)
    element.classList.toggle("shadow-sm", active)
    element.classList.toggle("text-black/60", !active)
    element.classList.toggle("hover:bg-stone-200", !active)
  }

  wrapSelection(start, end, selectedText, prefix, suffix) {
    const input = this.activeInput
    const content = selectedText || ""
    const replacement = `${prefix}${content}${suffix}`
    this.applyReplacement(input, start, end, replacement, prefix.length, prefix.length + content.length)
  }

  prefixLines(start, end, selectedText, prefix) {
    if (selectedText) {
      const replacement = selectedText
        .split("\n")
        .map((line) => `${prefix}${line}`)
        .join("\n")

      this.applyReplacement(this.activeInput, start, end, replacement, 0, replacement.length)
      return
    }

    const input = this.activeInput
    const lineStart = input.value.lastIndexOf("\n", Math.max(0, start - 1)) + 1
    this.applyReplacement(input, lineStart, lineStart, prefix, prefix.length, prefix.length)
  }

  replaceSelection(start, end, replacement) {
    this.applyReplacement(this.activeInput, start, end, replacement, 0, replacement.length)
  }

  insertLink(start, end, selectedText) {
    if (selectedText) {
      const replacement = `[${selectedText}]()`
      this.applyReplacement(this.activeInput, start, end, replacement, replacement.length - 1, replacement.length - 1)
      return
    }

    const replacement = "[]()"
    this.applyReplacement(this.activeInput, start, end, replacement, 1, 1)
  }

  applyReplacement(input, start, end, replacement, selectionStartOffset, selectionEndOffset) {
    input.setRangeText(replacement, start, end, "end")
    input.selectionStart = start + selectionStartOffset
    input.selectionEnd = start + selectionEndOffset
    input.dispatchEvent(new Event("input", { bubbles: true }))
  }

  isPasteableUrl(value) {
    if (!value || /\s/.test(value)) return false

    try {
      const url = new URL(value)
      return ["http:", "https:"].includes(url.protocol)
    } catch {
      return false
    }
  }

  renderMarkdown(value) {
    const source = value.trim()
    return source === ""
      ? '<p class="text-sm text-black/45">Chưa có nội dung để xem trước.</p>'
      : DOMPurify.sanitize(marked.parse(value))
  }

  syncInputsFrom(sourceInput) {
    if (!sourceInput) return

    const value = sourceInput.value
    if (this.hasInputTarget && sourceInput !== this.inputTarget) this.inputTarget.value = value
    if (this.hasModalInputTarget && sourceInput !== this.modalInputTarget) this.modalInputTarget.value = value
  }

  isFullscreenOpen() {
    return this.hasFullscreenModalTarget && !this.fullscreenModalTarget.classList.contains("hidden")
  }

  get activeInput() {
    return this.isFullscreenOpen() && this.hasModalInputTarget ? this.modalInputTarget : this.inputTarget
  }
}
