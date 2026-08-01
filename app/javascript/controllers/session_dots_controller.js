import { Controller } from "@hotwired/stimulus"

// Auth-only interactive grid: canvas owns the dots (CSS grid is suppressed).
// Nearby dots part from the pointer and tint toward --color-accent.
export default class extends Controller {
  static targets = ["canvas"]

  connect() {
    this.ctx = this.canvasTarget.getContext("2d", { alpha: false })
    this.dots = []
    this.pointer = null
    this.raf = null
    this.abortController = new AbortController()
    const { signal } = this.abortController

    document.documentElement.classList.add("session-dots-active")
    this.#ensureProbe()
    this.#resize()
    this.#seed()
    this.#paint()

    window.addEventListener("resize", this.#onResize, { signal })

    if (this.#interactive) {
      window.addEventListener("pointermove", this.#onPointerMove, { passive: true, signal })
      window.addEventListener("pointerdown", this.#onPointerMove, { passive: true, signal })
      document.documentElement.addEventListener("pointerleave", this.#onPointerLeave, { signal })
    }
  }

  disconnect() {
    this.abortController.abort()
    if (this.raf) cancelAnimationFrame(this.raf)
    document.documentElement.classList.remove("session-dots-active")
    this.probe?.remove()
  }

  get #interactive() {
    return window.matchMedia("(hover: hover) and (pointer: fine)").matches &&
      !window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }

  #onResize = () => {
    this.#resize()
    this.#seed()
    this.#paint()
  }

  #onPointerMove = (event) => {
    this.pointer = { x: event.clientX, y: event.clientY }
    this.#ensureTick()
  }

  #onPointerLeave = () => {
    this.pointer = null
    this.#ensureTick()
  }

  #ensureTick() {
    if (this.raf) return
    this.#tick()
  }

  #ensureProbe() {
    if (this.probe?.isConnected) return

    this.probe = document.createElement("div")
    this.probe.setAttribute("aria-hidden", "true")
    this.probe.style.cssText = "position:fixed;inset:auto;width:1px;height:1px;pointer-events:none;opacity:0"
    document.body.appendChild(this.probe)
  }

  #resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2)
    const width = window.innerWidth
    const height = window.innerHeight
    const canvas = this.canvasTarget

    canvas.width = Math.floor(width * dpr)
    canvas.height = Math.floor(height * dpr)
    canvas.style.width = `${width}px`
    canvas.style.height = `${height}px`
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    this.width = width
    this.height = height
    this.gap = this.#gridSize()
    this.radius = this.gap * 7
    this.push = this.gap * 1.75
  }

  #gridSize() {
    const raw = getComputedStyle(document.documentElement)
      .getPropertyValue("--background-grid-size")
      .trim()
    const rem = Number.parseFloat(raw) || 1.25
    const root = Number.parseFloat(getComputedStyle(document.documentElement).fontSize) || 16

    return rem * root
  }

  #seed() {
    const gap = this.gap
    const dots = []
    const cols = Math.ceil(this.width / gap) + 1
    const rows = Math.ceil(this.height / gap) + 1

    for (let row = 0; row < rows; row++) {
      for (let col = 0; col < cols; col++) {
        dots.push({
          homeX: col * gap,
          homeY: row * gap,
          x: col * gap,
          y: row * gap
        })
      }
    }

    this.dots = dots
  }

  #tick = () => {
    const moving = this.#step()
    this.#paint()

    if (this.pointer || moving) {
      this.raf = requestAnimationFrame(this.#tick)
    } else {
      this.raf = null
    }
  }

  #step() {
    const pointer = this.pointer
    const radius = this.radius
    const radiusSq = radius * radius
    const push = this.push
    const ease = 0.22
    let moving = false

    for (const dot of this.dots) {
      let targetX = dot.homeX
      let targetY = dot.homeY

      if (pointer) {
        const dx = dot.homeX - pointer.x
        const dy = dot.homeY - pointer.y
        const distSq = dx * dx + dy * dy

        if (distSq < radiusSq && distSq > 0.01) {
          const dist = Math.sqrt(distSq)
          const force = (1 - dist / radius) ** 2
          targetX += (dx / dist) * force * push
          targetY += (dy / dist) * force * push
        }
      }

      const nextX = dot.x + (targetX - dot.x) * ease
      const nextY = dot.y + (targetY - dot.y) * ease

      if (
        Math.abs(nextX - dot.homeX) > 0.05 ||
        Math.abs(nextY - dot.homeY) > 0.05 ||
        Math.abs(nextX - dot.x) > 0.05 ||
        Math.abs(nextY - dot.y) > 0.05
      ) {
        moving = true
      }

      dot.x = nextX
      dot.y = nextY
    }

    return moving
  }

  #paint() {
    const ctx = this.ctx
    const pointer = this.pointer
    const radius = this.radius
    const bg = this.#cssColor("--color-bg-base")
    const base = this.#gridColour()
    const accent = this.#cssColor("--color-accent")

    ctx.globalAlpha = 1
    ctx.fillStyle = bg
    ctx.fillRect(0, 0, this.width, this.height)

    ctx.fillStyle = base

    for (const dot of this.dots) {
      ctx.beginPath()
      ctx.arc(dot.x, dot.y, 1, 0, Math.PI * 2)
      ctx.fill()
    }

    if (!pointer) return

    ctx.fillStyle = accent

    for (const dot of this.dots) {
      const dist = Math.hypot(dot.x - pointer.x, dot.y - pointer.y)
      if (dist >= radius) continue

      const force = 1 - dist / radius
      ctx.globalAlpha = 0.2 + force ** 1.4 * 0.8
      ctx.beginPath()
      ctx.arc(dot.x, dot.y, 1 + force * 2.2, 0, Math.PI * 2)
      ctx.fill()
    }

    ctx.globalAlpha = 1
  }

  #gridColour() {
    const dark = window.matchMedia("(prefers-color-scheme: dark)").matches
    return this.#cssColor(dark ? "--background-grid-colour-dark" : "--background-grid-colour-light")
  }

  // Resolve a custom property to a canvas-safe rgb()/rgba() via backgroundColor.
  #cssColor(variable) {
    this.probe.style.backgroundColor = ""
    this.probe.style.backgroundColor = `var(${variable})`
    const value = getComputedStyle(this.probe).backgroundColor
    if (!value || value === "rgba(0, 0, 0, 0)" || value === "transparent") {
      return "rgb(128, 128, 128)"
    }
    return value
  }
}
