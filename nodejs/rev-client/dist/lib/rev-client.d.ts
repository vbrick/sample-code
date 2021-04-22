import type { RequestInit } from 'node-fetch';
import { Headers } from 'node-fetch';
import { Readable } from 'stream';
import { GroupRequest, SearchGroup, SearchUser, SearchVideo, User, UserRequest, VideoDetails, VideoSearchOptions, VideoStatusResponse, VideoUploadMetadata } from './types';
export interface RevCredentials {
    /** Username of Rev User (for login) - this or apiKey must be specified */
    username?: string;
    /** Password of Rev User (for login) - this or secret must be specified */
    password?: string;
    /** API Key forRev User (for login) - this or username must be specified */
    apiKey?: string;
    /** API Secret for Rev User (for login) - this or password must be specified */
    secret?: string;
}
export interface RevClientOptions extends RevCredentials {
    /** URL of Rev account */
    url: string;
    /** Logging function - default is log to console */
    log?: (severity: 'debug' | 'info' | 'warn' | 'error', ...args: any[]) => void;
}
export interface RevRequestOptions extends Partial<RequestInit> {
}
export interface RevSearchOptions<T> {
    /**
     * maximum number of search results
     */
    maxResults?: number;
    /**
     * callback per page
     */
    onPage?: (items: T[], index: number, total: number) => void;
}
export interface VideoUploadOptions extends RevRequestOptions {
    /** if specified don't try to calculate length of video stream */
    useChunkedTransfer?: boolean;
    /** specify content type of video */
    contentType?: string;
    /** specify filename of video as reported to Rev */
    filename?: string;
}
export interface RevResponse<T> {
    statusCode: number;
    headers: Headers;
    body: T;
}
export declare class RevClient {
    baseUrl: string;
    credentials: RevCredentials;
    session: {
        token?: string;
        userId?: string;
        apiKey?: string;
        expires?: Date;
    };
    log: RevClientOptions['log'];
    constructor(options: RevClientOptions);
    /**
     * authenticate with Rev
     */
    login(): Promise<void>;
    logoff(): Promise<void>;
    extendSession(): Promise<void>;
    /**
     * Returns true/false based on if the session is currently valid
     * @returns Promise<boolean>
     */
    verifySession(): Promise<boolean>;
    get token(): string;
    get expires(): Date;
    /**
     * check if expiration time of session has passed
     */
    get isSessionExpired(): boolean;
    autoRefreshSession(refreshThresholdMinutes?: number): Promise<boolean>;
    /**
     * make a REST request
     */
    request<T = any>(method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE' | 'HEAD', endpoint: string, data?: any, options?: RevRequestOptions): Promise<RevResponse<T>>;
    get<T = any>(endpoint: string, data?: {
        [key: string]: any;
    } | Record<string, any> | any[], options?: RevRequestOptions): Promise<T>;
    post<T = any>(endpoint: string, data?: {
        [key: string]: any;
    } | Record<string, any> | any[], options?: RevRequestOptions): Promise<T>;
    put<T = any>(endpoint: string, data?: {
        [key: string]: any;
    } | Record<string, any> | any[], options?: RevRequestOptions): Promise<T>;
    patch(endpoint: string, data?: {
        [key: string]: any;
    } | Record<string, any> | any[], options?: RevRequestOptions): Promise<void>;
    delete(endpoint: string, data?: {
        [key: string]: any;
    } | Record<string, any> | any[], options?: RevRequestOptions): Promise<void>;
    /**
     * Private helper function for scrolling through Search API results
     */
    _scroll<RawType>(searchOptions: {
        endpoint: string;
        totalKey: string;
        hitsKey: string;
    }, data: Record<string, any>, options: RevSearchOptions<RawType>): AsyncGenerator<RawType>;
    get video(): {
        /**
         * This is an example of using the video Patch API to only update a single field
         * @param videoId
         * @param title
         */
        setTitle(videoId: string, title: string): Promise<void>;
        /**
         * get processing status of a video
         * @param videoId
         */
        getStatus(videoId: string): Promise<VideoStatusResponse>;
        details(videoId: string): Promise<VideoDetails>;
        /**
         * Upload a video, and returns the resulting video ID
         */
        upload(file: string | Readable, metadata?: VideoUploadMetadata, options?: VideoUploadOptions): Promise<string>;
        /**
         * search for videos. leave blank to get all videos in the account
         */
        search(query?: VideoSearchOptions, options?: RevSearchOptions<SearchVideo>): Promise<SearchVideo[]>;
        /**
         * Example of using the video search API to search for videos, then getting
         * the details of each video
         * @param query
         * @param options
         */
        detailsStream(query?: VideoSearchOptions, options?: RevSearchOptions<SearchVideo>): AsyncGenerator<SearchVideo & (VideoDetails | {
            error?: Error;
        })>;
    };
    get user(): {
        /**
         * @description get the list of roles available in the system
         * @type {() => Promise<Array<{ id: string, name: string, description: string }>>}
         */
        roles(): Promise<{
            id: string;
            name: string;
            description: string;
        }[]>;
        /**
         * Create a new User in Rev
         * @param user
         * @returns the User ID of the created user
         */
        create(user: UserRequest): Promise<string>;
        details(userId: string): Promise<User>;
        /**
         */
        getByUsername(username: string): Promise<User>;
        /**
         */
        getByEmail(email: string): Promise<User>;
        /**
         * use PATCH API to add user to the specified group
         * https://revdocs.vbrick.com/reference#edituserdetails
         * @param {string} userId id of user in question
         * @param {string} groupId
         * @returns {Promise<void>}
         */
        addGroup(userId: string, groupId: string): Promise<void>;
        /**
         * use PATCH API to add user to the specified group
         * https://revdocs.vbrick.com/reference#edituserdetails
         * @param {string} userId id of user in question
         * @param {string} groupId
         * @returns {Promise<void>}
         */
        removeGroup(userId: string, groupId: string): Promise<void>;
        /**
         * search for users based on text query. Leave blank to return all users.
         *
         * @param {string} [searchText]
         * @param {RevSearchOptions<{Id: string, Name: string}>} [options]
         */
        search(searchText?: string, options?: RevSearchOptions<SearchUser>): Promise<SearchUser[]>;
    };
    get group(): {
        /**
         * Create a group. Returns the resulting Group ID
         * @param {{name: string, userIds: string[], roleIds: string[]}} group
         * @returns {Promise<string>}
         */
        create(group: GroupRequest): Promise<any>;
        delete(groupId: string): Promise<void>;
        /**
         *
         * @param {string} [searchText]
         * @param {RevSearchOptions<{Id: string, Name: string}>} [options]
         */
        search(searchText: string, options?: RevSearchOptions<SearchGroup>): Promise<SearchGroup[]>;
        list(options?: RevSearchOptions<SearchGroup>): Promise<SearchGroup[]>;
        listUsers(groupId: string, options?: RevSearchOptions<string>): Promise<string[]>;
        /**
         * get all users in a group with full details as a async generator
         * @param groupId
         * @param options
         * @returns
         */
        usersDetailStream(groupId: string, options?: RevSearchOptions<string> & {
            onError?: (userId: string, error: Error) => void;
        }): AsyncGenerator<User>;
    };
}
//# sourceMappingURL=rev-client.d.ts.map