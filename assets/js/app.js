// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"

let Hooks = {}

// Confirmations do not need to be dismissed by hand. Errors are left alone -
// they stay until the person has seen them.
Hooks.AutoDismiss = {
    mounted() {
        this.timer = setTimeout(() => {
            this.pushEvent("lv:clear-flash", { key: this.el.dataset.flashKey })
        }, 6000)
    },
    destroyed() {
        clearTimeout(this.timer)
    }
}

Hooks.SearchBar = {
    mounted() {
        const searchBarContainer = (this).el
        document.addEventListener('keydown', (event) => {
            if (event.key !== 'ArrowUp' && event.key !== 'ArrowDown') {
                return
            }

            const focusElemnt = document.querySelector(':focus')

            if (!focusElemnt) {
                return
            }

            if (!searchBarContainer.contains(focusElemnt)) {
                return
            }

            event.preventDefault()

            const tabElements = document.querySelectorAll(
                '#search-input, #options a, #option-none',
            )
            const focusIndex = Array.from(tabElements).indexOf(focusElemnt)
            const tabElementsCount = tabElements.length - 1

            if (event.key === 'ArrowUp') {
                tabElements[focusIndex > 0 ? focusIndex - 1 : tabElementsCount].focus()
            }

            if (event.key === 'ArrowDown') {
                tabElements[focusIndex < tabElementsCount ? focusIndex + 1 : 0].focus()
            }
        })
    },
}

// Remembers, per device, whether this browser shows the shift board or the
// ordinary page. Screen width deliberately plays no part: a 27" desktop is
// wider than the old 2xl breakpoint and is not a wall display.
const DISPLAY_MODE_KEY = "shift-display-mode"

Hooks.ShiftDisplayMode = {
    mounted() {
        const mode = this.el.dataset.mode

        if (mode === "tv") {
            // Includes a kiosk parked directly on /shift/tv, which never touched
            // the switch - record it so a later visit to /shift comes back here.
            localStorage.setItem(DISPLAY_MODE_KEY, "tv")
        } else if (localStorage.getItem(DISPLAY_MODE_KEY) === "tv") {
            this.pushEvent("set-display-mode", { mode: "tv" })
        }

        this.el.addEventListener("click", () => {
            const next = this.el.dataset.mode === "tv" ? "normal" : "tv"
            // Write before navigating. If the server got there first, the /shift
            // mount would read a stale "tv" and bounce straight back here.
            localStorage.setItem(DISPLAY_MODE_KEY, next)
            this.pushEvent("set-display-mode", { mode: next })
        })
    },
}

// Arrow-key navigation across the board, for a TV remote's D-pad. Tabbing 34
// times to reach F-35 is not a usable way to open a family.
Hooks.TvGridNav = {
    mounted() {
        this.index = 0
        this.onKeyDown = this.onKeyDown.bind(this)
        this.el.addEventListener("keydown", this.onKeyDown)
        this.el.addEventListener("focusin", (event) => {
            const i = this.cells().indexOf(event.target.closest("[data-family-id]"))
            if (i >= 0) { this.index = i }
            this.syncTabIndex()
            this.pushEvent("tv-focus", { focused: true })
        })
        this.el.addEventListener("focusout", (event) => {
            // Moving between cells fires focusout then focusin - only report
            // leaving when focus actually landed outside the board.
            if (this.el.contains(event.relatedTarget)) { return }
            this.pushEvent("tv-focus", { focused: false })
        })
        this.syncTabIndex()
    },

    updated() { this.syncTabIndex() },

    destroyed() { this.el.removeEventListener("keydown", this.onKeyDown) },

    cells() {
        return Array.from(this.el.querySelectorAll("[data-family-id]"))
    },

    // Derived from geometry rather than the CSS track list: cells sharing an
    // offsetTop are one row, which holds whatever the grid decided to do.
    columns(cells) {
        if (cells.length === 0) { return 1 }
        const firstRowTop = cells[0].offsetTop
        return cells.filter((cell) => cell.offsetTop === firstRowTop).length
    },

    // Exactly one cell is tabbable, so Tab enters and leaves the board in one
    // press instead of walking every family.
    syncTabIndex() {
        const cells = this.cells()
        if (this.index >= cells.length) { this.index = Math.max(0, cells.length - 1) }
        cells.forEach((cell, i) => cell.setAttribute("tabindex", i === this.index ? "0" : "-1"))
    },

    onKeyDown(event) {
        const step = { ArrowRight: 1, ArrowLeft: -1, ArrowDown: 0, ArrowUp: 0 }[event.key]
        if (step === undefined) { return }

        const cells = this.cells()
        if (cells.length === 0) { return }

        const columns = this.columns(cells)
        const delta = event.key === "ArrowDown" ? columns
            : event.key === "ArrowUp" ? -columns
                : step

        const next = this.index + delta

        if (next < 0) {
            // Off the top of the board - hand focus to the header controls.
            const header = document.getElementById("tv-header")?.querySelector("button")
            if (header) { event.preventDefault(); header.focus() }
            return
        }
        if (next >= cells.length) { return }

        event.preventDefault()
        this.index = next
        this.syncTabIndex()
        cells[next].focus()
    },
}

