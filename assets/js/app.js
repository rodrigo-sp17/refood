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

Hooks.TvGridSize = {
    minRowHeight: 84,
    rowGap: 12,
    minRows: 10,
    columns: 2,
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

    push() {
        this.lastPushedRows = this.rows
        this.lastPushedTrim = this.cardTrim
        this.pushEvent("tv-rows-changed", { rows: this.rows, trim: this.cardTrim })
    },

    measure() {
        if (this.el.offsetHeight === 0) {
            // Hidden (below the TV breakpoint) - nothing to measure.
            return
        }

        const target = Math.floor((this.el.clientHeight + this.rowGap) / (this.minRowHeight + this.rowGap))
        this.rows = Math.max(this.minRows, Math.min(target, this.maxRows))

        if (this.rows !== this.lastPushedRows || this.cardTrim !== this.lastPushedTrim) {
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

        const maxTrim = this.rows * this.columns - this.columns
        if (this.cardTrim < maxTrim) {
            this.cardTrim += this.columns
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

