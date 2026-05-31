import { Request, Response } from 'express';
export declare const login: (req: Request, res: Response) => Promise<void>;
export declare const register: (req: Request, res: Response) => Promise<void>;
export declare const me: (req: Request & {
    user?: any;
}, res: Response) => Promise<void>;
//# sourceMappingURL=auth.controller.d.ts.map