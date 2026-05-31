import client from "prom-client";
export declare const register: client.Registry;
export declare const httpRequests: client.Counter<"status" | "route" | "method">;
export declare const httpRequestDuration: client.Histogram<"status" | "route" | "method">;
export declare const httpErrors: client.Counter<"status" | "route" | "method">;
export declare const workerGauge: client.Gauge<string>;
//# sourceMappingURL=metrics.d.ts.map