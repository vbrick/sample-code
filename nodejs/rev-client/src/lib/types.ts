
export type ApprovalStatus = 'Approved' | 'PendingApproval' | 'Rejected' | 'RequiresApproval' | 'SubmittedApproval';

export type VideoType = "Live" | "Vod";

export type EncodingType = "H264" | "HLS" | "HDS" | "H264TS" | "Mpeg4" | "Mpeg2" | "WM" | "Flash" | "RTP";

export type VideoStatusEnum = "NotUploaded" |"Uploading" |"UploadingFinished" |"NotDownloaded" |"Downloading" |"DownloadingFinished" |"DownloadFailed" |"Canceled" |"UploadFailed" |"Processing" |"ProcessingFailed" |"ReadyButProcessingFailed" |"RecordingFailed" |"Ready";

export type VideoAccessControl = "AllUsers" | "Public" | "Private" | "Channels";
export type AccessControlEntityType = 'User' |'Group' |'Team' |'Role';
export type ExpirationAction = 'Delete' | 'Inactivate';

export interface AccessControlEntity {
    id: string;
    name: string;
    type: AccessControlEntityType;
    canEdit: boolean;
};

export interface Category {
    categoryId: string;
    name: string;
    fullPath: string;
    parentCategoryId: string;
};

export interface CustomField {
    id: string;
    name: string;
    value: any;
    required: boolean;
    displayedToUsers: boolean;
    type: string;
    fieldType: string;
};

export interface LinkedUrl {
    Url: string;
    EncodingType: EncodingType;
    Type: VideoType;
    IsMulticast: boolean;
};

export interface SearchVideo {
	id: string
	title: string
	description: string
	categories: string[]
	tags: string[]
	thumbnailUrl: string
	playbackUrl: string
	duration: string
	viewCount: number
	status: string
	approvalStatus: string
	uploader: string
	uploadedBy: string
	whenUploaded: string
	lastViewed: string
	averageRating: string
	ratingsCount: string
	speechResult: Array<{time: string, text: string}>
	unlisted: boolean
	whenModified: string
	whenPublished: string
	commentCount: string
	score: number
}

export interface VideoUploadMetadata {
	/** required - uploader of video */
	uploader: string;
	/** Title of the video being uploaded. If title is not specified, API will use uploaded filename as the title. */
	title?: string;
	/** Description - safe html will be preserved */
	description?: string;
	/** list of category names */
	categories?: string[]
	/** An array of category IDs */
	categoryIds?: string[]
	/** An array of strings that are tagged to the video. */
	tags?: string[];
	/**  */
	isActive?: boolean;

	enableRatings?: boolean;
	enableDownloads?: boolean;
	enableComments?: boolean;

	/**
	 * This sets access control for the video. This is an enum and can have the following values: Public/AllUsers/Private/Channels.
	 */
	videoAccessControl?: VideoAccessControl;
	/**
	 * This provides explicit rights to a User/Group/Collection with/without CanEdit access to a video. This is an array with properties; Name (entity name), Type (User/Group/Collection), CanEdit (true/false). If any value is invalid, it will be rejected while valid values are still associated with the video.
	 */
	accessControlEntities?: (Omit<AccessControlEntity, 'id'> | Omit<AccessControlEntity, 'name'>)[];

	/**
	 * A Password for Public Video Access Control. Use this field when the videoAccessControl is set to Public. If not this field is ignored.
	 */
	password?: string;

	/** An array of customFields that is attached to the video. */
	customFields?: ({ id: string, value: string } | { name: string, value: string })[];

	doNotTranscode?: boolean;
	is360?: boolean;

	unlisted?: boolean;

	publishDate?: string;
	userTags?: string[];
}

