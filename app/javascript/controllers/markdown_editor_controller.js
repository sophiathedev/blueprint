import { Controller } from "@hotwired/stimulus"
import DOMPurify from "dompurify"
import hljs from "highlight.js"
import { marked } from "marked"

export default class extends Controller {
  static IMAGE_BATCH_SIZE = 10
  static IMAGE_SCROLL_THRESHOLD = 160
  static MODAL_PREVIEW_DEBOUNCE_MS = 200

  static values = {
    attachmentUploadUrl: String,
    imagesUrl: String,
    uploadUrl: String
  }

  static targets = [
    "editPanel",
    "previewPanel",
    "editTab",
    "previewTab",
    "previewAction",
    "previewActionButton",
    "input",
    "preview",
    "uploadStatus",
    "imageLibraryModal",
    "imageLibraryGrid",
    "imageLibraryEmpty",
    "imageLibraryPaginationStatus",
    "imageLibraryScroller",
    "attachmentUploadInput",
    "attachmentLoadingFilename",
    "attachmentLoadingModal",
    "attachmentLoadingPercent",
    "attachmentLoadingProgressRing",
    "attachmentLoadingTransferred",
    "imageUploadInput",
    "fullscreenModal",
    "modalInput",
    "modalPreview"
  ]

  connect() {
    this.imageLibrary = []
    this.imageLibraryHasMore = true
    this.imageLibraryLoaded = false
    this.imageLibraryOffset = 0
    this.imageLibraryRequestInFlight = false
    this.imageSkeletonCounter = 0
    this.previewLoaded = false
    this.modalPreviewLoaded = false
    marked.setOptions({
      breaks: true,
      gfm: true
    })
    this.showEdit()
  }

