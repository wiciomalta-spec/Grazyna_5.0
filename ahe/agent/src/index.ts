import { detect } from "./capability";

function main() {
  const data = detect();

  console.log("=== AHE AGENT ===");
  console.log(JSON.stringify(data, null, 2));

  console.log("\n[Decision]");
  console.log(`Executor: ${data.recommended}`);

  if (data.recommended === "docker") {
    console.log("→ Użyj Docker runtime (Debian domyślnie)");
  } else if (data.recommended === "wsl") {
    console.log("→ Użyj WSL Linux environment");
  } else {
    console.log("→ Fallback native runtime");
  }
}

main();