/**
 * GRAŻYNA 5.0 - Backend Server
 * Express + Socket.IO + Prisma + JWT
 */
import { Server } from 'socket.io';
declare const app: import("express-serve-static-core").Express;
declare const io: Server<import("socket.io").DefaultEventsMap, import("socket.io").DefaultEventsMap, import("socket.io").DefaultEventsMap, any>;
export { app, io };
//# sourceMappingURL=index.d.ts.map