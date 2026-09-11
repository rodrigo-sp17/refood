// Service worker for the Refood tablets.
//
// Its only jobs are to make the app installable (Chrome requires a registered
// worker with a fetch handler) and to serve static assets from cache so the app
// opens instantly. It deliberately does NOT handle offline: the whole UI is
// LiveView, which is useless without a live socket, so a cached shell would only
// show a frozen page pretending to work.
//
// Bumping CACHE is the kill switch - the next activate drops every older cache.
const CACHE = "refood-static-v1"

// Only these prefixes are intercepted. Everything else - HTML, /live/websocket,
// POSTs, /export/* - is left alone so LiveView behaves exactly as it would
// without a worker.
const CACHEABLE_PREFIXES = ["/assets/", "/images/"]

self.addEventListener("install", () => {
    // Nothing to pre-cache: asset paths are fingerprinted by phx.digest and
    // change on every deploy, so a hardcoded list would go stale immediately.
    self.skipWaiting()
})

self.addEventListener("activate", event => {
    event.waitUntil(
        caches
            .keys()
            .then(names => Promise.all(names.filter(name => name !== CACHE).map(name => caches.delete(name))))
            .then(() => self.clients.claim())
    )
})

self.addEventListener("fetch", event => {
    const request = event.request

    if (request.method !== "GET") return

    const url = new URL(request.url)
    if (url.origin !== self.location.origin) return
    if (!CACHEABLE_PREFIXES.some(prefix => url.pathname.startsWith(prefix))) return

    event.respondWith(staleWhileRevalidate(request))
})

// Serve the cached copy immediately when there is one, and refresh it in the
// background. A digested asset never changes content under the same URL, so the
// stale read is always correct; the revalidate only matters for undigested
// images replaced in place.
async function staleWhileRevalidate(request) {
    const cache = await caches.open(CACHE)
    const cached = await cache.match(request)

    const network = fetch(request)
        .then(response => {
            if (response.ok) cache.put(request, response.clone())
            return response
        })
        .catch(error => {
            if (cached) return cached
            throw error
        })

    return cached || network
}
