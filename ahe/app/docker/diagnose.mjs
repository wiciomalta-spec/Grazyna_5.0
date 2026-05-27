const { execSync } = require("child_process");

function tryCmd(cmd) {
  try {
    return execSync(cmd).toString().trim();
  } catch {
    return "missing";
  }
}

const report = {
  node: process.version,
  arch: process.arch,
  platform: process.platform,
  openssl: tryCmd("openssl version"),
};

console.log("[AHE DIAG]", JSON.stringify(report, null, 2));