  disconnect() {
    clearTimeout(this.uploadStatusTimeout)
    clearTimeout(this.modalPreviewTimeout)
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
      clearTimeout(this.modalPreviewTimeout)
      this.modalPreviewTimeout = window.setTimeout(() => {
        this.loadModalPreview()
      }, this.constructor.MODAL_PREVIEW_DEBOUNCE_MS)
    }
  }

  async handlePaste(event) {
    const input = event.currentTarget
    const imageFiles = this.imageFilesFrom(event)

    if (imageFiles.length > 0) {
      event.preventDefault()
      this.rememberInsertionPoint(input)
      await this.uploadPastedImages(input, imageFiles)
      return
    }

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
      strikethrough: () => this.wrapSelection(start, end, selectedText, "~~", "~~"),
      list: () => this.prefixLines(start, end, selectedText, "- "),
      orderedList: () => this.insertOrderedList(start, end, selectedText),
      taskList: () => this.insertTaskList(start, end, selectedText),
      quote: () => this.prefixLines(start, end, selectedText, "> "),
      link: () => this.insertLink(start, end, selectedText),
      code: () => this.wrapSelection(start, end, selectedText, "`", "`"),
      codeBlock: () => this.insertCodeBlock(start, end, selectedText),
      table: () => this.insertTable(start, end, selectedText),
      divider: () => this.insertDivider(start, end)
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

    clearTimeout(this.modalPreviewTimeout)
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

    clearTimeout(this.modalPreviewTimeout)
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

  insertOrderedList(start, end, selectedText) {
    if (selectedText) {
      const replacement = selectedText
        .split("\n")
        .map((line, index) => `${index + 1}. ${line}`)
        .join("\n")

      this.applyReplacement(this.activeInput, start, end, replacement, 0, replacement.length)
      return
    }

    this.applyReplacement(this.activeInput, start, end, "1. ", 3, 3)
  }

  insertTaskList(start, end, selectedText) {
    if (selectedText) {
      const replacement = selectedText
        .split("\n")
        .map((line) => `- [ ] ${line}`)
        .join("\n")

      this.applyReplacement(this.activeInput, start, end, replacement, 0, replacement.length)
      return
    }

    this.applyReplacement(this.activeInput, start, end, "- [ ] ", 6, 6)
  }

  insertCodeBlock(start, end, selectedText) {
    const content = selectedText || ""
    const replacement = content ? `\`\`\`\n${content}\n\`\`\`` : "```\n\n```"
    const selectionStart = content ? 4 : 4
    const selectionEnd = content ? replacement.length - 4 : 4

    this.applyReplacement(this.activeInput, start, end, replacement, selectionStart, selectionEnd)
  }

  insertTable(start, end, selectedText) {
    const replacement = selectedText && selectedText.trim().length > 0
      ? `| Cột 1 | Cột 2 |\n| --- | --- |\n| ${selectedText.replaceAll("\n", " | ")} |  |`
      : "| Cột 1 | Cột 2 |\n| --- | --- |\n| Nội dung | Nội dung |"

    this.applyReplacement(this.activeInput, start, end, replacement, 2, 7)
  }

  insertDivider(start, end) {
    const replacement = "\n---\n"
    this.applyReplacement(this.activeInput, start, end, replacement, replacement.length, replacement.length)
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
    if (source === "") {
      return '<p class="text-sm text-black/45">Chưa có nội dung để xem trước.</p>'
    }

    const container = document.createElement("div")
    container.innerHTML = marked.parse(value)

    container.querySelectorAll("pre code").forEach((block) => {
      const sourceCode = block.textContent || ""
      const languageClass = Array.from(block.classList).find((className) => className.startsWith("language-"))
      const language = languageClass?.replace("language-", "")
      const highlighted = language && hljs.getLanguage(language)
        ? hljs.highlight(sourceCode, { language }).value
        : hljs.highlightAuto(sourceCode).value

      block.innerHTML = highlighted
      block.classList.add("hljs")
      if (language) block.dataset.language = language
    })

    return DOMPurify.sanitize(container.innerHTML, {
      ADD_ATTR: ["class", "data-language"]
    })
  }

  syncInputsFrom(sourceInput) {
    if (!sourceInput) return

    const value = sourceInput.value
    if (this.hasInputTarget && sourceInput !== this.inputTarget) this.inputTarget.value = value
    if (this.hasModalInputTarget && sourceInput !== this.modalInputTarget) this.modalInputTarget.value = value
  }

  openImageLibrary() {
    if (!this.hasImageLibraryModalTarget) return

    this.rememberInsertionPoint()
    this.imageLibraryModalTarget.classList.remove("hidden", "pointer-events-none", "opacity-0")
    this.imageLibraryModalTarget.classList.add("opacity-100")
    this.loadImageLibrary()
  }

  closeImageLibrary() {
    if (!this.hasImageLibraryModalTarget) return

    this.imageLibraryModalTarget.classList.add("hidden", "pointer-events-none", "opacity-0")
    this.imageLibraryModalTarget.classList.remove("opacity-100")

    if (this.hasImageUploadInputTarget) {
      this.imageUploadInputTarget.value = ""
    }
  }

  closeImageLibraryOnBackdrop(event) {
    if (event.target !== this.imageLibraryModalTarget) return

    this.closeImageLibrary()
  }

  keepImageLibraryOpen(event) {
    event.stopPropagation()
  }

  refreshImageLibrary() {
    this.resetImageLibrary()
    this.loadImageLibrary({ force: true })
  }

  openAttachmentPicker() {
    if (!this.hasAttachmentUploadInputTarget) return

    this.rememberInsertionPoint()
    this.attachmentUploadInputTarget.click()
  }

  async uploadAttachmentsFromPicker(event) {
    const files = Array.from(event.target.files || [])
    if (files.length === 0) return

    this.rememberInsertionPoint()
    this.showAttachmentLoadingModal(files)
    this.showUploadStatus(files.length > 1 ? `Đang tải ${files.length} attachment...` : "Đang tải attachment...")

    try {
      for (const file of files) {
        const attachment = await this.uploadAttachment(file, {
          onProgress: (progress) => this.updateAttachmentLoadingProgress(progress)
        })
        this.insertAttachmentAtCursor(attachment.url, attachment.filename)
      }

      this.showUploadStatus("Đã chèn attachment vào markdown.")
    } catch (error) {
      this.showUploadStatus(error.message || "Upload attachment thất bại.", true)
    } finally {
      this.hideAttachmentLoadingModal()
      event.target.value = ""
    }
  }

  openImagePicker() {
    if (!this.hasImageUploadInputTarget) return

    this.rememberInsertionPoint()
    this.imageUploadInputTarget.click()
  }

  async uploadImagesFromPicker(event) {
    const files = Array.from(event.target.files || []).filter((file) => file.type.startsWith("image/"))
    if (files.length === 0) return

    this.rememberInsertionPoint()
    this.showUploadStatus(files.length > 1 ? `Đang tải ${files.length} ảnh...` : "Đang tải ảnh...")

    try {
      for (const file of files) {
        const placeholderId = this.insertUploadingImageCard(file)

        try {
          const image = await this.uploadImage(file)
          this.replaceUploadingImageCard(placeholderId, image)
          this.addUploadedImageToLibrary(image)
          this.insertImageAtCursor(image.url, image.filename)
        } catch (error) {
          this.removeUploadingImageCard(placeholderId)
          throw error
        }
      }

      this.closeImageLibrary()
      this.showUploadStatus("Đã chèn ảnh vào markdown.")
    } catch (error) {
      this.showUploadStatus(error.message || "Upload ảnh thất bại.", true)
    } finally {
      event.target.value = ""
    }
  }

  async loadImageLibrary({ force = false } = {}) {
    if (!this.hasImagesUrlValue || !this.hasImageLibraryGridTarget) return
    if (this.imageLibraryRequestInFlight) return
    if (!this.imageLibraryHasMore && !force) return

    if (force) this.resetImageLibrary()

    const append = this.imageLibraryOffset > 0
    this.imageLibraryRequestInFlight = true
    this.updateImageLibraryLoading(true, append)
    this.appendImageSkeletons(this.constructor.IMAGE_BATCH_SIZE)

    try {
      const url = new URL(this.imagesUrlValue, window.location.origin)
      url.searchParams.set("limit", this.constructor.IMAGE_BATCH_SIZE)
      url.searchParams.set("offset", this.imageLibraryOffset)

      const paginatedResponse = await fetch(url.toString(), {
        credentials: "same-origin",
        headers: {
          Accept: "application/json"
        }
      })

      const payload = await paginatedResponse.json().catch(() => ({}))

      if (!paginatedResponse.ok) {
        throw new Error(payload.error || "Không thể tải thư viện ảnh.")
      }

      const images = payload.images || []
      this.removeImageSkeletons()
      this.imageLibrary = force ? images : [...this.imageLibrary, ...images]
      this.imageLibraryOffset = payload.next_offset ?? (this.imageLibraryOffset + images.length)
      this.imageLibraryHasMore = Boolean(payload.has_more)
      this.imageLibraryLoaded = true
      this.renderImageLibrary({ append, images })
    } catch (error) {
      this.removeImageSkeletons()

      if (this.imageLibrary.length === 0) {
        this.imageLibraryLoaded = false
        this.renderImageLibrary({ errorMessage: error.message || "Không thể tải thư viện ảnh." })
      } else {
        this.showUploadStatus(error.message || "Không thể tải thư viện ảnh.", true)
      }
    } finally {
      this.imageLibraryRequestInFlight = false
      this.updateImageLibraryLoading(false)
    }
  }

  renderImageLibrary({ append = false, images = this.imageLibrary, errorMessage = null } = {}) {
    if (!this.hasImageLibraryGridTarget || !this.hasImageLibraryEmptyTarget) return

    const currentImages = this.imageLibrary || []

    if (currentImages.length === 0) {
      this.imageLibraryGridTarget.innerHTML = ""
      this.imageLibraryEmptyTarget.textContent = errorMessage || "Chưa có ảnh nào trong thư viện. Hãy upload ảnh đầu tiên để dùng lại về sau."
      this.imageLibraryEmptyTarget.classList.remove("hidden")
      return
    }

    this.imageLibraryEmptyTarget.classList.add("hidden")

    if (!append) {
      this.imageLibraryGridTarget.innerHTML = images.map((image) => this.imageCardMarkup(image)).join("")
      return
    }

    this.imageLibraryGridTarget.insertAdjacentHTML("beforeend", images.map((image) => this.imageCardMarkup(image)).join(""))
  }

  imageCardMarkup(image) {
    const filename = this.escapeHtml(image.filename || "image")
    const imageUrl = this.escapeHtmlAttribute(image.url || "")
    const createdAt = image.created_at ? new Date(image.created_at).toLocaleString("vi-VN") : ""
    const meta = [this.formatFileSize(image.byte_size), createdAt].filter(Boolean).join(" • ")

    return `
      <button
        type="button"
        class="group overflow-hidden rounded-[24px] border border-black/10 bg-stone-50 text-left transition hover:-translate-y-0.5 hover:border-primary-400 hover:bg-primary-50"
        data-action="click->markdown-editor#selectImageFromLibrary"
        data-markdown-editor-image-url="${imageUrl}"
        data-markdown-editor-image-filename="${this.escapeHtmlAttribute(image.filename || "image")}"
      >
        <div class="relative aspect-[4/3] overflow-hidden bg-white">
          <div class="absolute inset-0 animate-pulse bg-stone-200" data-markdown-editor-image-skeleton></div>
          <img src="${imageUrl}" alt="${filename}" class="h-full w-full object-cover opacity-0 transition duration-200 group-hover:scale-[1.02]" loading="lazy" data-action="load->markdown-editor#handleLibraryImageLoaded error->markdown-editor#handleLibraryImageLoaded">
        </div>
        <div class="space-y-1 px-4 py-3">
          <p class="truncate text-sm font-semibold text-black">${filename}</p>
          <p class="text-xs text-black/50">${this.escapeHtml(meta)}</p>
        </div>
      </button>
    `
  }

  selectImageFromLibrary(event) {
    const { markdownEditorImageUrl: url, markdownEditorImageFilename: filename } = event.currentTarget.dataset
    if (!url) return

    this.insertImageAtCursor(url, filename)
    this.closeImageLibrary()
    this.showUploadStatus("Đã chèn ảnh vào markdown.")
  }

  insertImageAtCursor(url, filename) {
    const { input, start, end } = this.currentInsertionPoint()
    const markup = this.buildImageMarkup(url, filename)

    this.applyReplacement(input, start, end, markup, markup.length, markup.length)
    this.rememberInsertionPoint(input)
    input.focus()
  }

  insertAttachmentAtCursor(url, filename) {
    const { input, start, end } = this.currentInsertionPoint()
    const markup = this.buildAttachmentMarkup(url, filename)

    this.applyReplacement(input, start, end, markup, markup.length, markup.length)
    this.rememberInsertionPoint(input)
    input.focus()
  }

  imageFilesFrom(event) {
    const clipboardItems = Array.from(event.clipboardData?.items || [])

    return clipboardItems
      .filter((item) => item.kind === "file" && item.type.startsWith("image/"))
      .map((item) => item.getAsFile())
      .filter(Boolean)
  }

  async uploadPastedImages(input, files) {
    if (!this.hasUploadUrlValue) {
      this.showUploadStatus("Chưa cấu hình đường dẫn upload ảnh.", true)
      return
    }

    this.showUploadStatus(files.length > 1 ? `Đang tải ${files.length} ảnh...` : "Đang tải ảnh...")

    let insertionStart = input.selectionStart ?? input.value.length
    let insertionEnd = input.selectionEnd ?? input.value.length

    try {
      for (const file of files) {
        const { url, filename } = await this.uploadImage(file)
        const markdown = this.buildImageMarkup(url, filename)

        this.applyReplacement(input, insertionStart, insertionEnd, markdown, markdown.length, markdown.length)
        insertionStart = input.selectionStart ?? (insertionStart + markdown.length)
        insertionEnd = insertionStart
      }

      this.showUploadStatus("Đã chèn ảnh vào markdown.")
    } catch (error) {
      this.showUploadStatus(error.message || "Upload ảnh thất bại.", true)
    }
  }

  async uploadImage(file) {
    const formData = new FormData()
    formData.append("image", file, file.name || this.defaultFilename(file.type))

    const response = await fetch(this.uploadUrlValue, {
      method: "POST",
      body: formData,
      headers: this.csrfHeaders,
      credentials: "same-origin"
    })

    const payload = await response.json().catch(() => ({}))

    if (!response.ok) {
      throw new Error(payload.error || "Upload ảnh thất bại.")
    }

    if (!payload.url) {
      throw new Error("Không nhận được đường dẫn ảnh sau khi upload.")
    }

    return payload
  }

  async uploadAttachment(file, { onProgress } = {}) {
    if (!this.hasAttachmentUploadUrlValue) {
      throw new Error("Chưa cấu hình đường dẫn upload attachment.")
    }

    const startedAt = performance.now()

    return await new Promise((resolve, reject) => {
      const formData = new FormData()
      formData.append("attachment", file, file.name || "attachment")

      const xhr = new XMLHttpRequest()
      xhr.open("POST", this.attachmentUploadUrlValue, true)
      xhr.responseType = "json"
      Object.entries(this.csrfHeaders).forEach(([key, value]) => xhr.setRequestHeader(key, value))

      xhr.upload.onprogress = (event) => {
        if (!event.lengthComputable) return

        const elapsedSeconds = Math.max((performance.now() - startedAt) / 1000, 0.001)
        const speedBytesPerSecond = event.loaded / elapsedSeconds

        onProgress?.({
          loaded: event.loaded,
          total: event.total,
          percent: Math.min(Math.round((event.loaded / event.total) * 100), 100),
          speedBytesPerSecond
        })
      }

      xhr.onerror = () => reject(new Error("Upload attachment thất bại."))
      xhr.onabort = () => reject(new Error("Upload attachment đã bị hủy."))
      xhr.onload = () => {
        const payload = xhr.response || this.parseJsonSafe(xhr.responseText)

        if (xhr.status < 200 || xhr.status >= 300) {
          reject(new Error(payload?.error || "Upload attachment thất bại."))
          return
        }

        if (!payload?.url) {
          reject(new Error("Không nhận được đường dẫn attachment sau khi upload."))
          return
        }

        onProgress?.({
          loaded: file.size,
          total: file.size,
          percent: 100,
          speedBytesPerSecond: file.size / Math.max((performance.now() - startedAt) / 1000, 0.001)
        })

        resolve(payload)
      }

      xhr.send(formData)
    })
  }

  buildImageMarkup(url, filename) {
    const alt = this.escapeHtmlAttribute((filename || "image").replace(/\.[a-z0-9]+$/i, ""))
    const imageUrl = this.escapeHtmlAttribute(url)
    return `<img src="${imageUrl}" alt="${alt}">`
  }

  buildAttachmentMarkup(url, filename) {
    const label = this.escapeMarkdownLinkLabel(filename || "attachment")
    const attachmentUrl = this.escapeMarkdownLinkUrl(url)
    return `[${label}](${attachmentUrl})`
  }

  defaultFilename(contentType) {
    const extension = contentType?.split("/")[1] || "png"
    return `pasted-image.${extension}`
  }

  showUploadStatus(message, isError = false) {
    if (!this.hasUploadStatusTarget) return

    this.uploadStatusTarget.textContent = message
    this.uploadStatusTarget.classList.remove("hidden", "text-primary-700", "text-rose-600")
    this.uploadStatusTarget.classList.add(isError ? "text-rose-600" : "text-primary-700")

    clearTimeout(this.uploadStatusTimeout)
    this.uploadStatusTimeout = window.setTimeout(() => {
      if (!this.hasUploadStatusTarget) return

      this.uploadStatusTarget.textContent = ""
      this.uploadStatusTarget.classList.add("hidden")
      this.uploadStatusTarget.classList.remove("text-primary-700", "text-rose-600")
    }, isError ? 5000 : 2500)
  }

  showAttachmentLoadingModal(files) {
    if (!this.hasAttachmentLoadingModalTarget) return

    const fileNames = files.map((file) => file.name).filter(Boolean)
    const label = fileNames.length > 1
      ? `${fileNames.length} files đang được upload...`
      : (fileNames[0] || "Hệ thống đang upload file, vui lòng chờ một chút.")

    if (this.hasAttachmentLoadingFilenameTarget) {
      this.attachmentLoadingFilenameTarget.textContent = label
    }

    this.updateAttachmentLoadingProgress({
      loaded: 0,
      total: files[0]?.size || 0,
      percent: 0,
      speedBytesPerSecond: 0
    })

    this.attachmentLoadingModalTarget.classList.remove("hidden", "pointer-events-none", "opacity-0")
    this.attachmentLoadingModalTarget.classList.add("opacity-100")
  }

  hideAttachmentLoadingModal() {
    if (!this.hasAttachmentLoadingModalTarget) return

    this.attachmentLoadingModalTarget.classList.add("hidden", "pointer-events-none", "opacity-0")
    this.attachmentLoadingModalTarget.classList.remove("opacity-100")
  }

  updateAttachmentLoadingProgress({ loaded = 0, total = 0, percent = 0, speedBytesPerSecond = 0 }) {
    const safePercent = Math.max(0, Math.min(100, percent))

    if (this.hasAttachmentLoadingPercentTarget) {
      this.attachmentLoadingPercentTarget.textContent = `${safePercent}%`
    }

    if (this.hasAttachmentLoadingTransferredTarget) {
      this.attachmentLoadingTransferredTarget.textContent =
        `${this.formatFileSize(loaded)} / ${this.formatFileSize(total)} (${this.formatTransferSpeed(speedBytesPerSecond)})`
    }

    if (this.hasAttachmentLoadingProgressRingTarget) {
      const accent = safePercent * 3.6
      this.attachmentLoadingProgressRingTarget.style.background =
        `conic-gradient(rgb(14 165 233) 0deg, rgb(14 165 233) ${accent}deg, rgb(224 242 254) ${accent}deg, rgb(224 242 254) 360deg)`
    }
  }

  get csrfHeaders() {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    return token ? { "X-CSRF-Token": token } : {}
  }

  updateImageLibraryLoading(loading, pagination = false) {
    if (this.hasImageLibraryPaginationStatusTarget) {
      this.imageLibraryPaginationStatusTarget.classList.toggle("hidden", !loading || !pagination)
    }
  }

  handleImageLibraryScroll() {
    if (!this.hasImageLibraryScrollerTarget || this.imageLibraryRequestInFlight || !this.imageLibraryHasMore) return

    const { scrollTop, scrollHeight, clientHeight } = this.imageLibraryScrollerTarget
    const distanceToBottom = scrollHeight - scrollTop - clientHeight

    if (distanceToBottom <= this.constructor.IMAGE_SCROLL_THRESHOLD) {
      this.loadImageLibrary()
    }
  }

  handleLibraryImageLoaded(event) {
    const image = event.currentTarget
    image.classList.remove("opacity-0")
    image.classList.add("opacity-100")
    image.parentElement?.querySelector("[data-markdown-editor-image-skeleton]")?.remove()
  }

  appendImageSkeletons(count) {
    if (!this.hasImageLibraryGridTarget || count <= 0) return

    const skeletons = Array.from({ length: count }, () => this.imageSkeletonMarkup()).join("")
    this.imageLibraryGridTarget.insertAdjacentHTML("beforeend", skeletons)
  }

  removeImageSkeletons() {
    this.imageLibraryGridTarget?.querySelectorAll("[data-markdown-editor-gallery-skeleton]").forEach((node) => node.remove())
  }

  insertUploadingImageCard(file) {
    if (!this.hasImageLibraryGridTarget) return null

    const placeholderId = `uploading-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`
    this.imageLibraryEmptyTarget?.classList.add("hidden")
    this.imageLibraryGridTarget.insertAdjacentHTML("afterbegin", this.uploadingImageCardMarkup(placeholderId, file))
    return placeholderId
  }

  replaceUploadingImageCard(placeholderId, image) {
    if (!placeholderId || !this.hasImageLibraryGridTarget) return

    const placeholder = this.imageLibraryGridTarget.querySelector(`[data-markdown-editor-uploading-card="${placeholderId}"]`)
    if (!placeholder) return

    placeholder.outerHTML = this.imageCardMarkup(image)
  }

  removeUploadingImageCard(placeholderId) {
    if (!placeholderId || !this.hasImageLibraryGridTarget) return

    this.imageLibraryGridTarget.querySelector(`[data-markdown-editor-uploading-card="${placeholderId}"]`)?.remove()
  }

  addUploadedImageToLibrary(image) {
    if (!image?.id) return

    this.imageLibrary = [image, ...this.imageLibrary.filter((item) => item.id !== image.id)]

    if (this.imageLibraryLoaded) {
      this.imageLibraryOffset += 1
    }
  }

  uploadingImageCardMarkup(placeholderId, file) {
    const filename = this.escapeHtml(file?.name || "Đang tải ảnh")

    return `
      <div
        class="overflow-hidden rounded-[24px] border border-primary-200 bg-[linear-gradient(180deg,rgba(255,255,255,0.98),rgba(239,246,255,0.96))] shadow-[0_14px_30px_rgba(59,130,246,0.10)]"
        data-markdown-editor-uploading-card="${placeholderId}"
      >
        <div class="relative aspect-[4/3] overflow-hidden bg-primary-50">
          <div class="absolute inset-0 bg-[linear-gradient(120deg,rgba(255,255,255,0)_10%,rgba(255,255,255,0.85)_30%,rgba(255,255,255,0)_52%)] animate-[gallery-skeleton-shimmer_1.25s_ease-in-out_infinite]"></div>
          <div class="absolute inset-x-6 top-6 flex items-center justify-between">
            <div class="h-9 w-9 rounded-2xl bg-white/75 shadow-sm"></div>
            <div class="flex gap-1.5">
              <div class="h-2 w-2 rounded-full bg-primary-300 animate-bounce [animation-delay:-0.2s]"></div>
              <div class="h-2 w-2 rounded-full bg-primary-300 animate-bounce [animation-delay:-0.1s]"></div>
              <div class="h-2 w-2 rounded-full bg-primary-300 animate-bounce"></div>
            </div>
          </div>
          <div class="absolute inset-x-6 bottom-6 rounded-[20px] border border-white/60 bg-white/55 px-4 py-3 backdrop-blur-sm">
            <div class="h-3 w-24 rounded-full bg-primary-100"></div>
            <div class="mt-2 h-2.5 w-16 rounded-full bg-primary-50"></div>
          </div>
        </div>
        <div class="space-y-2 px-4 py-3">
          <p class="truncate text-sm font-semibold text-black">${filename}</p>
          <div class="flex items-center gap-2 text-xs font-medium text-primary-700">
            <span class="inline-flex h-2 w-2 rounded-full bg-primary-400 animate-pulse"></span>
            <span>Đang upload...</span>
          </div>
        </div>
      </div>
    `
  }

  imageSkeletonMarkup() {
    this.imageSkeletonCounter += 1

    return `
      <div class="relative overflow-hidden rounded-[24px] border border-primary-100/80 bg-[linear-gradient(180deg,rgba(255,255,255,0.98),rgba(239,246,255,0.96))] shadow-[0_14px_28px_rgba(56,189,248,0.10)]" data-markdown-editor-gallery-skeleton="${this.imageSkeletonCounter}">
        <div class="relative aspect-[4/3] overflow-hidden bg-primary-50/70">
          <div class="absolute inset-0 bg-[linear-gradient(180deg,rgba(224,242,254,0.92),rgba(186,230,253,0.78))]"></div>
          <div class="absolute left-5 top-5 h-[62%] w-[30%] rounded-[18px] bg-white/55"></div>
          <div class="absolute left-[39%] top-5 h-[34%] w-[23%] rounded-[18px] bg-primary-100/70"></div>
          <div class="absolute right-5 top-5 h-[52%] w-[30%] rounded-[18px] bg-white/48"></div>
          <div class="absolute left-[39%] bottom-5 h-[24%] w-[56%] rounded-[18px] bg-primary-100/60"></div>
          <div class="absolute inset-y-0 -left-[42%] w-[26%] animate-[gallery-skeleton-shimmer_1.55s_linear_infinite] bg-[linear-gradient(90deg,rgba(255,255,255,0),rgba(255,255,255,0.92),rgba(255,255,255,0))]"></div>
        </div>
        <div class="relative space-y-4 px-4 py-4">
          <div class="absolute inset-y-0 -left-[42%] w-[26%] animate-[gallery-skeleton-shimmer_1.55s_linear_infinite] bg-[linear-gradient(90deg,rgba(255,255,255,0),rgba(255,255,255,0.8),rgba(255,255,255,0))]"></div>
          <div class="relative flex items-start justify-between gap-3">
            <div class="space-y-2">
              <div class="h-4 w-32 rounded-full bg-primary-100"></div>
              <div class="h-3 w-24 rounded-full bg-sky-50"></div>
            </div>
            <div class="h-8 w-8 rounded-2xl bg-white/85 ring-1 ring-primary-100/80"></div>
          </div>
          <div class="relative flex items-center gap-2">
            <div class="h-2 w-2 rounded-full bg-primary-200"></div>
            <div class="h-3 w-16 rounded-full bg-sky-50"></div>
            <div class="h-2 w-2 rounded-full bg-primary-200"></div>
            <div class="h-3 w-12 rounded-full bg-sky-50"></div>
          </div>
          <div class="relative flex gap-2 pt-1">
            <div class="h-6 w-14 rounded-full bg-white/90 ring-1 ring-primary-100/70"></div>
            <div class="h-6 w-18 rounded-full bg-primary-50/80 ring-1 ring-primary-100/60"></div>
          </div>
        </div>
      </div>
    `
  }

  resetImageLibrary() {
    this.imageLibrary = []
    this.imageLibraryLoaded = false
    this.imageLibraryHasMore = true
    this.imageLibraryOffset = 0
    this.imageLibraryRequestInFlight = false
    this.imageSkeletonCounter = 0

    if (this.hasImageLibraryGridTarget) {
      this.imageLibraryGridTarget.innerHTML = ""
    }
  }

  rememberInsertionPoint(input = this.activeInput) {
    if (!input) return

    const context = this.hasModalInputTarget && input === this.modalInputTarget ? "modal" : "main"
    this.insertionPoint = {
      context,
      start: input.selectionStart ?? input.value.length,
      end: input.selectionEnd ?? input.value.length
    }
  }

  currentInsertionPoint() {
    const input = this.inputForInsertionPoint()

    return {
      input,
      start: this.insertionPoint?.start ?? input.value.length,
      end: this.insertionPoint?.end ?? input.value.length
    }
  }

  inputForInsertionPoint() {
    if (this.insertionPoint?.context === "modal" && this.hasModalInputTarget) {
      return this.modalInputTarget
    }

    return this.inputTarget
  }

  formatFileSize(byteSize) {
    if (!byteSize) return ""

    if (byteSize < 1024) return `${byteSize} B`
    if (byteSize < 1024 * 1024) return `${(byteSize / 1024).toFixed(1)} KB`
    return `${(byteSize / (1024 * 1024)).toFixed(1)} MB`
  }

  formatTransferSpeed(bytesPerSecond) {
    if (!bytesPerSecond) return "0 KB/s"

    if (bytesPerSecond < 1024 * 1024) {
      return `${(bytesPerSecond / 1024).toFixed(1)} KB/s`
    }

    return `${(bytesPerSecond / (1024 * 1024)).toFixed(2)} MB/s`
  }

  parseJsonSafe(value) {
    try {
      return JSON.parse(value)
    } catch {
      return null
    }
  }

  escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;")
  }

  escapeHtmlAttribute(value) {
    return this.escapeHtml(value)
  }

  escapeMarkdownLinkLabel(value) {
    return String(value).replaceAll("[", "\\[").replaceAll("]", "\\]")
  }

  escapeMarkdownLinkUrl(value) {
    return String(value).replaceAll(" ", "%20").replaceAll(")", "%29")
  }

  isFullscreenOpen() {
    return this.hasFullscreenModalTarget && !this.fullscreenModalTarget.classList.contains("hidden")
  }

  get activeInput() {
    return this.isFullscreenOpen() && this.hasModalInputTarget ? this.modalInputTarget : this.inputTarget
  }
}
