export interface DriverDescriptor {
    id: string;
    class: 'core' | 'network' | 'realtime' | 'storage' | 'kernel';
    enabled: boolean;
    priority: number;
    portable: boolean;
}
declare class DriverFabricService {
    private drivers;
    list(): DriverDescriptor[];
    enable(id: string): DriverDescriptor[];
    disable(id: string): DriverDescriptor[];
}
export declare const driverFabricService: DriverFabricService;
export default driverFabricService;
//# sourceMappingURL=driver-fabric.service.d.ts.map