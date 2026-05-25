export interface CapabilityItem {
  id: string;
  enabled: boolean;
  source: 'browser' | 'backend' | 'fallback';
  description: string;
}

class CapabilityRegistry {
  private capabilities: CapabilityItem[] = [
    { id: 'offline-cache', enabled: true, source: 'browser', description: 'Lokalny cache aplikacji' },
    { id: 'adaptive-shell', enabled: true, source: 'browser', description: 'Adaptacja UI do środowiska' },
    { id: 'realtime-sync', enabled: true, source: 'backend', description: 'Synchronizacja przez WebSocket' },
    { id: 'portable-mode', enabled: true, source: 'fallback', description: 'Tryb awaryjny bez zależności zewnętrznych' },
    { id: 'self-profile', enabled: true, source: 'browser', description: 'Samodiagnoza wydajności' },
  ];

  list() {
    return this.capabilities;
  }

  setEnabled(id: string, enabled: boolean) {
    this.capabilities = this.capabilities.map((item) => item.id === id ? { ...item, enabled } : item);
  }
}

export const capabilityRegistry = new CapabilityRegistry();
export default capabilityRegistry;
