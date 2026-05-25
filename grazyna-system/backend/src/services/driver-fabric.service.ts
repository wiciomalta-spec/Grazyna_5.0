export interface DriverDescriptor {
  id: string;
  class: 'core' | 'network' | 'realtime' | 'storage' | 'kernel';
  enabled: boolean;
  priority: number;
  portable: boolean;
}

class DriverFabricService {
  private drivers: DriverDescriptor[] = [
    { id: 'memory-fabric', class: 'core', enabled: true, priority: 100, portable: true },
    { id: 'http-bridge', class: 'network', enabled: true, priority: 90, portable: true },
    { id: 'ws-signal', class: 'realtime', enabled: true, priority: 80, portable: true },
    { id: 'offline-cache', class: 'storage', enabled: true, priority: 85, portable: true },
    { id: 'profile-scout', class: 'kernel', enabled: true, priority: 95, portable: true },
  ];

  list() {
    return this.drivers.sort((a, b) => b.priority - a.priority);
  }

  enable(id: string) {
    this.drivers = this.drivers.map((driver) => driver.id === id ? { ...driver, enabled: true } : driver);
    return this.list();
  }

  disable(id: string) {
    this.drivers = this.drivers.map((driver) => driver.id === id ? { ...driver, enabled: false } : driver);
    return this.list();
  }
}

export const driverFabricService = new DriverFabricService();
export default driverFabricService;
