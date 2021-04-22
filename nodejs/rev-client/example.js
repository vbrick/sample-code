/**
 * This is a sample of using the rev client code to interact with the Rev API
 * edit the below revConfig and filename values to test.
 */

const {RevClient} = require('.');
const utils = require('./dist/lib/utils');

/** REQUIRED: Edit this value */
/** @type {import('.').RevClientOptions} */
const revConfig = {
	url: 'https://example.rev.url',
	username: 'enter.username.here',
	password: 'enter.password.here'
	// Instead of username + password, you can specify API Key + Secret
	// apiKey: 'enter.apiKey.here'
	// secret: 'enter.secret.here'
};

/** REQUIRED: Edit this value */
// Video used for testing upload functionality
const filename = 'C:\\\\Videos\\my.video.file.mp4';

// Username used for testing group/user operations
const targetUsername = revConfig.username;
// const targetUsername = 'my.username';

// this is the client instance for interacting with the API
const rev = new RevClient(revConfig);

/**
 * Upload a video, then wait for the transcode to complete
 * For details see: https://revdocs.vbrick.com/reference#uploadvideo
 *
 * @param {string} filename filename of video to upload
 * @param {import('.').VideoUploadMetadata} [metadata] additional metadata to include
 * @param {number} [maxWaitMinutes]
 */
async function uploadTask(filename, metadata, maxWaitMinutes = 10) {
	// how long to wait between status checks
	const sleepIntervalSeconds = 15;

	console.log('uploading video');
	const videoId = await rev.video.upload(filename, metadata);
	console.log(`Video uploaded - ID is ${videoId}`);

	// wait for X minutes before giving up waiting
	const waitStart = Date.now();
	let videoStatus;
	do {
		try {
			videoStatus = await rev.video.getStatus(videoId);
		}
		catch (err) {
			console.warn('Unable to get video status', err);
		}
		const { status, isProcessing, overallProgress } = videoStatus;
		console.log(`Video ${videoId} is ${status} - ${Math.round(overallProgress * 100)}%`);

		if (overallProgress === 1 && !isProcessing) {
			console.log('Video done processing');
			break;
		}
		await utils.sleep(sleepIntervalSeconds * 1000);
	} while (Date.now() - waitStart < (maxWaitMinutes * 60 * 1000));

	return videoStatus;
}

/**
 * example of various user/group operations
 * @param {string} targetUsername
 * @param {boolean} autoDelete
 */
async function groupOperations(targetUsername, autoDelete = true) {
	// get list of roles in system
	const roles = await rev.user.roles();

	// get the media viewer role
	const viewerRole = roles.find(role => role.name === 'Media Viewer');

	// get user details using the GET method call. The commented out lines are equivalent
	const userDetails = await rev.get(`/api/v2/users/${targetUsername}`, { type: 'username' });
	// const userDetails = await rev.get(`/api/v2/users/${targetUsername}?type=username`);
	// const userDetails = await rev.user.getByUsername(targetUsername);

	console.log('Target User: ', userDetails);
	const { userId } = userDetails;

	// now create a group
	const groupRequest = {
		name: `Test_Group_${Math.random().toString(16).slice(3)}`,
		userIds: [],
		roleIds: [viewerRole.id]
	};
	console.log(`Creating empty test group ${groupRequest.name}`);
	const groupId = await rev.group.create(groupRequest);
	console.log(`Group created with id: ${groupId}`);

	console.log('Adding user to group using PATCH API');
	await rev.user.addGroup(userId, groupId);


	console.log('Listing members of group');
	for await (const user of rev.group.usersDetailStream(groupId)) {
		console.log(`Member: ${user.firstname} ${user.lastname}`);
	}


	if (autoDelete) {
		console.log('Now cleaning up');
		await rev.group.delete(groupId);
	}
}

(async () => {
	if (rev.baseUrl === 'https://example.rev.url') {
		console.warn('USAGE: Edit this file to specify your configuration values for Rev');
		process.exit(1);
	}
	console.log('Logging in...');
	await rev.login();
	console.log('Testing User/Group Operations');
	await groupOperations(targetUsername);
	console.log('refreshing session if necessary');
	if (await rev.autoRefreshSession()) {
		console.log('Used extend session API');
	}
	else {
		console.log(`session valid - expires: ${rev.session.expires}`);
	}
	console.log('Uploading Video');
	/** @type {import('.').VideoUploadMetadata} */
	const videoMetadata = {
		title: 'Test Video Upload 123',
		uploader: targetUsername,
		videoAccessControl: 'Private'
	};
	await uploadTask(filename, videoMetadata);


	console.log('Logging out');
	await rev.logoff();
	process.exit();
})()
	.catch(error => {
		console.error('FATAL Error:', error);
	});
