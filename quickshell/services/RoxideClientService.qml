// RoxideClientService — IPC bridge to the Rust daemon
// Usage: RoxideClientService { id: client }
//
// Unified API:
//   client.request("GET", "/sysmon", callback)
//   client.request("POST", "/brightness", { value: 0.5 }, callback)
//   client.subscribe(["sysmon_updated"], function(event) { ... })

import QtQuick

QtObject {
    id: root

    readonly property string baseUrl: "http://localhost:" + (Qt.application.environments["ROXIDE_PORT"] || "8765")

    // Connection state
    readonly property bool connected: _sseConnected || _pendingRequests > 0
    property int _pendingRequests: 0
    property int _reconnectDelayMs: 1000
    readonly property int maxReconnectDelayMs: 30000

    // Event subscription state
    property var _eventFilters: []
    property var _sseXhr: null
    property var _sseCallbacks: ([])
    property bool _sseConnected: false

    // Registered event handlers (serviceName -> callback)
    property var _eventHandlers: ({})

    // Unified request method
    function request(method, path, body, callback) {
        _pendingRequests++

        var xhr = new XMLHttpRequest()
        xhr.open(method, baseUrl + path)

        if (method === "POST") {
            xhr.setRequestHeader("Content-Type", "application/json")
        }

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                _pendingRequests--

                if (xhr.status === 200) {
                    try {
                        var parsed = xhr.responseText ? JSON.parse(xhr.responseText) : null
                        if (callback) callback(parsed, null)
                    } catch(e) {
                        if (callback) callback(null, "parse error: " + e)
                    }
                } else {
                    if (callback) callback(null, "http " + xhr.status)
                }
            }
        }

        xhr.onerror = function() {
            _pendingRequests--
            if (callback) callback(null, "network error")
        }

        if (body && (typeof body === "object")) {
            xhr.send(JSON.stringify(body))
        } else {
            xhr.send(body || "")
        }
    }

    // Convenience GET
    function get(path, callback) {
        request("GET", path, null, callback)
    }

    // Convenience POST
    function post(path, body, callback) {
        request("POST", path, body, callback)
    }

    // Subscribe to SSE events with automatic reconnection
    function subscribe(filters, callback) {
        _eventFilters = filters || []
        _sseCallbacks = _sseCallbacks.concat(callback).filter(function(x, i, a) { return a.indexOf(x) === i })

        if (_sseXhr && _sseConnected) {
            return
        }

        _connectSSE()
    }

    function _connectSSE() {
        if (_sseXhr) {
            _sseXhr.abort()
        }

        var filterQuery = _eventFilters.length > 0 ? "?filters=" + encodeURIComponent(_eventFilters.join(",")) : ""

        _sseXhr = new XMLHttpRequest()
        _sseXhr.open("GET", baseUrl + "/events" + filterQuery, true)

        _sseXhr.onprogress = function() {
            if (_sseXhr.readyState === XMLHttpRequest.LOADING) {
                var text = _sseXhr.responseText
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i]
                    if (line.startsWith("data: ")) {
                        try {
                            var event = JSON.parse(line.substring(6))
                            _dispatchEvent(event)
                        } catch (e) {
                            console.error("RoxideClientService: SSE parse error:", e)
                        }
                    }
                }
            }
        }

        _sseXhr.onload = function() {
            _sseConnected = false
            _scheduleReconnect()
        }

        _sseXhr.onerror = function() {
            _sseConnected = false
            console.error("RoxideClientService: SSE connection error")
            _scheduleReconnect()
        }

        _sseConnected = true
        _sseXhr.send()
    }

    function _scheduleReconnect() {
        if (_eventFilters.length === 0 && _sseCallbacks.length === 0) {
            return
        }

        var delay = _reconnectDelayMs
        _reconnectDelayMs = Math.min(_reconnectDelayMs * 2, root.maxReconnectDelayMs)

        console.log("RoxideClientService: Reconnecting in " + delay + "ms (backoff)")

        Qt.callLater(function() {
            if (_eventFilters.length > 0 || _sseCallbacks.length > 0) {
                _connectSSE()
            }
        })
    }

    function _dispatchEvent(event) {
        if (!event || !event.type) return

        for (var i = 0; i < _sseCallbacks.length; i++) {
            try {
                _sseCallbacks[i](event)
            } catch (e) {
                console.error("RoxideClientService: Event handler error:", e)
            }
        }
    }

    function unsubscribe(callback) {
        if (callback) {
            _sseCallbacks = _sseCallbacks.filter(function(c) { return c !== callback })
        } else {
            _sseCallbacks = []
            _eventFilters = []
        }

        if (_sseCallbacks.length === 0) {
            if (_sseXhr) {
                _sseXhr.abort()
                _sseXhr = null
            }
            _sseConnected = false
            _reconnectDelayMs = 1000
        }
    }

    // Register a service handler for a specific event type
    function registerHandler(serviceName, eventType, callback) {
        if (!_eventHandlers[eventType]) {
            _eventHandlers[eventType] = []
        }
        _eventHandlers[eventType].push({ service: serviceName, callback: callback })
    }

    function unregisterHandler(serviceName, eventType) {
        if (_eventHandlers[eventType]) {
            _eventHandlers[eventType] = _eventHandlers[eventType].filter(
                function(h) { return h.service !== serviceName }
            )
        }
    }

    // Ping health check
    function ping(callback) {
        get("/ping", function(data, err) {
            if (!err && data) {
                _reconnectDelayMs = 1000
            }
            if (callback) callback(data, err)
        })
    }
}