export interface VideoDetails {
	/** Video ID */
	id: string;
	/** Title of the video being uploaded. If title is not specified, API will use uploaded filename as the title. */
	title: string;
	/** Description in plain text */
	description: string;
	/** Description with HTML tags included */
	htmlDescription: string;
	/** An array of strings that are tagged to the video. */
	tags: string[];
	/** An array of category IDs */
	categories: string[]
	/** An array of categories with full details (id + full path) */
	categoryPaths: Array<{categoryId: string, name: string, fullPath: string}>
	/** An array of customFields that is attached to the video. */
	customFields: Array<{ id: string, name: string, value: string, required: boolean }>;
	/** when video was uploaded (ISO Date) */
	whenUploaded: string;
	/** the full name of user who uploaded video */
	uploadedBy: string;
	/**  */
	isActive: boolean;
	/** This is the processing status of a video. */
	status: VideoStatusEnum;
	linkedUrl: LinkedUrl | null;
	/** type of video - live or VOD */
	type: VideoType;
	/**
	 * This sets access control for the video. This is an enum and can have the following values: Public/AllUsers/Private/Channels.
	 */
	videoAccessControl: VideoAccessControl;
	/**
	 * This provides explicit rights to a User/Group/Collection with/without CanEdit access to a video. This is an array with properties; Name (entity name), Type (User/Group/Collection), CanEdit (true/false). If any value is invalid, it will be rejected while valid values are still associated with the video.
	 */
	accessControlEntities: Array<AccessControlEntity>;
	/**
	 * A Password for Public Video Access Control. Use this field when the videoAccessControl is set to Public. If not this field is ignored.
	 */
	password: string | null;
	expirationDate: string | null;
	/**
	 * This sets action when video expires. This is an enum and can have the following values: Delete/Inactivate.
	 */
	expirationAction: ExpirationAction | null;
	/**
	 * date video will be published
	 */
	publishDate: string | null;
	lastViewed: string;
	approvalStatus: ApprovalStatus;
	thumbnailUrl: string;
	enableRatings: boolean;
	enableDownloads: boolean;
	enableComments: boolean;
	unlisted: boolean;
	is360: boolean;
	userTags: Array<{userId: string, displayName: string}>;
}

export interface VideoStatusResponse {
	videoId: string
	title: string
	status: VideoStatusEnum
	isProcessing: boolean
	overallProgress: number
	isActive: boolean
	uploadedBy: string
	whenUploaded: string
}

export interface VideoSearchOptions {
	/** text to search for */
	q?: string;
	/**
	 * live or vod videos
	 */
	type?: VideoType;
	/**
	 * list of category IDs separated by commas. pass blank to get uncategorized only
	 */
	categories?: string;
	/** list of uploader names separated by commas */
	uploaders?: string;
	/** list of uploader IDs separated by commas */
	uploaderIds?: string;
	status?: 'active' | 'inactive';
	fromPublishedDate?: string
	toPublishedDate?: string
	fromUploadDate?: string
	toUploadDate?: string
	fromModifiedDate?: string
	toModifiedDate?: string

	exactMatch?: boolean;
	unlisted?: 'unlisted' | 'listed' | 'all';

	/**
	 * If provided, the query results are fetched on the provided searchField only.
	 * If the exactMatch flag is also set along with searchField, then the results are fetched for
	 * an exact match on the provided searchField only.
	 */
	searchField?: string

	includeTranscriptSnippets?: boolean;

	/**
	 * Show recommended videos for the specified Username. Videos returned are based on the user’s
	 * last 10 viewed videos. Must be Account Admin or Media Admin to use this query. Sort order
	 * must be _score. User must exist.
	 */
	recommendedFor?: string;

	sortField?: 'title' | 'whenUploaded' | 'uploaderName' | 'duration' | '_score';
	sortDirection?: 'asc' | 'desc';

	/**
	 * search for videos matching specific custom field values.
	 * Object in the format {My_Custom_Field_Name: "MyCustomFieldValue"}
	 */
	[key: string]: any;
}

export interface User {
	userId: string
    username: string
    email: string
    firstname: string
    lastname: string
	language: string | null
	title: string | null
	phone: string | null
	groups: {id: string, name: string}[]
	roles: {id: string, name: string}[]
	channels: {id: string, name: string}[]
    profileImageUri: string | null
}

export interface SearchUser {
	Id: string;
	Email: string | null
	EntityType: 'User'
	FirstName: string;
	LastName: string;
	UserName: string;
}

export interface UserRequest {
	username: string
	email?: string
	firstname?: string
	lastname: string
	title?: string
	phoneNumber?: string
	language?: string
	groupIds?: string[]
	roleIds?: string[]
}

export interface SearchGroup {
	Name: string
	Id: string
	EntityType: 'Group'
}

export interface GroupRequest {
	name: string;
	userIds: string[];
	roleIds: string[];
}
