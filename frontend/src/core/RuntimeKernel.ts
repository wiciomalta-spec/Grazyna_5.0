export type KernelMode = 'minimal' | 'balanced' | 'turbo' | 'portable' | 'autonomous';

export interface RuntimeSignal {
  environment: 'browser' | 'pwa' | 'embedded' | 'unknown';
  online: boolean;
  cores: number;
  memoryEstimateGB: number;
  touch: boolean;
  reducedMotion: boolean;
  recommendedMode: KernelMode;
}

export class RuntimeKernel {
  profile(): RuntimeSignal {
    const nav = navigator as Navigator & { deviceMemory?: number; standalone?: boolean };
    const online = typeof navigator !== 'undefined' ? navigator.onLine : true;
    const cores = nav.hardwareConcurrency || 2;
    const memoryEstimateGB = nav.deviceMemory || 2;
    const reducedMotion = typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    const touch = typeof window !== 'undefined' && 'ontouchstart' in window;
    const environment: RuntimeSignal['environment'] =
      window.matchMedia?.('(display-mode: standalone)').matches || nav.standalone ? 'pwa' : 'browser';

    return {
      environment,
      online,
      cores,
      memoryEstimateGB,
      touch,
      reducedMotion,
      recommendedMode: this.recommend(memoryEstimateGB, cores, online),
    };
  }

  recommend(memoryEstimateGB: number, cores: number, online: boolean): KernelMode {
    if (!online) return 'portable';
    if (memoryEstimateGB <= 2 || cores <= 2) return 'minimal';
    if (memoryEstimateGB >= 8 && cores >= 8) return 'turbo';
    return 'autonomous';
  }
}

export const runtimeKernel = new RuntimeKernel();
