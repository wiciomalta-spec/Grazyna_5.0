import os from "node:os";
import { execSync } from "node:child_process";

function cmd(c: string): string | null {
  try {
    return execSync(c).toString().trim();
  } catch {
    return null;
  }
}

export function detect() {
  const platform = process.platform;
  const release = os.release();
  const arch = process.arch;

  const hasDocker = !!cmd("docker version");
  const hasWSL = !!process.env.WSL_DISTRO_NAME;

  let executor = "native";

  if (hasDocker) executor = "docker";
  else if (hasWSL) executor = "wsl";

  return {
    system: {
      platform,
      release,
      arch
    },
    features: {
      docker: hasDocker,
      wsl: hasWSL
    },
    recommended: executor
  };
}