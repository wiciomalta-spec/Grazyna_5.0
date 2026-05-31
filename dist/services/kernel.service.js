import os from 'os';
class KernelService {
    currentMode = 'balanced';
    getRuntimeProfile() {
        const totalMemoryMB = Math.round(os.totalmem() / 1024 / 1024);
        const freeMemoryMB = Math.round(os.freemem() / 1024 / 1024);
        const cpuCount = os.cpus().length;
        const capabilities = this.detectCapabilities(totalMemoryMB, cpuCount);
        return {
            platform: os.platform(),
            arch: os.arch(),
            cpuCount,
            totalMemoryMB,
            freeMemoryMB,
            nodeVersion: process.version,
            uptimeSec: Math.round(process.uptime()),
            recommendedMode: this.recommendMode(totalMemoryMB, cpuCount),
            capabilities,
        };
    }
    getMode() {
        return this.currentMode;
    }
    adapt(forceMode) {
        const profile = this.getRuntimeProfile();
        this.currentMode = forceMode || profile.recommendedMode;
        return {
            mode: this.currentMode,
            profile,
            strategy: this.getStrategy(this.currentMode),
            tuning: this.getTuning(this.currentMode),
        };
    }
    getBlueprint() {
        return {
            kernel: 'GRAŻYNA Hybrid Kernel',
            philosophy: 'local-first, adaptive, resilient, portable',
            layers: [
                'runtime detection',
                'capability registry',
                'driver fabric',
                'self-healing state',
                'offline-first transport',
                'hybrid UI shell',
            ],
            modes: ['minimal', 'balanced', 'turbo', 'portable', 'autonomous'],
        };
    }
    getDrivers() {
        return [
            { id: 'memory-fabric', class: 'core', portable: true, description: 'Local memory state driver' },
            { id: 'http-bridge', class: 'network', portable: true, description: 'HTTP API transport bridge' },
            { id: 'ws-signal', class: 'realtime', portable: true, description: 'Realtime event synchronization' },
            { id: 'offline-cache', class: 'storage', portable: true, description: 'Cache-first persistence layer' },
            { id: 'profile-scout', class: 'kernel', portable: true, description: 'Environment profiler and tuner' },
        ];
    }
    recommendMode(totalMemoryMB, cpuCount) {
        if (totalMemoryMB < 2048 || cpuCount <= 2)
            return 'minimal';
        if (totalMemoryMB > 8192 && cpuCount >= 8)
            return 'turbo';
        return 'balanced';
    }
    detectCapabilities(totalMemoryMB, cpuCount) {
        const capabilities = ['http-api', 'ws-events', 'typed-runtime', 'driver-fabric'];
        if (totalMemoryMB >= 2048)
            capabilities.push('local-cache');
        if (cpuCount >= 4)
            capabilities.push('parallel-workers');
        if (totalMemoryMB >= 8192)
            capabilities.push('heavy-analytics');
        return capabilities;
    }
    getStrategy(mode) {
        const strategies = {
            minimal: 'Prefer low memory footprint, reduced animation, batched refresh',
            balanced: 'Balanced UX and throughput with safe concurrency',
            turbo: 'High throughput, richer telemetry, aggressive caching',
            portable: 'No-dependency boot path, offline-first compatibility',
            autonomous: 'Adaptive orchestration with environment-aware switching',
        };
        return strategies[mode];
    }
    getTuning(mode) {
        const tuning = {
            minimal: { uiAnimations: false, telemetryIntervalMs: 10000, cache: 'light', workerPool: 1 },
            balanced: { uiAnimations: true, telemetryIntervalMs: 5000, cache: 'standard', workerPool: 2 },
            turbo: { uiAnimations: true, telemetryIntervalMs: 2000, cache: 'aggressive', workerPool: 4 },
            portable: { uiAnimations: false, telemetryIntervalMs: 12000, cache: 'fallback', workerPool: 1 },
            autonomous: { uiAnimations: true, telemetryIntervalMs: 3000, cache: 'adaptive', workerPool: 3 },
        };
        return tuning[mode];
    }
}
export const kernelService = new KernelService();
export default kernelService;
//# sourceMappingURL=kernel.service.js.map