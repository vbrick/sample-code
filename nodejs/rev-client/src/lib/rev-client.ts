/**
 * This class is a usable wrapper around the Rev API for use in node.js v12+
 */
import FormData from 'form-data';
import fs from 'fs';
import type { RequestInit } from 'node-fetch';
import fetch, { Headers } from 'node-fetch';
import { Readable } from 'stream';
import { URL } from 'url';
import { RevError } from './rev-error';
import { GroupRequest, SearchGroup, SearchUser, SearchVideo, User, UserRequest, VideoDetails, VideoSearchOptions, VideoStatusResponse, VideoUploadMetadata } from './types';
import { isPlainObject, retry, sanitizeContentType } from './utils';


export interface RevCredentials {
	/** Username of Rev User (for login) - this or apiKey must be specified */
	username?: string
	/** Password of Rev User (for login) - this or secret must be specified */
	password?: string
	/** API Key forRev User (for login) - this or username must be specified */
	apiKey?: string
	/** API Secret for Rev User (for login) - this or password must be specified */
	secret?: string
}
export interface RevClientOptions extends RevCredentials {
	/** URL of Rev account */
	url: string

	/** Logging function - default is log to console */
	log?: (severity: 'debug' | 'info' | 'warn' | 'error', ...args: any[]) => void
}

export interface RevRequestOptions extends Partial<RequestInit> {

}
export interface RevSearchOptions<T> {
	/**
	 * maximum number of search results
	 */
	maxResults?: number
	/**
	 * callback per page
	 */
	onPage?: (items: T[], index: number, total: number) => void
}

export interface VideoUploadOptions extends RevRequestOptions {
	/** if specified don't try to calculate length of video stream */
	useChunkedTransfer?: boolean
	/** specify content type of video */
	contentType?: string
	/** specify filename of video as reported to Rev */
	filename?: string
}


export interface RevResponse<T> {
	statusCode: number
	headers: Headers
	body: T
}


