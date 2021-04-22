"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.RevError = void 0;
const utils_1 = require("./utils");
class RevError extends Error {
    constructor(response, body) {
        const { status = 500, statusText = '', url } = response;
        super(`${status} ${statusText}`);
        Error.captureStackTrace(this, this.constructor);
        this.status = status;
        this.url = url;
        this.code = `${status}`;
        this.detail = statusText;
        // Some Rev API responses include additional details in its body
        if (utils_1.isPlainObject(body)) {
            if (body.code) {
                this.code = body.code;
            }
            if (body.detail) {
                this.detail = body.detail;
            }
        }
        else if (typeof body === 'string' && /^(<!DOCTYPE|<html)/.test(body)) {
            // if html then strip out the extra cruft
            if (this.status === 429) {
                this.detail = 'Too Many Requests';
            }
            else {
                this.detail = body
                    .replace(/.*<body>\s+/s, '')
                    .replace(/<\/body>.*/s, '')
                    .slice(0, 256);
            }
        }
    }
    get name() {
        return this.constructor.name;
    }
    get [Symbol.toStringTag]() {
        return this.constructor.name;
    }
    static async create(response) {
        const { headers } = response;
        let body;
        const contentType = headers.get('Content-Type') || '';
        try {
            body = contentType.startsWith('application/json')
                ? await response.json()
                : await response.text();
        }
        catch (err) {
            body = {
                code: 'Unknown',
                detail: `Unable to parse error response body: ${err}`
            };
        }
        return new RevError(response, body);
    }
}
exports.RevError = RevError;
//# sourceMappingURL=rev-error.js.map