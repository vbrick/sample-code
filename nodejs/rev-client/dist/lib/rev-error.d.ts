import type { Response } from 'node-fetch';
export declare class RevError extends Error {
    status: number;
    url: string;
    code: string;
    detail: string;
    constructor(response: Response, body: {
        [key: string]: any;
    } | string);
    get name(): string;
    get [Symbol.toStringTag](): string;
    static create(response: Response): Promise<RevError>;
}
//# sourceMappingURL=rev-error.d.ts.map