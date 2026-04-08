// RustiqIntegration — Unified Rust daemon integration layer
// Provides connection monitoring and event routing to services
//
// Usage:
//   RustiqIntegration.connect("NetworkService", ["network_updated"], function(event) { ... })
//   RustiqIntegration.get("network", NetworkService.handleUpdate)
//   RustiqIntegration.disconnect("NetworkService")

import QtQuick
import qs.services

QtObject {
    id: root

    readonly property bool connected: RustiqClientService.connected
    readonly property bool daemonAvailable: _daemonAvailable

    property bool _daemonAvailable: false
    property var _serviceSubscriptions: ({})
    property var _pendingInit: false

    Component.onCompleted: {
        _checkDaemon()
    }

    function _checkDaemon() {
        RustiqClientService.ping(function(data, err) {
            _daemonAvailable = !err && data && data.pong
            if (_daemonAvailable) {
                Logger.i("RustiqIntegration", "Daemon connected: " + (data?.version || "unknown"))
                _subscribeAll()
            } else {
                Logger.w("RustiqIntegration", "Daemon unavailable, retrying in 5s...")
                Qt.callLater(function() { _checkDaemon() })
            }
        })
    }

    // Connect a service to Rust events
    function connect(serviceName, eventFilters, handler) {
        if (!_serviceSubscriptions[serviceName]) {
            _serviceSubscriptions[serviceName] = {
                filters: [],
                handler: handler
            }
        }

        var sub = _serviceSubscriptions[serviceName]
        eventFilters.forEach(function(f) {
            if (sub.filters.indexOf(f) === -1) {
                sub.filters.push(f)
            }
        })

        _subscribeAll()

        Logger.d("RustiqIntegration", "Connected service:", serviceName, "filters:", eventFilters)
    }

    // Disconnect a service
    function disconnect(serviceName) {
        delete _serviceSubscriptions[serviceName]
        _subscribeAll()
        Logger.d("RustiqIntegration", "Disconnected service:", serviceName)
    }

    function _subscribeAll() {
        var allFilters = []
        var handlers = []

        for (var serviceName in _serviceSubscriptions) {
            var sub = _serviceSubscriptions[serviceName]
            sub.filters.forEach(function(f) {
                if (allFilters.indexOf(f) === -1) {
                    allFilters.push(f)
                }
            })
            if (sub.handler && handlers.indexOf(sub.handler) === -1) {
                handlers.push(sub.handler)
            }
        }

        if (handlers.length > 0) {
            RustiqClientService.subscribe(allFilters, function(event) {
                for (var serviceName in _serviceSubscriptions) {
                    var sub = _serviceSubscriptions[serviceName]
                    if (sub.handler) {
                        try {
                            sub.handler(event)
                        } catch(e) {
                            console.error("RustiqIntegration handler error for", serviceName, e)
                        }
                    }
                }
            })
        }
    }

    // Unified GET request
    function get(endpoint, callback) {
        RustiqClientService.get("/" + endpoint, callback)
    }

    // Unified POST request
    function post(endpoint, body, callback) {
        RustiqClientService.post("/" + endpoint, body, callback)
    }

    // Convenience: fetch data and call service handler
    function fetch(serviceName, endpoint, handler) {
        get(endpoint, function(data, err) {
            if (err) {
                Logger.e("RustiqIntegration", "Fetch error for", serviceName, ":", err)
            } else if (handler) {
                handler(data)
            }
        })
    }
}
