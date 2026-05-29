declare global {
  // eslint-disable-next-line no-var
  var prisma: any | undefined;
}

let prisma: any = undefined;

try {
  // Try to dynamically import @prisma/client (may not be generated in some environments)
  // Use top-level await (ES2022) so this file can gracefully fallback when prisma client is missing
  const mod = await import('@prisma/client').catch(() => null);
  if (mod && mod.PrismaClient) {
    const PrismaClient = mod.PrismaClient;
    prisma = global.prisma || new PrismaClient({
      log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
    });
    if (process.env.NODE_ENV !== 'production') {
      global.prisma = prisma;
    }
  } else {
    throw new Error('prisma client not available');
  }
} catch (err) {
  console.warn('Prisma client not available; using fallback in-memory stub.');
  prisma = {
    $disconnect: async () => { },
    user: { findUnique: async () => null },
    vehicle: { findMany: async () => [] },
  };
}

export { prisma };
export default prisma;
