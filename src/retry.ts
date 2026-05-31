export async function retry(fn: Function, retries = 3, delay = 100) {
  let last;

  for (let i = 0; i < retries; i++) {
    try {
      return await fn();
    } catch (err) {
      last = err;
      await new Promise(r => setTimeout(r, delay * (i + 1)));
    }
  }

  throw last;
}
