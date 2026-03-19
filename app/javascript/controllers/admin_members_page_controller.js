import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { baseUrl: String }

  connect() {
    this.clearModalParamsFromUrl()
  }

  clearModalParamsFromUrl() {
    const url = new URL(window.location.href)
    const hadEditParam = url.searchParams.has("edit_member_id")
    const hadResetParam = url.searchParams.has("reset_password_member_id")

    if (!hadEditParam && !hadResetParam) return

    url.searchParams.delete("edit_member_id")
    url.searchParams.delete("reset_password_member_id")

    const nextUrl = `${url.pathname}${url.search}${url.hash}`
    window.history.replaceState({}, "", nextUrl)
  }
}
