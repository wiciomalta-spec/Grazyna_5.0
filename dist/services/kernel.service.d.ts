export type KernelMode = 'minimal' | 'balanced' | 'turbo' | 'portable' | 'autonomous';
export interface RuntimeProfile {
    platform: string;
    arch: string;
    cpuCount: number;
    totalMemoryMB: number;
    freeMemoryMB: number;
    nodeVersion: string;
    uptimeSec: number;
    recommendedMode: KernelMode;
    capabilities: string[];
}
declare class KernelService {
    private currentMode;
    getRuntimeProfile(): RuntimeProfile;
    getMode(): KernelMode;
    adapt(forceMode?: KernelMode): {
        mode: KernelMode;
        profile: RuntimeProfile;
        strategy: string;
        tuning: Record<string, string | number | boolean>;
    };
    getBlueprint(): {
        kernel: string;
        philosophy: string;
        layers: string[];
        modes: string[];
    };
    getDrivers(): {
        id: string;
        class: string;
        portable: boolean;
        description: string;
    }[];
    private recommendMode;
    private detectCapabilities;
    private getStrategy;
    private getTuning;
}
export declare const kernelService: KernelService;
export default kernelService;
//# sourceMappingURL=kernel.service.d.ts.map