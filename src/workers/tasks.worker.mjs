import { parentPort } from "node:worker_threads";
import bcrypt from "bcryptjs";

if (!parentPort) {
  throw new Error("Worker requires parentPort");
}

function generateFleetReport(vehicles = [], period = "unknown") {
  const stats = vehicles.reduce(
    (acc, v) => {
      acc.totalMileage += v.mileage || 0;
      acc.totalFuelCost += v.fuelCost || 0;
      const key = v.status || "UNKNOWN";
      acc.byStatus[key] = (acc.byStatus[key] || 0) + 1;
      return acc;
    },
    { totalMileage: 0, totalFuelCost: 0, byStatus: {} }
  );

  return {
    period,
    totalVehicles: vehicles.length,
    totalMileage: stats.totalMileage,
    totalFuelCost: stats.totalFuelCost,
    byStatus: stats.byStatus,
    avgMileage: vehicles.length > 0 ? stats.totalMileage / vehicles.length : 0,
    generatedAt: new Date().toISOString()
  };
}

parentPort.on("message", async (msg) => {
  const { id, type, data } = msg;
  try {
    let result;

    switch (type) {
      case "bcrypt:hash":
        result = await bcrypt.hash(data.password, data.rounds || 12);
        break;

      case "bcrypt:compare":
        result = await bcrypt.compare(data.password, data.hash);
        break;

      case "report:fleet":
        result = generateFleetReport(data.vehicles || [], data.period || "unknown");
        break;

      default:
        throw new Error("Unknown task type: " + type);
    }

    parentPort.postMessage({ id, data: result });
  } catch (err) {
    parentPort.postMessage({ id, error: err?.message || "worker-error" });
  }
});
