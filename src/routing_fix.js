/* ==== AUTO PATCH: ROUTING FIX ==== */

function applyRoutingFix(app, apiRoutes, register) {

  // ✅ HEALTH
  app.get("/health", (_req, res) => {
    res.status(200).json({
      status: "ok",
      uptime: process.uptime(),
      timestamp: new Date().toISOString()
    });
  });

  // ✅ METRICS
  app.get("/metrics", async (_req, res) => {
    try {
      res.setHeader("Content-Type", register.contentType);
      res.end(await register.metrics());
    } catch {
      res.status(500).send("metrics error");
    }
  });

  // ✅ API ROOT (eliminuje 404 /api)
  app.get("/api", (_req, res) => {
    res.json({
      status: "API READY",
      service: "grazyna-backend"
    });
  });

  // ✅ COMPAT alias (eliminuje 404 /api/system/metrics)
  app.get("/api/system/metrics", (_req, res) => {
    res.redirect("/metrics");
  });

  // ✅ API ROUTER
  app.use("/api", apiRoutes);

  // ✅ ROOT
  app.get("/", (_req, res) => {
    res.json({
      service: "grazyna",
      status: "running"
    });
  });

  // ✅ 404 NA KOŃCU
  app.use((req, res) => {
    res.status(404).json({
      error: "Not found",
      path: req.path
    });
  });
}

module.exports = { applyRoutingFix };
