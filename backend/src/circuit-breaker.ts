export class CircuitBreaker {
  private failures = 0;
  private lastFail = 0;
  private state: "CLOSED" | "OPEN" | "HALF" = "CLOSED";

  constructor(private threshold = 5, private timeout = 10000) {}

  async exec(fn: Function) {
    const now = Date.now();

    if (this.state === "OPEN") {
      if (now - this.lastFail > this.timeout) {
        this.state = "HALF";
      } else {
        throw new Error("Circuit OPEN");
      }
    }

    try {
      const res = await fn();
      this.failures = 0;
      this.state = "CLOSED";
      return res;
    } catch (err) {
      this.failures++;
      this.lastFail = now;

      if (this.failures >= this.threshold) {
        this.state = "OPEN";
      }

      throw err;
    }
  }
}
