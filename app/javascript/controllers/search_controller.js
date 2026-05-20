import { Controller } from "@hotwired/stimulus";
import { debounce } from "helpers/debounce";

const SEARCH_DEBOUNCE_MS = 20;

export default class extends Controller {
  static targets = ["form", "textform"];

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
    history.replaceState({}, "", url.toString());
  }

  cancelPendingRequest() {
    if (this.abortController) this.abortController.abort();
    this.abortController = null;
  }
}
