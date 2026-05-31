export function startChaosEngine() {
  if (process.env.CHAOS !== "true") return;

  console.warn("[CHAOS] ENABLED");

  setInterval(() => {
    const r = Math.random();

    if (r < 0.1) {
      console.error("[CHAOS] random crash");
      process.exit(1);
    }

    if (r < 0.2) {
      console.warn("[CHAOS] event loop block");
      const start = Date.now();
      while (Date.now() - start < 100) {}
    }

    if (r < 0.3) {
      console.warn("[CHAOS] memory spike");
      const arr = [];
      for (let i = 0; i < 1e5; i++) arr.push("x");
    }

  }, 15000);
}
