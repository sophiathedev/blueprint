import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "valueInput",
    "display",
    "dayEnabledInput",
    "timeEnabledInput",
    "hourInput",
    "minuteInput",
    "dateSection",
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
    this.closeAnimationTimeout = null
    this.dayEnabledInputTarget.value = "1"
    this.timeEnabledInputTarget.value = "1"
    this.pickerInputTarget.value = this.valueInputTarget.value || ""
    this.hourSelectTarget.value = this.hourInputTarget.value || this.currentHour()
    this.minuteSelectTarget.value = this.minuteInputTarget.value || this.currentMinute()
    this.setVisibleMonthFromValue()
    this.syncTimeOptions()
    this.renderCalendar()
    this.ensureValidCurrentSelection()
    this.apply()
    this.syncDisplay()
  }

  toggleCalendar(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.calendarPanelTarget.classList.contains("hidden")) {
      this.openCalendar()
    } else {
      this.closeCalendar()
    }
    this.setVisibleMonthFromValue()
    this.renderCalendar()
    this.syncDisplay()
  }

  keepOpen(event) {
    event.stopPropagation()
  }

  closeCalendar() {
    if (!this.hasCalendarPanelTarget) return
    if (this.calendarPanelTarget.classList.contains("hidden")) return

    clearTimeout(this.closeAnimationTimeout)
    this.calendarPanelTarget.classList.remove("is-open")
    this.closeAnimationTimeout = setTimeout(() => {
      this.calendarPanelTarget.classList.add("hidden")
    }, 180)
  }

  closeCalendarOnOutside(event) {
    if (!this.hasCalendarPanelTarget || this.calendarPanelTarget.classList.contains("hidden")) return
    if (!this.hasDateSectionTarget) return
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
    this.syncTimeOptions()
    this.ensureValidCurrentSelection()
    this.renderCalendar()
    this.apply()
    this.syncDisplay()
  }

  openCalendar() {
    if (!this.hasCalendarPanelTarget) return

    this.initializeDefaultSelection()
    clearTimeout(this.closeAnimationTimeout)
    this.calendarPanelTarget.classList.remove("hidden")
    requestAnimationFrame(() => {
      this.calendarPanelTarget.classList.add("is-open")
    })
  }

  apply() {
    this.syncTimeOptions()
    this.ensureValidCurrentSelection()
    this.dayEnabledInputTarget.value = "1"
    this.timeEnabledInputTarget.value = "1"
    this.valueInputTarget.value = this.pickerInputTarget.value || ""
    this.hourInputTarget.value = this.hourSelectTarget.value || "00"
    this.minuteInputTarget.value = this.minuteSelectTarget.value || "00"
    this.syncDisplay()
  }

  syncDisplay() {
    if (this.hasDisplayTarget) {
      this.displayTarget.textContent = this.displayValue() || "Chọn thời gian hoàn thành"
    }

    if (this.hasCalendarTriggerLabelTarget) {
      this.calendarTriggerLabelTarget.textContent = this.formattedDate(this.pickerInputTarget.value || this.valueInputTarget.value) || "Chọn ngày hoàn thành"
    }
  }

  renderCalendar() {
    if (!this.hasCalendarDaysTarget || !this.hasCalendarMonthLabelTarget) return

    const selectedValue = this.pickerInputTarget.value || this.today()
    const selectedDate = this.parseDate(selectedValue)
    const month = this.visibleMonth || new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1)
    const year = month.getFullYear()
    const monthIndex = month.getMonth()

    this.calendarMonthLabelTarget.textContent = `Thang ${monthIndex + 1} Nam ${year}`
      .replace("Thang", "Tháng")
      .replace("Nam", "Năm")

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
      const isDisabled = this.isDateDisabled(currentValue)

      const button = document.createElement("button")
      button.type = "button"
      if (!isDisabled) button.dataset.action = "click->completion-date-picker#pickDate"
      button.dataset.value = currentValue
      button.className = [
        "completion-date-picker__day inline-flex aspect-square w-[84%] justify-self-center items-center justify-center rounded-xl text-sm font-semibold transition",
        !inCurrentMonth ? "completion-date-picker__day--outside" : null,
        isSelected ? "completion-date-picker__day--selected" : null,
        isToday && !isSelected ? "completion-date-picker__day--today" : null,
        isDisabled ? "completion-date-picker__day--disabled" : null
      ].filter(Boolean).join(" ")
      button.disabled = isDisabled
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

  nextDay() {
    const nextDay = new Date()
    nextDay.setDate(nextDay.getDate() + 1)
    nextDay.setHours(0, 0, 0, 0)
    return this.formatIsoDate(nextDay)
  }

  currentHour() {
    return String(new Date().getHours()).padStart(2, "0")
  }

  currentMinute() {
    return String(new Date().getMinutes()).padStart(2, "0")
  }

  currentTimestamp() {
    const now = new Date()
    now.setSeconds(0, 0)
    return now
  }

  initializeDefaultSelection() {
    const hasExistingDateSelection = Boolean(this.pickerInputTarget.value || this.valueInputTarget.value)
    if (hasExistingDateSelection && this.hourInputTarget.value && this.minuteInputTarget.value) return

    const defaultDate = this.nextDay()
    this.pickerInputTarget.value = hasExistingDateSelection ? (this.pickerInputTarget.value || this.valueInputTarget.value) : defaultDate
    this.hourSelectTarget.value = hasExistingDateSelection ? (this.hourInputTarget.value || "00") : "00"
    this.minuteSelectTarget.value = hasExistingDateSelection ? (this.minuteInputTarget.value || "00") : "00"
    this.apply()
    this.setVisibleMonthFromValue()
    this.renderCalendar()
  }

  isDateDisabled(value) {
    return this.parseDate(value) < this.parseDate(this.today())
  }

  selectedDateIsToday() {
    return (this.pickerInputTarget.value || this.valueInputTarget.value) === this.today()
  }

  syncTimeOptions() {
    if (!this.hasHourSelectTarget || !this.hasMinuteSelectTarget) return

    const now = this.currentTimestamp()
    const isToday = this.selectedDateIsToday()
    const currentHour = now.getHours()
    const currentMinute = now.getMinutes()

    Array.from(this.hourSelectTarget.options).forEach((option) => {
      const hour = Number(option.value)
      option.disabled = isToday && hour < currentHour
    })

    const selectedHour = Number(this.hourSelectTarget.value || currentHour)
    Array.from(this.minuteSelectTarget.options).forEach((option) => {
      const minute = Number(option.value)
      option.disabled = isToday && selectedHour === currentHour && minute < currentMinute
    })
  }

  ensureValidCurrentSelection() {
    if (!this.hasHourSelectTarget || !this.hasMinuteSelectTarget) return

    const firstEnabledHour = Array.from(this.hourSelectTarget.options).find((option) => !option.disabled)
    if (this.hourSelectTarget.selectedOptions[0]?.disabled && firstEnabledHour) {
      this.hourSelectTarget.value = firstEnabledHour.value
    }

    this.syncTimeOptions()

    const firstEnabledMinute = Array.from(this.minuteSelectTarget.options).find((option) => !option.disabled)
    if (this.minuteSelectTarget.selectedOptions[0]?.disabled && firstEnabledMinute) {
      this.minuteSelectTarget.value = firstEnabledMinute.value
    }
  }

  get dayEnabled() {
    return this.dayEnabledInputTarget.value !== "0"
  }

  get timeEnabled() {
    return this.timeEnabledInputTarget.value === "1"
  }
}
