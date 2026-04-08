// Rustiq.js - Helper for QML services to interact with Rust IPC
// Usage:
//   var Rustiq = require("./Rustiq.js");
//   Rustiq.subscribe(["sysmon_updated"], function(event) { ... });

.pragma library

var baseUrl = "http://localhost:8765";
var _xhr = null;
var _callbacks = [];
var _filters = [];
var _connected = false;

var eventTypes = {
    "sysmon_updated": true,
    "weather_updated": true,
    "niri_window_focus": true,
    "niri_workspace_changed": true,
    "niri_windows_changed": true,
    "notification": true,
    "notification_closed": true,
    "clipboard_updated": true,
    "brightness_updated": true,
    "network_updated": true,
    "bluetooth_updated": true,
    "media_player_changed": true
};

function subscribe(callback, filters) {
    if (typeof callback !== 'function') {
        console.error("Rustiq.subscribe: callback must be a function");
        return;
    }

    _callbacks.push(callback);
    _filters = filters || [];

    if (_connected) {
        return;
    }

    var filterQuery = "";
    if (_filters.length > 0) {
        var validFilters = _filters.filter(function(f) {
            return eventTypes.hasOwnProperty(f);
        });
        if (validFilters.length > 0) {
            filterQuery = "?filters=" + encodeURIComponent(validFilters.join(","));
        }
    }

    _xhr = new XMLHttpRequest();
    _xhr.open("GET", baseUrl + "/events" + filterQuery, true);

    _xhr.onprogress = function() {
        if (_xhr.readyState === XMLHttpRequest.LOADING) {
            var text = _xhr.responseText;
            var lines = text.split("\n");
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i];
                if (line.substring(0, 6) === "data: ") {
                    try {
                        var event = JSON.parse(line.substring(6));
                        for (var j = 0; j < _callbacks.length; j++) {
                            try {
                                _callbacks[j](event);
                            } catch (e) {
                                console.error("Rustiq callback error:", e);
                            }
                        }
                    } catch (e) {
                        console.error("Rustiq SSE parse error:", e);
                    }
                }
            }
        }
    };

    _xhr.onload = function() {
        _connected = false;
        console.log("Rustiq SSE disconnected");
        if (_callbacks.length > 0) {
            Qt.callLater(function() {
                subscribe(_callbacks[_callbacks.length - 1], _filters);
            });
        }
    };

    _xhr.onerror = function() {
        _connected = false;
        console.error("Rustiq SSE error");
        if (_callbacks.length > 0) {
            Qt.callLater(function() {
                subscribe(_callbacks[_callbacks.length - 1], _filters);
            });
        }
    };

    _connected = true;
    _xhr.send();
}

function unsubscribe(callback) {
    var index = _callbacks.indexOf(callback);
    if (index > -1) {
        _callbacks.splice(index, 1);
    }
    if (_callbacks.length === 0) {
        disconnect();
    }
}

function disconnect() {
    if (_xhr) {
        _xhr.abort();
        _xhr = null;
    }
    _callbacks = [];
    _connected = false;
}

function isConnected() {
    return _connected;
}

function get(path, callback) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", baseUrl + path);
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                try {
                    callback(JSON.parse(xhr.responseText), null);
                } catch (e) {
                    callback(null, "parse error: " + e);
                }
            } else {
                callback(null, "http " + xhr.status);
            }
        }
    };
    xhr.send();
}

function post(path, body, callback) {
    var xhr = new XMLHttpRequest();
    xhr.open("POST", baseUrl + path);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (callback) callback(xhr.status === 200, xhr.status);
        }
    };
    xhr.send(body ? JSON.stringify(body) : "");
}

// Convenience methods
function ping(callback) {
    get("/ping", callback);
}

function sysmon(callback) {
    get("/sysmon", callback);
}

function weather(callback) {
    get("/weather", callback);
}

function notifications(callback) {
    get("/notifications", callback);
}

function notificationHistory(callback) {
    get("/notifications/history", callback);
}

function dismissNotification(id, callback) {
    post("/notifications/" + id + "/dismiss", null, callback);
}

function network(callback) {
    get("/network", callback);
}

function bluetooth(callback) {
    get("/bluetooth", callback);
}

function clipboard(callback) {
    get("/clipboard/list", callback);
}

function brightness(callback) {
    get("/brightness", callback);
}

function media(callback) {
    get("/media", callback);
}
