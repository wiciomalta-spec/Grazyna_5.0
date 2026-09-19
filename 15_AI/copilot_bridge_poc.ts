export type Intent =
  | "READ_VIN"
  | "READ_ECU_FULL"
  | "READ_IMMO_STATUS"
  | "PLAN_IMMO_RESET"
  | "EXECUTE_IMMO_RESET"
  | "UNKNOWN";

export class CopilotBridge {
  classify(message: string): Intent {
    const t = message.toLowerCase();
    if (/(vin).*(read|show|get|odczyt|pokaż)/.test(t)) return "READ_VIN";
    if (/(ecu|sterownik).*(full|read|odczyt|pełn)/.test(t)) return "READ_ECU_FULL";
    if (/(immo|immobiliz).*(status|stan|read|odczyt)/.test(t)) return "READ_IMMO_STATUS";
    if (/(plan|zaplan).*(reset).*(immo|immobiliz)/.test(t)) return "PLAN_IMMO_RESET";
    if (/(execute|wykon|reset).*(immo|immobiliz)/.test(t)) return "EXECUTE_IMMO_RESET";
    return "UNKNOWN";
  }

  policy(intent: Intent) {
    if (intent === "EXECUTE_IMMO_RESET") {
      return { allowed: false, status: "POLICY_REQUIRES_EXPLICIT_GATES", writePerformed: false };
    }
    return { allowed: intent !== "UNKNOWN", status: intent === "UNKNOWN" ? "UNKNOWN_INTENT" : "ALLOW_READ_OR_PLAN" };
  }

  handle(message: string) {
    const intent = this.classify(message);
    return { intent, policy: this.policy(intent) };
  }
}
