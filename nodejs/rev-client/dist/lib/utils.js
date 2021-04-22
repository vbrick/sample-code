"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.sanitizeContentType = exports.getExtensionForMime = exports.getMimeForExtension = exports.sleep = exports.retry = exports.isPlainObject = void 0;
const path_1 = __importDefault(require("path"));
const { toString: _toString } = Object.prototype;
function isPlainObject(val) {
    if (_toString.call(val) !== '[object Object]') {
        return false;
    }
    const prototype = Object.getPrototypeOf(val);
    return prototype === null || prototype === Object.getPrototypeOf({});
}
exports.isPlainObject = isPlainObject;
/**
 * Retry a function multiple times, sleeping before attempts
 * @param {() => Promise<T>} fn function to attempt. Return value if no error thrown
 * @param {(err: Error, attempt: number) => boolean} [shouldRetry] callback on error.
 * @param {number} [maxAttempts] maximum number of retry attempts before throwing error
 * @param {number} [sleepMilliseconds] milliseconds to wait between attempts
 * @returns {Promise<T>}
 */
async function retry(fn, shouldRetry = () => true, maxAttempts = 3, sleepMilliseconds = 1000) {
    let attempt = 0;
    while (attempt < maxAttempts) {
        try {
            const result = await fn();
            return result;
        }
        catch (err) {
            attempt += 1;
            if (attempt >= maxAttempts || !shouldRetry(err, attempt)) {
                throw err;
            }
            await sleep(sleepMilliseconds);
        }
    }
}
exports.retry = retry;
async function sleep(ms) {
    return new Promise(done => setTimeout(done, ms));
}
exports.sleep = sleep;
const mimeTypes = {
    '.7z': 'application/x-7z-compressed',
    '.asf': 'video/x-ms-asf',
    '.avi': 'video/x-msvideo',
    '.csv': 'text/csv',
    '.doc': 'application/msword',
    '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.f4v': 'video/x-f4v',
    '.flv': 'video/x-flv',
    '.gif': 'image/gif',
    '.jpg': 'image/jpeg',
    '.m4a': 'audio/mp4',
    '.m4v': 'video/x-m4v',
    '.mkv': 'video/x-matroska',
    '.mov': 'video/quicktime',
    '.mp3': 'audio/mpeg',
    '.mp4': 'video/mp4',
    '.mpg': 'video/mpeg',
    '.pdf': 'application/pdf',
    '.png': 'image/png',
    '.ppt': 'application/vnd.ms-powerpoint',
    '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    '.rar': 'application/x-rar-compressed',
    '.srt': 'application/x-subrip',
    '.svg': 'image/svg+xml',
    '.swf': 'application/x-shockwave-flash',
    '.ts': 'video/mp2t',
    '.txt': 'text/plain',
    '.wmv': 'video/x-ms-wmv',
    '.xls': 'application/vnd.ms-excel',
    '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    '.zip': 'application/zip',
    '.mks': 'video/x-matroska',
    '.mts': 'model/vnd.mts',
    '.wma': 'audio/x-ms-wma'
};
function getMimeForExtension(extension = '', defaultType = 'video/mp4') {
    extension = extension.toLowerCase();
    if (extension && (extension in mimeTypes)) {
        return mimeTypes[extension];
    }
    return defaultType;
}
exports.getMimeForExtension = getMimeForExtension;
function getExtensionForMime(contentType, defaultExtension = 'mp4') {
    const match = contentType && Object.entries(mimeTypes)
        .find(([ext, mime]) => contentType.startsWith((mime)));
    return match
        ? match[0]
        : defaultExtension;
}
exports.getExtensionForMime = getExtensionForMime;
function sanitizeContentType(filename = 'video', contentType = '') {
    // sanitize content type
    if (contentType === 'application/octet-stream') {
        contentType = '';
    }
    if (/charset/.test(contentType)) {
        contentType = contentType.replace(/;?.*charset.*$/, '');
    }
    let { name, ext } = path_1.default.parse(filename);
    if (!ext) {
        ext = getExtensionForMime(contentType);
    }
    filename = `${name}${ext}`;
    if (!contentType) {
        contentType = getMimeForExtension(ext);
    }
    return {
        filename,
        contentType
    };
}
exports.sanitizeContentType = sanitizeContentType;
//# sourceMappingURL=utils.js.map