Hooks.TvGridSize = {
    minRowHeight: 96,
    rowGap: 12,
    minRows: 10,
    // Ceiling on rows / cards trimmed from the page, only in effect for the page of
    // families currently on screen - a card that doesn't fit shouldn't be silently
    // clipped off the bottom of the screen. Reset (see fingerprint()) whenever the
    // rendered set of families changes, so a fix applied for one oversized card
    // doesn't permanently shrink every other, unrelated page.
    maxRows: Infinity,
    cardTrim: 0,
    lastFingerprint: null,
    lastPushedRows: undefined,
    lastPushedTrim: undefined,
    lastPushedColumns: undefined,

    mounted() {
        this.measure = this.measure.bind(this)
        this.checkOverflow = this.checkOverflow.bind(this)
        this.lastFingerprint = this.fingerprint()
        this.measure()
        this.checkOverflow()
        window.addEventListener("resize", this.measure)
    },

    updated() {
        const fp = this.fingerprint()
        if (fp !== this.lastFingerprint) {
            this.lastFingerprint = fp
            this.maxRows = Infinity
            this.cardTrim = 0
        }
        this.measure()
        this.checkOverflow()
    },

    destroyed() {
        window.removeEventListener("resize", this.measure)
    },

    fingerprint() {
        // Identify the page by its first card only (not the count) - the count
        // itself shifts as cardTrim is applied/reset, which would otherwise make
        // every trim adjustment look like a brand new page and reset itself.
        const first = this.el.querySelector("[data-family-id]")
        return first ? first.getAttribute("data-family-id") : ""
    },

    // Columns come from `repeat(auto-fill, minmax(...))`, so CSS decides how many
    // fit and the server is told after the fact. Nothing here hardcodes a count.
    columns() {
        const tracks = getComputedStyle(this.el).gridTemplateColumns
        return tracks === "none" ? 1 : tracks.split(" ").length
    },

    push() {
        this.lastPushedRows = this.rows
        this.lastPushedTrim = this.cardTrim
        this.lastPushedColumns = this.cols
        this.pushEvent("tv-rows-changed", { rows: this.rows, trim: this.cardTrim, columns: this.cols })
    },

    measure() {
        if (this.el.offsetHeight === 0) {
            // Not on screen - nothing to measure.
            return
        }

        const target = Math.floor((this.el.clientHeight + this.rowGap) / (this.minRowHeight + this.rowGap))
        this.rows = Math.max(this.minRows, Math.min(target, this.maxRows))
        this.cols = this.columns()

        if (this.rows !== this.lastPushedRows
            || this.cardTrim !== this.lastPushedTrim
            || this.cols !== this.lastPushedColumns) {
            this.push()
        }
    },

    checkOverflow() {
        if (this.el.offsetHeight === 0 || this.rows === undefined) {
            return
        }

        const overflowing = this.el.scrollHeight > this.el.clientHeight + 2
        if (!overflowing) {
            return
        }

        if (this.rows > this.minRows) {
            this.maxRows = this.rows - 1
            this.measure()
            return
        }

        const columns = this.cols || this.columns()
        const maxTrim = this.rows * columns - columns
        if (this.cardTrim < maxTrim) {
            this.cardTrim += columns
            this.push()
        }
    },
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, params: { _csrf_token: csrfToken } })

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

