// RustiqClient — IPC bridge to the Rust daemon
// Usage: RustiqClient { id: client }
//        client.get("/sysmon", function(data) { ... })
//        client.subscribe(["sysmon_updated"], function(event) { ... })

import QtQuick

QtObject {
    id: root

    readonly property string baseUrl: "http://localhost:8765"

    // Event filters for SSE subscription
    property var eventFilters: []

    // Active SSE connection
    property var _sseXhr: null
    property var _sseCallbacks: ([])
    property bool _sseConnected: false

    // Low-level GET request
    function get(path, callback) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", baseUrl + path)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        callback(JSON.parse(xhr.responseText), null)
                    } catch(e) {
                        callback(null, "parse error: " + e)
                    }
                } else {
                    callback(null, "http " + xhr.status)
                }
            }
        }
        xhr.send()
    }

    // Low-level POST request
    function post(path, body, callback) {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", baseUrl + path)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (callback) {
                    callback(xhr.status === 200, xhr.status)
                }
            }
        }
        xhr.send(body ? JSON.stringify(body) : "")
    }

    // Server-Sent Events subscription
    function subscribe(callbacks, filters) {
        if (_sseXhr) {
            _sseXhr.abort()
        }

        _sseCallbacks = callbacks instanceof Array ? callbacks : [callbacks]
        var filterQuery = filters && filters.length > 0 ? "?filters=" + encodeURIComponent(filters.join(",")) : ""

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
                            for (var j = 0; j < _sseCallbacks.length; j++) {
                                _sseCallbacks[j](event)
                            }
                        } catch (e) {
                            console.error("SSE parse error:", e)
                        }
                    }
                }
            }
        }

        _sseXhr.onload = function() {
            _sseConnected = false
            console.log("SSE connection closed")
        }

        _sseXhr.onerror = function() {
            _sseConnected = false
            console.error("SSE connection error")
            // Reconnect after 1 second
            Qt.callLater(function() {
                if (root.eventFilters.length > 0 || _sseCallbacks.length > 0) {
                    subscribe(_sseCallbacks, root.eventFilters)
                }
            })
        }

        _sseConnected = true
        _sseXhr.send()
    }

    function unsubscribe() {
        if (_sseXhr) {
            _sseXhr.abort()
            _sseXhr = null
        }
        _sseCallbacks = []
        _sseConnected = false
    }

    // Convenience methods for system stats
    function sysmon(callback) { get("/sysmon", callback) }
    function weather(callback) { get("/weather", callback) }

    // Convenience methods for niri
    function workspaces(callback) { get("/niri/workspaces", callback) }
    function windows(callback) { get("/niri/windows", callback) }
    function activateWorkspace(id, callback) { post("/niri/workspaces/" + id + "/activate", null, callback) }
    function focusWindow(id, callback) { post("/niri/windows/" + id + "/focus", null, callback) }

    // Search
    function search(query, limit, callback) {
        get("/search?q=" + encodeURIComponent(query) + "&limit=" + (limit || 20), callback)
    }

    // Notifications
    function notifications(callback) { get("/notifications", callback) }
    function notificationHistory(callback) { get("/notifications/history", callback) }
    function dismissNotification(id, callback) { post("/notifications/" + id + "/dismiss", null, callback) }
    function dismissAllNotifications(callback) { post("/notifications/dismiss-all", null, callback) }
    function clearNotificationHistory(callback) { post("/notifications/clear-history", null, callback) }

    // Network
    function network(callback) { get("/network", callback) }
    function setWifiEnabled(enabled, callback) { post("/network/wifi", { enabled: enabled }, callback) }

    // Bluetooth
    function bluetooth(callback) { get("/bluetooth", callback) }
    function setBluetoothEnabled(enabled, callback) { post("/bluetooth", { enabled: enabled }, callback) }

    // Clipboard
    function clipboard(callback) { get("/clipboard", callback) }
    function clipboardList(callback) { get("/clipboard/list", callback) }
    function clipboardCopy(id, callback) { post("/clipboard/" + id + "/copy", null, callback) }
    function clipboardDelete(id, callback) { post("/clipboard/" + id + "/delete", null, callback) }
    function clipboardWipe(callback) { post("/clipboard/wipe", null, callback) }
    function clipboardDecode(id, callback) {
        get("/clipboard/" + id + "/decode", function(data, err) {
            if (callback) callback(data ? data.content : null, err)
        })
    }

    // Brightness
    function brightness(callback) { get("/brightness", callback) }
    function setBrightness(value, callback) { post("/brightness", { value: value }, callback) }
    function increaseBrightness(delta, callback) { post("/brightness/increase", { delta: delta }, callback) }
    function decreaseBrightness(delta, callback) { post("/brightness/decrease", { delta: delta }, callback) }

    // Media
    function media(callback) { get("/media", callback) }
    function mediaPlay(player, callback) { post("/media/" + player + "/play", null, callback) }
    function mediaPause(player, callback) { post("/media/" + player + "/pause", null, callback) }
    function mediaPlayPause(player, callback) { post("/media/" + player + "/play-pause", null, callback) }
    function mediaStop(player, callback) { post("/media/" + player + "/stop", null, callback) }
    function mediaNext(player, callback) { post("/media/" + player + "/next", null, callback) }
    function mediaPrevious(player, callback) { post("/media/" + player + "/previous", null, callback) }

    // App launch
    function launch(appId, callback) { post("/launch", { app_id: appId }, callback) }
}
