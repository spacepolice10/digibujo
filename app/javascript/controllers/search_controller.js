import { Controller } from "@hotwired/stimulus";
import { debounce } from "helpers/debounce";

const SEARCH_DEBOUNCE_MS = 20;

export default class extends Controller {
  static targets = ["form", "textform"];
  static values = { replaceLink: { type: Boolean, default: true }, historyUrl: String, selectionUrl: String };

  connect() {
    this.abortController = null;
    this.debouncedSearch = debounce(
      () => this.performSearch(),
      SEARCH_DEBOUNCE_MS,
    );
  }

  disconnect() {
    this.cancelPendingRequest();
  }

  search() {
    this.cancelPendingRequest();
    this.abortController = new AbortController();
    this.debouncedSearch();
  }

  async performSearch() {
    const q = this.textformTarget.value.trim();
    const form = this.formTarget;
    const url = new URL(form.action, window.location.origin);
    const params = new URLSearchParams(new FormData(form));

    params.set("q", q);
    params.delete("page");
    url.search = params.toString();

    const response = await fetch(url.toString(), {
      signal: this.abortController.signal,
      headers: { Accept: "text/vnd.turbo-stream.html" },
    }).catch(() => null);
    if (!response || !response.ok) return;
    const turboStreamHtml = await response.text().catch(() => "");
    if (!turboStreamHtml) return;
    if (!window.Turbo) return;
    window.Turbo.renderStreamMessage(turboStreamHtml);
    if (this.replaceLinkValue) {
      const historyUrl = this.hasHistoryUrlValue
        ? new URL(this.historyUrlValue, window.location.origin)
        : url;
      historyUrl.searchParams.set("q", q);
      history.replaceState({}, "", historyUrl.toString());
    }
  }

  cancelPendingRequest() {
    if (this.abortController) this.abortController.abort();
    this.abortController = null;
  }

  rememberSelection(event) {
    if (!this.hasSelectionUrlValue) return;

    const link = event.currentTarget;
    const searchableType = link.dataset.searchableType;
    const searchableId = link.dataset.searchableId;
    if (!searchableType || !searchableId) return;

    const token = document.querySelector("meta[name='csrf-token']")?.content;
    const q = this.textformTarget.value.trim();

    fetch(this.selectionUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": token
      },
      body: JSON.stringify({ searchable_type: searchableType, searchable_id: searchableId, query: q }),
      keepalive: true
    }).catch(() => null);
  }
}
