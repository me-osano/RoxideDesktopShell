// SysmonService — System monitoring via Rust daemon IPC
// Fetches data from rustiq daemon (GET /sysmon, GET /sysmon/processes)
// Similar architecture to dgopService from DankMaterialShell

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    // Component registration - only poll when something needs sysmon data
    function registerComponent(componentId) {
        root._registered[componentId] = true;
        root._registered = Object.assign({}, root._registered);
        Logger.d("Sysmon", "Component registered:", componentId, "- total:", root._registeredCount);
    }

    function unregisterComponent(componentId) {
        delete root._registered[componentId];
        root._registered = Object.assign({}, root._registered);
        Logger.d("Sysmon", "Component unregistered:", componentId, "- total:", root._registeredCount);
    }

    property var _registered: ({})
    readonly property int _registeredCount: Object.keys(_registered).length
    readonly property bool _lockScreenActive: PanelService.lockScreen?.active ?? false
    readonly property bool shouldRun: _registeredCount > 0 && !_lockScreenActive && root.daemonAvailable

    // Daemon availability
    property bool daemonAvailable: false
    property bool _daemonChecking: false

    // Update intervals (faster when more components registered)
    property int updateInterval: root.shouldRun ? (root._registeredCount > 5 ? 1000 : 2000) : 30000
    property int processesUpdateInterval: root.shouldRun ? 5000 : 30000

    // CPU properties
    property real cpuUsage: 0
    property real cpuFrequency: 0
    property string cpuModel: ""
    property int cpuCores: 1
    property var perCoreCpuUsage: []

    // Memory properties
    property real memoryUsage: 0
    property real totalMemoryMB: 0
    property real usedMemoryMB: 0
    property real availableMemoryMB: 0
    property int totalMemoryKB: 0
    property int usedMemoryKB: 0
    property int totalSwapKB: 0
    property int usedSwapKB: 0
    property real swapPercent: 0

    // Network properties
    property real networkRxRate: 0
    property real networkTxRate: 0
    property var networkInterfaces: []
    property var lastNetworkStats: null

    // Disk properties
    property var disks: []
    property var diskPercents: ({})
    property var diskAvailableGb: ({})
    property var diskUsedGb: ({})
    property var diskSizeGb: ({})

    // Process properties
    property var processes: []
    property var allProcesses: []
    property int processCount: 0
    property int runningProcesses: 0
    property int sleepingProcesses: 0
    property string currentSort: "cpu"
    property bool sortAscending: false

    // System properties
    property real loadAvg1: 0
    property real loadAvg5: 0
    property real loadAvg15: 0
    property int uptimeSecs: 0
    property string uptime: ""
    property string shortUptime: ""

    // History arrays
    property int historySize: 60
    property var cpuHistory: []
    property var memoryHistory: []
    property var networkRxHistory: []
    property var networkTxHistory: []

    // Internal state for network speed calculation
    property real prevRxBytes: 0
    property real prevTxBytes: 0
    property real prevTime: 0

    // Process limits
    property int processLimit: 20

    // -------------------------------------------------------
    // Initialize
    Component.onCompleted: {
        Logger.i("Sysmon", "Service started");
        _checkDaemon();
    }

    onShouldRunChanged: {
        if (shouldRun) {
            _checkDaemon();
        }
    }

    // Check daemon availability
    function _checkDaemon() {
        if (_daemonChecking) return;
        _daemonChecking = true;
        
        RustiqClientService.ping(function(data, err) {
            _daemonChecking = false;
            root.daemonAvailable = (err === null && data !== null);
            if (root.daemonAvailable) {
                Logger.i("Sysmon", "Daemon connected");
                _fetchSysmon();
                _fetchProcesses();
            } else {
                Logger.w("Sysmon", "Daemon not available:", err || "no response");
            }
        });
    }

    // -------------------------------------------------------
    // Timer for sysmon updates
    Timer {
        id: sysmonTimer
        interval: root.updateInterval
        repeat: true
        running: root.shouldRun && root.daemonAvailable
        triggeredOnStart: true
        onTriggered: _fetchSysmon()
    }

    // Timer for process updates (slower)
    Timer {
        id: processTimer
        interval: root.processesUpdateInterval
        repeat: true
        running: root.shouldRun && root.daemonAvailable
        triggeredOnStart: true
        onTriggered: _fetchProcesses()
    }

    // -------------------------------------------------------
    // Fetch sysmon data from daemon
    function _fetchSysmon() {
        RustiqClientService.get("/sysmon", function(data, err) {
            if (err) {
                Logger.w("Sysmon", "Failed to fetch sysmon:", err);
                if (err.indexOf("http") === 0) {
                    root.daemonAvailable = false;
                    _checkDaemon();
                }
                return;
            }

            if (!data) return;

            // CPU
            if (data.cpu) {
                root.cpuUsage = data.cpu.usage_percent || 0;
                root.cpuFrequency = data.cpu.freq_mhz || 0;
                root.cpuModel = data.cpu.brand || "";
                root.cpuCores = data.cpu.core_count || 1;
                root.perCoreCpuUsage = data.cpu.per_core || [];
                _addToHistory(cpuHistory, root.cpuUsage);
            }

            // Memory
            if (data.memory) {
                const mem = data.memory;
                root.totalMemoryKB = mem.total_kb || 0;
                root.totalMemoryMB = Math.round(root.totalMemoryKB / 1024);
                root.usedMemoryKB = mem.used_kb || 0;
                root.usedMemoryMB = Math.round(root.usedMemoryKB / 1024);
                root.availableMemoryMB = Math.round((mem.available_kb || 0) / 1024);
                root.memoryUsage = mem.used_percent || 0;
                root.totalSwapKB = mem.swap_total_kb || 0;
                root.usedSwapKB = mem.swap_used_kb || 0;
                root.swapPercent = root.totalSwapKB > 0 ? (root.usedSwapKB / root.totalSwapKB) * 100 : 0;
                _addToHistory(memoryHistory, root.memoryUsage);
            }

            // Network
            if (data.network && Array.isArray(data.network)) {
                root.networkInterfaces = data.network;
                let totalRx = 0;
                let totalTx = 0;
                for (const iface of data.network) {
                    totalRx += iface.rx_rate_bps || 0;
                    totalTx += iface.tx_rate_bps || 0;
                }
                root.networkRxRate = totalRx;
                root.networkTxRate = totalTx;
                _addToHistory(networkRxHistory, root.networkRxRate / 1024);
                _addToHistory(networkTxHistory, root.networkTxRate / 1024);
            }

            // Disks
            if (data.disks && Array.isArray(data.disks)) {
                root.disks = data.disks;
                const newPercents = {};
                const newAvailGb = {};
                const newUsedGb = {};
                const newSizeGb = {};
                for (const disk of data.disks) {
                    newPercents[disk.mount] = disk.used_percent || 0;
                    newAvailGb[disk.mount] = Math.round((disk.total_kb - disk.used_kb) / 1024 / 1024);
                    newUsedGb[disk.mount] = Math.round(disk.used_kb / 1024 / 1024);
                    newSizeGb[disk.mount] = Math.round(disk.total_kb / 1024 / 1024);
                }
                root.diskPercents = newPercents;
                root.diskAvailableGb = newAvailGb;
                root.diskUsedGb = newUsedGb;
                root.diskSizeGb = newSizeGb;
            }

            // System
            root.uptimeSecs = data.uptime_secs || 0;
            root.loadAvg1 = data.load_avg[0] || 0;
            root.loadAvg5 = data.load_avg[1] || 0;
            root.loadAvg15 = data.load_avg[2] || 0;
            _updateUptime();

            // Processes (top 20 from main sysmon)
            if (data.processes && Array.isArray(data.processes)) {
                root.processes = data.processes.slice(0, root.processLimit);
                root.processCount = data.processes.length + 100; // Approximate
            }
        });
    }

    // -------------------------------------------------------
    // Fetch detailed process list
    function _fetchProcesses() {
        RustiqClientService.get("/sysmon/processes", function(data, err) {
            if (err) {
                Logger.w("Sysmon", "Failed to fetch processes:", err);
                return;
            }

            if (!data) return;

            root.allProcesses = data.processes || [];
            root.processCount = data.total || 0;
            root.runningProcesses = data.running || 0;
            root.sleepingProcesses = data.sleeping || 0;
            
            _applySorting();
        });
    }

    // -------------------------------------------------------
    // History management
    function _addToHistory(array, value) {
        array.push(value);
        if (array.length > historySize) {
            array.shift();
        }
    }

    // -------------------------------------------------------
    // Uptime formatting
    function _updateUptime() {
        if (root.uptimeSecs <= 0) {
            root.uptime = "";
            root.shortUptime = "";
            return;
        }

        const days = Math.floor(root.uptimeSecs / 86400);
        const hours = Math.floor((root.uptimeSecs % 86400) / 3600);
        const minutes = Math.floor((root.uptimeSecs % 3600) / 60);

        const parts = [];
        if (days > 0) parts.push(`${days}d`);
        if (hours > 0) parts.push(`${hours}h`);
        if (minutes > 0) parts.push(`${minutes}m`);

        root.uptime = parts.length > 0 ? "up " + parts.join(" ") : "up < 1m";
        root.shortUptime = root.uptime;
    }

    // -------------------------------------------------------
    // Sorting
    function setSortBy(newSortBy) {
        if (newSortBy !== root.currentSort) {
            root.currentSort = newSortBy;
            root.sortAscending = false;
            _applySorting();
        }
    }

    function _applySorting() {
        if (!root.allProcesses || root.allProcesses.length === 0) return;

        const asc = root.sortAscending;
        const sorted = root.allProcesses.slice();
        sorted.sort((a, b) => {
            let valueA, valueB, result;
            switch (root.currentSort) {
            case "cpu":
                valueA = a.cpu_percent || 0;
                valueB = b.cpu_percent || 0;
                result = valueB - valueA;
                break;
            case "memory":
                valueA = a.mem_kb || 0;
                valueB = b.mem_kb || 0;
                result = valueB - valueA;
                break;
            case "name":
                valueA = (a.name || "").toLowerCase();
                valueB = (b.name || "").toLowerCase();
                result = valueA.localeCompare(valueB);
                break;
            case "pid":
                valueA = a.pid || 0;
                valueB = b.pid || 0;
                result = valueA - valueB;
                break;
            default:
                return 0;
            }
            return asc ? -result : result;
        });

        root.processes = sorted.slice(0, root.processLimit);
    }

    // -------------------------------------------------------
    // Formatters
    function formatCpuUsage(cpu) {
        return (cpu || 0).toFixed(1) + "%";
    }

    function formatMemory(memoryKB) {
        const mem = memoryKB || 0;
        if (mem < 1024) return mem + " KB";
        if (mem < 1024 * 1024) return (mem / 1024).toFixed(1) + " MB";
        return (mem / (1024 * 1024)).toFixed(1) + " GB";
    }

    function formatSpeed(bytesPerSecond) {
        if (bytesPerSecond <= 0) return "0 B/s";
        const units = ["B/s", "KB/s", "MB/s", "GB/s"];
        let value = bytesPerSecond;
        let unitIndex = 0;
        while (value >= 1024 && unitIndex < units.length - 1) {
            value /= 1024;
            unitIndex++;
        }
        return value.toFixed(1) + " " + units[unitIndex];
    }

    function formatCompactSpeed(bytesPerSecond) {
        if (bytesPerSecond <= 0) return "0";
        const units = ["", "K", "M", "G"];
        let value = bytesPerSecond;
        let unitIndex = 0;
        while (value >= 1024 && unitIndex < units.length - 1) {
            value /= 1024;
            unitIndex++;
        }
        return Math.round(value) + units[unitIndex];
    }

    function formatGigabytes(gb) {
        if (gb < 10) return gb.toFixed(1) + "G";
        return Math.round(gb) + "G";
    }

    function formatPercentage(value) {
        return Math.round(value || 0) + "%";
    }

    function getProcessIcon(command) {
        if (!command) return "memory";
        const cmd = command.toLowerCase();
        if (cmd.includes("firefox") || cmd.includes("chrome") || cmd.includes("chromium")) return "web";
        if (cmd.includes("code") || cmd.includes("editor") || cmd.includes("vim")) return "code";
        if (cmd.includes("terminal") || cmd.includes("bash") || cmd.includes("zsh")) return "terminal";
        if (cmd.includes("music") || cmd.includes("audio") || cmd.includes("spotify")) return "music_note";
        if (cmd.includes("video") || cmd.includes("vlc") || cmd.includes("mpv")) return "play_circle";
        if (cmd.includes("systemd") || cmd.includes("kernel") || cmd.includes("kthread") || cmd.includes("kworker")) return "settings";
        return "memory";
    }

    function killProcess(pid) {
        if (pid > 0) {
            Quickshell.execDetached("kill", [pid.toString()]);
        }
    }

    // -------------------------------------------------------
    // Component references
    // Allow other services to register for sysmon data
    property var moduleRefCounts: ({})

    function addRef(modules = null) {
        if (modules) {
            const modulesToAdd = Array.isArray(modules) ? modules : [modules];
            for (const module of modulesToAdd) {
                const currentCount = moduleRefCounts[module] || 0;
                moduleRefCounts[module] = currentCount + 1;
            }
            moduleRefCounts = Object.assign({}, moduleRefCounts);
        }
    }

    function removeRef(modules = null) {
        if (modules) {
            const modulesToRemove = Array.isArray(modules) ? modules : [modules];
            for (const module of modulesToRemove) {
                const currentCount = moduleRefCounts[module] || 0;
                if (currentCount > 1) {
                    moduleRefCounts[module] = currentCount - 1;
                } else if (currentCount === 1) {
                    delete moduleRefCounts[module];
                }
            }
            moduleRefCounts = Object.assign({}, moduleRefCounts);
        }
    }
}