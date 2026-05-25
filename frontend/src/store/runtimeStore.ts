import { create } from 'zustand';
import { runtimeKernel, type KernelMode, type RuntimeSignal } from '../core/RuntimeKernel';

interface RuntimeState {
  signal: RuntimeSignal;
  mode: KernelMode;
  refresh: () => void;
  setMode: (mode: KernelMode) => void;
}

const initial = runtimeKernel.profile();

export const useRuntimeStore = create<RuntimeState>((set) => ({
  signal: initial,
  mode: initial.recommendedMode,
  refresh: () => {
    const next = runtimeKernel.profile();
    set({ signal: next, mode: next.recommendedMode });
  },
  setMode: (mode) => set({ mode }),
}));
