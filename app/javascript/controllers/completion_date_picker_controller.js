import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "valueInput",
    "display",
    "dayEnabledInput",
    "timeEnabledInput",
    "hourInput",
    "minuteInput",
    "dayToggle",
    "timeToggle",
    "dateSection",
    "timeSection",
    "pickerInput",
    "hourSelect",
    "minuteSelect",
    "calendarPanel",
    "calendarMonthLabel",
    "calendarDays",
    "calendarTriggerLabel"
  ]

  connect() {
    this.visibleMonth = null
    this.syncDisplay()
  }

  prepareOpen() {
    this.dayToggleTarget.checked = this.dayEnabled
    this.timeToggleTarget.checked = this.timeEnabled
    this.ensurePickerDate()
    this.hourSelectTarget.value = this.hourInputTarget.value || "09"
    this.minuteSelectTarget.value = this.minuteInputTarget.value || "00"
    this.syncVisibility()
    this.setVisibleMonthFromValue()
    this.renderCalendar()
    this.syncDisplay()
    this.closeCalendar()
  }

  toggleDay() {
    if (!this.dayToggleTarget.checked) {
      this.timeToggleTarget.checked = false
      this.closeCalendar()
    } else {
      this.ensurePickerDate()
      this.setVisibleMonthFromValue()
      this.renderCalendar()
    }

    this.syncVisibility()
    this.syncDisplay()
  }

  toggleTime() {
    if (this.timeToggleTarget.checked) {
      this.dayToggleTarget.checked = true

      this.ensurePickerDate()
      if (!this.hourSelectTarget.value) this.hourSelectTarget.value = this.hourInputTarget.value || "09"
      if (!this.minuteSelectTarget.value) this.minuteSelectTarget.value = this.minuteInputTarget.value || "00"
      this.setVisibleMonthFromValue()
      this.renderCalendar()
    }

    this.syncVisibility()
    this.syncDisplay()
  }

  toggleCalendar(event) {
    event.preventDefault()
    event.stopPropagation()
    if (!this.dayToggleTarget.checked) return

    this.ensurePickerDate()
    this.calendarPanelTarget.classList.toggle("hidden")
    this.setVisibleMonthFromValue()
    this.renderCalendar()
    this.syncDisplay()
  }

  keepOpen(event) {
    event.stopPropagation()
  }

  closeCalendar() {
    if (!this.hasCalendarPanelTarget) return

    this.calendarPanelTarget.classList.add("hidden")
  }

  closeCalendarOnOutside(event) {
    if (!this.hasCalendarPanelTarget || this.calendarPanelTarget.classList.contains("hidden")) return
    if (this.dateSectionTarget.contains(event.target)) return

    this.closeCalendar()
  }

  showPreviousMonth(event) {
    event.preventDefault()
    event.stopPropagation()
    this.visibleMonth = new Date(this.visibleMonth.getFullYear(), this.visibleMonth.getMonth() - 1, 1)
    this.renderCalendar()
  }

  showNextMonth(event) {
    event.preventDefault()
    event.stopPropagation()
    this.visibleMonth = new Date(this.visibleMonth.getFullYear(), this.visibleMonth.getMonth() + 1, 1)
    this.renderCalendar()
  }

  pickDate(event) {
    event.preventDefault()
    event.stopPropagation()
    const value = event.currentTarget.dataset.value
    if (!value) return

    this.pickerInputTarget.value = value
    this.setVisibleMonthFromValue()
    this.renderCalendar()
    this.syncDisplay()
    this.closeCalendar()
  }

  apply() {
    const dayEnabled = this.dayToggleTarget.checked
    const timeEnabled = dayEnabled && this.timeToggleTarget.checked

    this.dayEnabledInputTarget.value = dayEnabled ? "1" : "0"
    this.timeEnabledInputTarget.value = timeEnabled ? "1" : "0"

    if (!dayEnabled) {
      this.valueInputTarget.value = ""
      this.hourInputTarget.value = ""
      this.minuteInputTarget.value = ""
      this.syncDisplay()
      return
    }

    this.valueInputTarget.value = this.pickerInputTarget.value || this.today()
    this.hourInputTarget.value = timeEnabled ? this.hourSelectTarget.value : ""
    this.minuteInputTarget.value = timeEnabled ? this.minuteSelectTarget.value : ""
    this.syncDisplay()
  }

  syncVisibility() {
    const dayEnabled = this.dayToggleTarget.checked
    const timeEnabled = dayEnabled && this.timeToggleTarget.checked

    this.dateSectionTarget.classList.toggle("hidden", !dayEnabled)
    this.timeSectionTarget.classList.toggle("hidden", !timeEnabled)
  }

  syncDisplay() {
    this.displayTarget.textContent = this.displayValue() || "Chọn ngày hoàn thành"

    if (this.hasCalendarTriggerLabelTarget) {
      this.calendarTriggerLabelTarget.textContent = this.formattedDate(this.pickerInputTarget.value || this.valueInputTarget.value) || "Chọn ngày"
    }
  }

  renderCalendar() {
    if (!this.hasCalendarDaysTarget || !this.hasCalendarMonthLabelTarget) return

    const selectedValue = this.pickerInputTarget.value || this.today()
    const selectedDate = this.parseDate(selectedValue)
    const month = this.visibleMonth || new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1)
    const year = month.getFullYear()
    const monthIndex = month.getMonth()

    this.calendarMonthLabelTarget.textContent = new Intl.DateTimeFormat("vi-VN", {
      month: "long",
      year: "numeric"
    }).format(month)

    const firstDay = new Date(year, monthIndex, 1)
    const startingOffset = (firstDay.getDay() + 6) % 7
    const startDate = new Date(year, monthIndex, 1 - startingOffset)
    const todayValue = this.today()

    this.calendarDaysTarget.innerHTML = ""

    for (let index = 0; index < 42; index += 1) {
      const currentDate = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate() + index)
      const currentValue = this.formatIsoDate(currentDate)
      const inCurrentMonth = currentDate.getMonth() === monthIndex
      const isSelected = currentValue === selectedValue
      const isToday = currentValue === todayValue

      const button = document.createElement("button")
      button.type = "button"
      button.dataset.action = "click->completion-date-picker#pickDate"
      button.dataset.value = currentValue
      button.className = [
        "inline-flex h-9 items-center justify-center rounded-xl text-sm font-semibold transition",
        inCurrentMonth ? "text-black hover:bg-stone-100" : "text-black/30 hover:bg-stone-50",
        isSelected ? "bg-primary-500 text-white hover:bg-primary-500" : null,
        isToday && !isSelected ? "ring-1 ring-primary-200" : null
      ].filter(Boolean).join(" ")
      button.textContent = String(currentDate.getDate())
      this.calendarDaysTarget.appendChild(button)
    }
  }

  displayValue() {
    if (!this.dayEnabled || !this.valueInputTarget.value) return null

    const date = this.formattedDate(this.valueInputTarget.value)
    return this.timeEnabled && this.hourInputTarget.value && this.minuteInputTarget.value
      ? `${date} - ${this.hourInputTarget.value}:${this.minuteInputTarget.value}`
      : date
  }

  setVisibleMonthFromValue() {
    const baseDate = this.parseDate(this.pickerInputTarget.value || this.valueInputTarget.value || this.today())
    this.visibleMonth = new Date(baseDate.getFullYear(), baseDate.getMonth(), 1)
  }

  ensurePickerDate() {
    if (!this.pickerInputTarget.value) {
      this.pickerInputTarget.value = this.valueInputTarget.value || this.today()
    }
  }

  parseDate(value) {
    const [year, month, day] = value.split("-").map(Number)
    return new Date(year, month - 1, day)
  }

  formattedDate(value) {
    if (!value) return null

    return new Intl.DateTimeFormat("vi-VN", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric"
    }).format(this.parseDate(value))
  }

  formatIsoDate(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, "0")
    const day = String(date.getDate()).padStart(2, "0")

    return `${year}-${month}-${day}`
  }

  today() {
    return this.formatIsoDate(new Date())
  }

  get dayEnabled() {
    return this.dayEnabledInputTarget.value !== "0"
  }

  get timeEnabled() {
    return this.timeEnabledInputTarget.value === "1"
  }
}
