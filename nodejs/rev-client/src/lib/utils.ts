import path from 'path';

const {
	toString: _toString
} = Object.prototype;

export function isPlainObject(val: unknown): val is ({[key: string]: any} | any[]) {
	if (_toString.call(val) !== '[object Object]') {
		return false;
	}
	const prototype = Object.getPrototypeOf(val);
	return prototype === null || prototype === Object.getPrototypeOf({});
}

/**
 * Retry a function multiple times, sleeping before attempts
 * @param {() => Promise<T>} fn function to attempt. Return value if no error thrown
 * @param {(err: Error, attempt: number) => boolean} [shouldRetry] callback on error.
 * @param {number} [maxAttempts] maximum number of retry attempts before throwing error
 * @param {number} [sleepMilliseconds] milliseconds to wait between attempts
 * @returns {Promise<T>}
 */
export async function retry<T>(fn: () => Promise<T>, shouldRetry: (err: Error, attempt: number) => boolean = () => true, maxAttempts: number = 3, sleepMilliseconds: number = 1000) {
	let attempt = 0;
	while (attempt < maxAttempts) {
		try {
			const result = await fn();
			return result;
		} catch (err) {
			attempt += 1;
			if (attempt >= maxAttempts || !shouldRetry(err, attempt)) {
				throw err;
			}
			await sleep(sleepMilliseconds);
		}
	}
}

export async function sleep(ms: number) {
	return new Promise(done => setTimeout(done, ms));
}

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

export function getMimeForExtension(extension: string = '', defaultType = 'video/mp4') {
	extension = extension.toLowerCase();
	if (extension && (extension in mimeTypes)) {
		return mimeTypes[extension as keyof typeof mimeTypes];
	}
	return defaultType;
}

export function getExtensionForMime(contentType: string, defaultExtension = 'mp4') {
	const match = contentType && Object.entries(mimeTypes)
		.find(([ext, mime]) => contentType.startsWith((mime)));
	return match
		? match[0]
		: defaultExtension;

}

export function sanitizeContentType(filename: string = 'video', contentType: string = '') {
	// sanitize content type
	if (contentType === 'application/octet-stream') {
		contentType = '';
	}
	if (/charset/.test(contentType)) {
		contentType = contentType.replace(/;?.*charset.*$/, '');
	}
	let {name, ext} = path.parse(filename);
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
