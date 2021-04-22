export declare function isPlainObject(val: unknown): val is ({
    [key: string]: any;
} | any[]);
/**
 * Retry a function multiple times, sleeping before attempts
 * @param {() => Promise<T>} fn function to attempt. Return value if no error thrown
 * @param {(err: Error, attempt: number) => boolean} [shouldRetry] callback on error.
 * @param {number} [maxAttempts] maximum number of retry attempts before throwing error
 * @param {number} [sleepMilliseconds] milliseconds to wait between attempts
 * @returns {Promise<T>}
 */
export declare function retry<T>(fn: () => Promise<T>, shouldRetry?: (err: Error, attempt: number) => boolean, maxAttempts?: number, sleepMilliseconds?: number): Promise<T>;
export declare function sleep(ms: number): Promise<unknown>;
export declare function getMimeForExtension(extension?: string, defaultType?: string): string;
export declare function getExtensionForMime(contentType: string, defaultExtension?: string): string;
export declare function sanitizeContentType(filename?: string, contentType?: string): {
    filename: string;
    contentType: string;
};
//# sourceMappingURL=utils.d.ts.map