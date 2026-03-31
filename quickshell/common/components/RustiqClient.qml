// RustiqClient — IPC bridge to the Rust daemon
// Usage: RustiqClient { id: client }
//        client.get("/sysmon", function(data) { ... })

import QtQuick

QtObject {
    id: root

    readonly property string socketPath: {
        var rt = Qt.environment ? Qt.environment["XDG_RUNTIME_DIR"] : "/run/user/1000"
        return "http+unix://" + encodeURIComponent(rt + "/rustiq.sock")
    }

    // Low-level GET request
    function get(path, callback) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://localhost" + path)
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

    // POST request
    function post(path, body, callback) {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://localhost" + path)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (callback) callback(xhr.status === 200)
            }
        }
        xhr.send(body ? JSON.stringify(body) : "")
    }

    // Convenience methods
    function sysmon(cb)      { get("/sysmon", cb) }
    function weather(cb)     { get("/weather", cb) }
    function workspaces(cb)  { get("/niri/workspaces", cb) }
    function windows(cb)     { get("/niri/windows", cb) }

    function search(query, limit, cb) {
        get("/search?q=" + encodeURIComponent(query) + "&limit=" + (limit || 20), cb)
    }

    function activateWorkspace(id) {
        post("/niri/workspace/" + id + "/activate", null, null)
    }

    function focusWindow(id) {
        post("/niri/window/" + id + "/focus", null, null)
    }

    function launch(appId) {
        post("/launch", { app_id: appId }, null)
    }

    function dismissNotification(id) {
        post("/notifications/" + id + "/dismiss", null, null)
    }
}
