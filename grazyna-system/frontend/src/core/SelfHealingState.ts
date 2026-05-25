type StateRecord = Record<string, unknown>;

class SelfHealingState {
  private namespace = 'grazyna-recovery';

  save(snapshot: StateRecord) {
    localStorage.setItem(this.namespace, JSON.stringify({ snapshot, updatedAt: Date.now() }));
  }

  restore<T extends StateRecord>(): T | null {
    const raw = localStorage.getItem(this.namespace);
    if (!raw) return null;
    try {
      return JSON.parse(raw).snapshot as T;
    } catch {
      localStorage.removeItem(this.namespace);
      return null;
    }
  }

  clear() {
    localStorage.removeItem(this.namespace);
  }
}

export const selfHealingState = new SelfHealingState();
export default selfHealingState;