export class RevClient {
	baseUrl: string;
	credentials: RevCredentials;
	session: { token?: string, userId?: string, apiKey?: string, expires?: Date };
	log: RevClientOptions['log'];
	constructor(options: RevClientOptions) {
		const {
			url,
			log = (severity, ...args) => {
				const ts = (new Date()).toJSON().replace('T', ' ').slice(0, -5);
				console.debug(`${ts} REV-CLIENT [${severity}]`, ...args);
			},
			...credentials
		} = options;

		// add logging functionality
		this.log = log;

		// get just the origin of provided url
		const urlObj = new URL(url);
		this.baseUrl = urlObj.origin;


		// make sure login credentials are specified
		if (!(
			(credentials.username && credentials.password) ||
			(credentials.apiKey && credentials.secret)
		)) {
			throw new TypeError('Must specify credentials (username+password or apiKey+secret) to login');
		}

		this.credentials = credentials;

		// used for session management
		this.session = {};
	}
	/**
	 * authenticate with Rev
	 */
	async login() {
		const {
			username,
			password,
			apiKey,
			secret
		} = this.credentials;

		const isUsernameLogin = username && password;

		// make sure the authorization header isn't added
		this.session = {};

		// Rarely the login call will fail on first attempt, therefore this code attempts to login
		// multiple times
		const response = await retry<{token: string, id?: string, expiration: string}>(() => {
			if (isUsernameLogin) {
				return this.post('/api/v2/user/login', {
					username,
					password
				});
			}
			// otherwise login using API key
			return this.post('/api/v2/authenticate', {
				apiKey,
				secret
			});
		}, (err) => {
			// Do not re-attempt logins with invalid user/password - it can lock out the user
			// @ts-ignore
			if ([401, 429].includes(err.status)) {
				return false;
			}
			// otherwise retry logging in
			return true;
		});

		const {
			token,
			id: userId,
			expiration
		} = response;

		// save response data for subsequent requests
		Object.assign(this.session, {
			token,
			expires: new Date(expiration),
			// these are used for logout
			userId,
			apiKey
		});
	}
	async logoff() {
		const {
			userId,
			apiKey
		} = this.session;
		const isUsernameLogin = !!userId;

		try {
			if (isUsernameLogin) {
				await this.post('/api/v2/user/logoff', { userId });
			} else {
				await this.delete(`/api/v2/tokens/${apiKey}`);
			}
		} catch (error) {
			this.log('warn', `Error in logoff, ignoring: ${error}`);
		} finally {
			this.session = {};
		}
	}
	// this should get called every 15 minutes or so to extend the connection session
	async extendSession() {
		const {
			apiKey,
			userId
		} = this.session;

		/** @type {RevResponse<{ expiration: string }>} */
		let response;

		// API Key session
		if (apiKey) {
			response = await this.post(`/api/v2/auth/extend-session-timeout/${apiKey}`);
		} else {
			// username session
			response = await this.post('/api/v2/user/extend-session-timeout', { userId });
		}
		const {
			body: {
				expiration
			}
		} = response;
		this.session.expires = new Date(expiration);
	}
	/**
	 * Returns true/false based on if the session is currently valid
	 * @returns Promise<boolean>
	 */
	async verifySession() {
		try {
			await this.get('/api/v2/user/session');
			return true;
		} catch (err) {
			return false;
		}
	}
	get token() {
		return this.session.token;
	}
	get expires() {
		return this.session.expires;
	}
	/**
	 * check if expiration time of session has passed
	 */
	get isSessionExpired() {
		if (!this.session.expires) {
			return true;
		}
		return Date.now() > this.session.expires.getTime();

	}
	async autoRefreshSession(refreshThresholdMinutes = 3) {
		const timeTillExpiration = this.session.expires
			? this.session.expires.getTime() - Date.now()
			: -1;

		let mustLogin = false;
		let didRefresh = false;
		// login if session expired
		if (timeTillExpiration < 0) {
			mustLogin = true;
		} else if (timeTillExpiration < refreshThresholdMinutes * 60 * 1000) {
		// if within refresh window extend
			try {
				await this.extendSession();
				didRefresh = true;
			} catch (error) {
				this.log('warn', 'Error extending session - re-logging in', error);
				mustLogin = true;
			}
		} else {
			// otherwise check if valid session
			mustLogin = !(await this.verifySession());
		}
		if (mustLogin) {
			await this.login();
			didRefresh = true;
		}
		return didRefresh;
	}
	/**
	 * make a REST request
	 */
	async request<T = any>(method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE' | 'HEAD', endpoint: string, data: any = undefined, options: RevRequestOptions = {}): Promise<RevResponse<T>> {
		const url = new URL(endpoint, this.baseUrl);

		// setup headers for JSON communication (by default)
		const headers = new Headers(options.headers);

		// add authorization header from stored token
		if (this.session.token && !headers.has('Authorization')) {
			headers.set('Authorization', `VBrick ${this.session.token}`);
		}

		const fetchOptions = {
			method,
			...options,
			headers
		};

		// add provided data to request body or as query string parameters

		if (data) {
			if (['POST', 'PUT', 'PATCH'].includes(method.toUpperCase())) {
				if (typeof data === 'string') {
					fetchOptions.body = data;
				} else if (data instanceof FormData) {
					headers.set('content-type', `multipart/form-data; boundary=${data.getBoundary()}`);
					fetchOptions.body = data;
				} else if (isPlainObject(data) || Array.isArray(data)) {
					fetchOptions.body = JSON.stringify(data);
				} else {
					fetchOptions.body = data;
				}
			} else if (isPlainObject(data)) {
				// add values to query string of URL
				for (let [key, value] of Object.entries(data)) {
					url.searchParams.append(key, value);
				}
			} else {
				throw new TypeError(`Invalid payload for request to ${method} ${endpoint}`);
			}
		}

		const JSON_MIMETYPE = 'application/json';

		// default to JSON communication
		if (!headers.has('Accept')) {
			headers.set('Accept', JSON_MIMETYPE);
		}
		if (!headers.has('Content-Type')) {
			headers.set('Content-Type', JSON_MIMETYPE);
		}

		// OPTIONAL log request and response
		this.log('info', `Request ${method} ${endpoint}`);

		// NOTE: will throw error on AbortError or client fetch errors
		const response = await fetch(url, {
			...fetchOptions,
			method,
			headers
		});

		this.log('info', `Response ${method} ${endpoint} ${response.status} ${response.statusText}`);

		// check for error response code
		if (!response.ok) {
			const err = await RevError.create(response);
			throw err;
		}

		// if no mimetype in response then assume JSON unless otherwise specified
		const contentType = response.headers.get('Content-Type') || headers.get('Accept');

		let body: any;

		if (contentType.startsWith('application/json')) {
			try {
				body = await response.json();
			} catch (err) {
				this.log('warn', 'Unable to decode response body', err);
			}
		}

		if (!body) {
			if (contentType.startsWith('text')) {
				body = await response.text();
			} else {
				body = await response.buffer();
			}
		}

		return {
			statusCode: response.status,
			headers: response.headers,
			body
		};
	}
	async get<T = any>(endpoint: string, data?: {[key: string]: any} | Record<string, any> | any[], options?: RevRequestOptions): Promise<T> {
		const { body } = await this.request('GET', endpoint, data, options);
		return body;
	}
	async post<T = any>(endpoint: string, data?: {[key: string]: any} | Record<string, any> | any[], options?: RevRequestOptions): Promise<T> {
		const { body } = await this.request('POST', endpoint, data, options);
		return body;
	}
	async put<T = any>(endpoint: string, data?: {[key: string]: any} | Record<string, any> | any[], options?: RevRequestOptions): Promise<T> {
		const { body } = await this.request('PUT', endpoint, data, options);
		return body;
	}
	async patch(endpoint: string, data?: {[key: string]: any} | Record<string, any> | any[], options?: RevRequestOptions) {
		await this.request('PATCH', endpoint, data, options);
	}
	async delete(endpoint: string, data?: {[key: string]: any} | Record<string, any> | any[], options?: RevRequestOptions) {
		await this.request('DELETE', endpoint, data, options);
	}
	/**
	 * Private helper function for scrolling through Search API results
	 */
	async * _scroll<RawType>(searchOptions: {endpoint: string, totalKey: string, hitsKey: string}, data: Record<string, any>, options: RevSearchOptions<RawType>): AsyncGenerator<RawType> {
		const {
			endpoint,
			totalKey,
			hitsKey
		} = searchOptions;

		const {
			maxResults = Infinity,
			onPage = (items, index, total) => {
				this.log('debug', `searching ${hitsKey}, ${index}-${index + items.length} of ${total}...`);
			}
		} = options;

		const query = { ...data };
		delete query.scrollId;

		let total = maxResults;
		let current = 0;
		// continue until max reached
		while (current < maxResults) {
			const response = await this.get(endpoint, query);
			let {
				scrollId,
				[totalKey]: responseTotal,
				[hitsKey]: items
			} = response;

			query.scrollId = scrollId;
			total = Math.min(responseTotal, maxResults);

			// limit results to specified max results
			if (current + items.length >= maxResults) {
				const delta = current + items.length - maxResults;
				items = items.slice(0, items.length - delta);
			}

			onPage(items, current, total);
			current += items.length;

			for (let item of items) {
				yield item;
			}

			// if no scrollId returned then no more results to page through
			if (!scrollId) {
				return;
			}
		}
	}
	get video() {
		const rev = this;
		const videoAPI = {
			/**
			 * This is an example of using the video Patch API to only update a single field
			 * @param videoId
			 * @param title
			 */
			async setTitle(videoId: string, title: string) {
				const payload = [{ op: 'add', path: '/Title', value: title }];
				await rev.patch(`/api/v2/videos/${videoId}`, payload);
			},
			/**
			 * get processing status of a video
			 * @param videoId
			 */
			async getStatus(videoId: string): Promise<VideoStatusResponse> {
				return rev.get(`/api/v2/videos/${videoId}/status`);
			},
			async details(videoId: string): Promise<VideoDetails> {
				return rev.get(`/api/v2/videos/${videoId}/details`);
			},
			/**
			 * Upload a video, and returns the resulting video ID
			 */
			async upload(
				file: string | Readable,
				metadata: VideoUploadMetadata = {uploader: this.credentials.username},
				options: VideoUploadOptions = {}): Promise<string> {
				const {
					// don't calculate length if set to true
					useChunkedTransfer = false,
					contentType: optMimeType,
					filename: optFilename
				} = options;

				// prepare payload
				const form = new FormData();

				// at bare minimum the uploader needs to be defined
				if (!metadata.uploader) {
					// if using username login then uploader can be set to current user
					const defaultUsername = this.credentials.username;
					if (defaultUsername) {
						metadata.uploader = defaultUsername;
					} else {
						throw new TypeError('metadata must include uploader parameter');
					}
				}

				// add video metadata to body (as json)
				form.append('video', JSON.stringify(metadata));

				// add file to form data as stream
				const fileStream = typeof file === 'string'
					? fs.createReadStream(file)
					: file;

				const {
					filename,
					contentType
				} = sanitizeContentType(optFilename || (fileStream as any).path, optMimeType);

				form.append('VideoFile', fileStream, {
					filename,
					contentType
				});

				// prepare headers from form
				const headers = Object.assign(
					form.getHeaders(),
					options.headers instanceof Headers
						? Object.fromEntries(options.headers)
						: options.headers
				);
				const totalBytes = await new Promise(resolve => {
					if (useChunkedTransfer) {
						resolve(0);
						return;
					}
					form.getLength((err, bytes) => {
						if (err) {
							resolve(0);
						} else {
							resolve(bytes);
						}
					});
				});
				if (totalBytes > 0) {
					headers['content-length'] = totalBytes;
				} else {
					rev.log('debug', 'Using chunked transfer to upload');
					headers['transfer-encoding'] = 'chunked';
					delete headers['content-length'];
				}

				rev.log('info', `Uploading ${typeof file === 'string' ? file : 'stream'} (${totalBytes} bytes)`);

				const { videoId } = await rev.post<{ videoId: string }>('/api/v2/uploads/videos', form, { headers });

				return videoId;
			},
			/**
			 * search for videos. leave blank to get all videos in the account
			 */
			async search(query: VideoSearchOptions = {}, options: RevSearchOptions<SearchVideo> = {}) {
				const searchDefinition = {
					endpoint: '/api/v2/videos/search',
					totalKey: 'totalVideos',
					hitsKey: 'videos'
				};
				const results: SearchVideo[] = [];
				const pager = rev._scroll<SearchVideo>(searchDefinition, query, options);

				for await (const video of pager) {

					results.push(video);
				}
				return results;
			},
			/**
			 * Example of using the video search API to search for videos, then getting
			 * the details of each video
			 * @param query
			 * @param options
			 */
			async * detailsStream(query: VideoSearchOptions = {}, options: RevSearchOptions<SearchVideo> = {}): AsyncGenerator<SearchVideo & (VideoDetails | {error?: Error})> {
				const searchDefinition = {
					endpoint: '/api/v2/videos/search',
					totalKey: 'totalVideos',
					hitsKey: 'videos'
				};
				const pager = rev._scroll<SearchVideo>(searchDefinition, query, options);
				for await (const rawVideo of pager) {
					const out: SearchVideo & (VideoDetails | {error?: Error}) = rawVideo;
					try {
						const details = await videoAPI.details(rawVideo.id);
						Object.assign(out, details);
					} catch (error) {
						out.error = error;
					}
					yield out;
				}
			}
		};
		return videoAPI;
	}
	get user() {
		const rev = this;
		return {
			/**
			 * @description get the list of roles available in the system
			 * @type {() => Promise<Array<{ id: string, name: string, description: string }>>}
			 */
			async roles(): Promise<{ id: string, name: string, description: string}[]> {
				return rev.get('/api/v2/users/roles');
			},
			/**
			 * Create a new User in Rev
			 * @param user
			 * @returns the User ID of the created user
			 */
			async create(user: UserRequest): Promise<string> {
				const { userId } = await rev.post('/api/v2/users', user);
				return userId;
			},
            async details(userId: string) {
                return rev.get<User>(`/api/v2/users/${userId}`);
            },
			/**
			 */
			async getByUsername(username: string) {
				return rev.get<User>(`/api/v2/users/${username}`, { type: 'username' });
			},
			/**
			 */
			async getByEmail(email: string) {
				return rev.get<User>(`/api/v2/users/${email}`, { type: 'email' });
			},
			/**
			 * use PATCH API to add user to the specified group
			 * https://revdocs.vbrick.com/reference#edituserdetails
			 * @param {string} userId id of user in question
			 * @param {string} groupId
			 * @returns {Promise<void>}
			 */
			async addGroup(userId: string, groupId: string) {
				const operations = [
					{ op: 'add', path: '/GroupIds/-', value: groupId }
				];
				await rev.patch(`/api/v2/users/${userId}`, operations);
			},
			/**
			 * use PATCH API to add user to the specified group
			 * https://revdocs.vbrick.com/reference#edituserdetails
			 * @param {string} userId id of user in question
			 * @param {string} groupId
			 * @returns {Promise<void>}
			 */
			async removeGroup(userId: string, groupId: string) {
				const operations = [
					{ op: 'remove', path: '/GroupIds', value: groupId }
				];
				await rev.patch(`/api/v2/users/${userId}`, operations);
			},
			/**
			 * search for users based on text query. Leave blank to return all users.
			 *
			 * @param {string} [searchText]
			 * @param {RevSearchOptions<{Id: string, Name: string}>} [options]
			 */
			async search(searchText?: string, options: RevSearchOptions<SearchUser> = {}) {
				const searchDefinition = {
					endpoint: '/api/v2/search/access-entity',
					totalKey: 'totalEntities',
					hitsKey: 'accessEntities'
				};
				const query: Record<string, any> = { type: 'user' };
				if (searchText) {
					query.q = searchText;
				}
				const results: SearchUser[] = [];
				const pager = rev._scroll<SearchUser>(searchDefinition, query, options);
				for await (const user of pager) {
					results.push(user);
				}
				return results;
			}
		};
	}
	get group() {
		const rev = this;
		const groupAPI = {
			/**
			 * Create a group. Returns the resulting Group ID
			 * @param {{name: string, userIds: string[], roleIds: string[]}} group
			 * @returns {Promise<string>}
			 */
			async create(group: GroupRequest) {
				const { groupId } = await rev.post('/api/v2/groups', group);
				return groupId;
			},
			async delete(groupId: string) {
				await rev.delete(`/api/v2/groups/${groupId}`);
			},
			/**
			 *
			 * @param {string} [searchText]
			 * @param {RevSearchOptions<{Id: string, Name: string}>} [options]
			 */
			async search(searchText: string, options:RevSearchOptions<SearchGroup> = {}) {
				const searchDefinition = {
					endpoint: '/api/v2/search/access-entity',
					totalKey: 'totalEntities',
					hitsKey: 'accessEntities'
				};
				const query: Record<string, any> = { type: 'group' };
				if (searchText) {
					query.q = searchText;
				}
				const results: SearchGroup[] = [];
				const pager = rev._scroll<SearchGroup>(searchDefinition, query, options);
				for await (const rawGroup of pager) {
					results.push(rawGroup);
				}
				return results;
			},
			async list(options: RevSearchOptions<SearchGroup> = {}) {
				return groupAPI.search(undefined, options);
			},
			async listUsers(groupId: string, options:RevSearchOptions<string> = {}) {
				const searchDefinition = {
					endpoint: `/api/v2/search/groups/${groupId}/users`,
					totalKey: 'totalUsers',
					hitsKey: 'userIds'
				};
				const userIds: string[] = [];
				const pager = rev._scroll<string>(searchDefinition, undefined, options);
				for await (const id of pager) {
					userIds.push(id);
				}
				return userIds;
			},
			/**
			 * get all users in a group with full details as a async generator
			 * @param groupId
			 * @param options
			 * @returns
			 */
			async * usersDetailStream(groupId: string, options:(RevSearchOptions<string> & {onError?: (userId: string, error: Error) => void}) = {}): AsyncGenerator<User> {
				const {
					onError = (userId: string, error: Error) => rev.log('warn', `Error getting user details for ${userId}`, error),
					...searchOptions
				} = options
				const searchDefinition = {
					endpoint: `/api/v2/search/groups/${groupId}/users`,
					totalKey: 'totalUsers',
					hitsKey: 'userIds'
				};
				const pager = rev._scroll<string>(searchDefinition, undefined, searchOptions);
				for await (const userId of pager) {
					try {
						const user = await rev.user.details(userId);
						yield user;
					} catch (error) {
						onError(userId, error);
					}
				}
			}
		};
		return groupAPI;
	}
}
