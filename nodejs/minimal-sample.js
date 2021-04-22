/**
 * This code is an example of logging into Rev and using the resulting
 * authentication token to get details about a specific video
 * */

var revUrl = 'my.rev.instance.portal.vbrick.com';
var username = 'enter.username.here';
var password = 'enter.password.here';
var videoId = 'enter.video.id.here';

var https = require('https');
var querystring = require('querystring');

function login(revUrl, username, password, callback) {
	// this is the API endpoint for logging in
	// see https://portal.vbrick.com/rev-developers/v2/authentication/username-login/
	var endpoint = '/api/v2/user/login';
	var query = querystring.stringify({
		username: username,
		password: password
	});

	// construct request options
	var requestOptions = {
		method: 'POST',
		protocol: 'https:',
		hostname: revUrl,
		path: endpoint + '?' + query
	};

	var req = https.request(requestOptions, function (res) {
		var statusCode = res.statusCode;
		var raw = '';
		console.log('received login request for username ' + username + '. Status Code ' + statusCode);
		res.setEncoding('utf8');
		res.on('data', function (chunk) {
			raw += chunk;
		});
		res.on('end', function () {
			var data;
			try {
				data = JSON.parse(raw);
			} catch (err) {
				console.error('Invalid login response body', raw);
				callback(new Error('Could not parse response body'));
				return;
			}

			// successful login, return token for subsequent API calls
			if (statusCode == 200) {
				callback(null, data.token);
			} else {
				var error = new Error('Rev error response ' + statusCode + ' ' + data.code + ' - ' + data.detail);
				error.code = statusCode;
				console.error('Rev returned error status code: ' + error.message);
				callback(error);
			}
		});
	});

	req.on('error', function (err) {
		console.error(`problem with request: ${err.message}`);
		callback(err);
	});

	console.log('sending login request');
	req.end();
}

function getVideoDetails(authToken, videoId, callback) {
	var endpoint = '/api/v2/videos/' + videoId + '/details';

	// construct request options
	var requestOptions = {
		method: 'GET',
		protocol: 'https:',
		hostname: revUrl,
		path: endpoint,
		// add authorization token returned by login request
		headers: {
			'Authorization': 'VBrick ' + authToken
		}
	};

	var req = https.request(requestOptions, function (res) {
		var statusCode = res.statusCode;
		var statusMessage = res.statusMessage;
		var raw = '';

		console.log('Video details result ' + statusCode + ' ' + statusMessage);
		res.setEncoding('utf8');
		res.on('data', function (chunk) {
			raw += chunk;
		});
		res.on('end', function () {
			if (statusCode != 200) {
				// e.g. 404 Not Found - Unable to locate VideoPlaybackView with ID
				var error = new Error(statusCode + ' ' + statusMessage + ' - ' + raw);
				error.code = statusCode;
				callback(error);
				return;
			}

			try {
				var videoDetails = JSON.parse(raw);
				callback(null, videoDetails);
			} catch (err) {
				callback(new Error('Could not parse response body'));
			}
		});
	});

	req.on('error', function (err) {
		callback(err);
	});

	console.log('getting details for video ' + videoId);
	req.end();
}

// perform login
login(revUrl, username, password, function (loginError, token) {
	if (loginError) {
		console.warn('Could not login. Check url, username and password', loginError);
		process.exit(1);
		return;
	}

	getVideoDetails(token, videoId, function (err, details) {
		if (err) {
			console.warn('Unable to retrieve video details. Check videoId', err);
			process.exit(1);
			return;
		}

		console.log('Retrieved video details', details);
		console.log('The video title is "' + details.title + '", and was uploaded by ' + details.uploadedBy);
		process.exit();
	});
});
