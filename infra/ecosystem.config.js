module.exports = {
  apps: [
    {
      name: "GRAZYNA_BACKEND",
      script: "./backend/src/system/GRAZYNA_BACKEND_FIX.ts",
      instances: "max",
      exec_mode: "cluster",
      env: {
        NODE_ENV: "production",
        PORT: 3000
      }
    }
  ]
};
