# rev-client

This is a sample node.js client library for interacting with the [Vbrick Rev API](https://revdocs.vbrick.com/reference). See example.js or `src/example.ts` for sample usage.

## Usage

```js
const { RevClient } = require('.');

const apiClient = new RevClient({
    url: 'https://my.rev.url',
    apiKey: 'my.user.apikey',
    secret: 'my.user.secret'
    // or can login via username + password
    // username: 'my.username',
    // password: 'my.password'
});

(async () => {
    // will throw error if invalid login
    await apiClient.login();

    // get a list of categories in Rev
    const categoriesResponse = await apiClient.get('/api/v2/categories');
    // print out first 10 categories
    for (const category of categoriesResponse.categories.slice(0, 10)) {
        console.log('Category full path: ', category.fullPath);
    }

})();

```


## Session Managment

### `login()`
Authenticate using credentials passed in to the `RevClient` constructor

### `logoff()`
Clear access token and end session

### `extendSession()`
Extends the session expiration time.

### `verifySession()`
Returns false if current session is expired/invalid, otherwise true

### `autoRefreshSession(refreshThresholdMinutes = 3)`
Calls `login()` or `extendSession()` only if session is expired, or will expire in the next `refreshThresholdMinutes`.


## HTTP Methods

#### `request(method, endpoint, data?, options?)`
Make a HTTP Request to Rev with the specified parameters. Uses `node-fetch` to actually make the calls.

Returns a Promise with `statusCode`, `headers` and `body`. The body is automatically converted to a JSON object, text, or buffer depending on the response content type.

##### method

Type: `string`

The HTTP VERB for the request

##### endpont

Type: `string`

The path for the API call *(relative to the configured rev URL, i.e. `https://my.rev.url/endpoint`)*

##### data

Type: *JSON object/array* | `string` | `FormData` | any `fetch` body type

If a `GET` request these only an `object` is valid - the values will be added as query parameters. If `POST`,`PUT` or `PATCH` then this will be added as the body of the request. `JSON` data will automatically be stringified.

##### options

Type: `object`

Any additional `fetch` Request options.

#### `get(endpoint, data, options)`

Make a `get` API request to `endpoint`. See `request()` above for data + options values.

Returns: the body of the API response.

#### `put(endpoint, data, options)`

Make a `put` API request to `endpoint`. See `request()` above for data + options values.

Returns: the body of the API response.

#### `patch(endpoint, data, options)`

Make a `patch` API request to `endpoint`. See `request()` above for data + options values.

Returns: the body of the API response.

#### `post(endpoint, data, options)`

Make a `post` API request to `endpoint`. See `request()` above for data + options values.

Returns: the body of the API response.

#### `delete(endpoint, data, options)`

Make a `delete` API request to `endpoint`. See `request()` above for data + options values.

Returns: the body of the API response.

## Video API

#### `video.setTitle(videoId, title)`

An example of using the [Video PATCH API](https://revdocs.vbrick.com/reference#editvideopatch) to change a single value on the video

#### `video.getStatus(videoId)`

Get the processing status of a video

#### `video.details(videoId)`

Get the full metadata details of a video

#### `video.upload(file, metadata?, options?)`

Upload a file to Rev with specified metadata.

##### file

Type: `string` | `stream.Readable`

The path to a file to upload. Can also be a Readable stream instead.

##### metadata

Type: `object`

The video metadata to add. `uploader` is the only required field - it will default to the `username` if set in the `RevClient` constructor. See the [API documentation](https://revdocs.vbrick.com/reference#uploadvideo) for the available options.

##### options

Type: `object`

Additional `fetch` options, as well as:
* `useChunkedEncoding` - transfer using chunked encoding. Only useful if using a Readable stream as input and don't know the actuall content length of the input.
* `contentType` - set the mimetype of the file. Required if the specified file does not have a valid file extension (i.e. `mp4` or `mov`).
* `filename` - specify the filename used in the `FormData` field when uploading.


#### `video.search(query?, options?)`

Search for videos matching the specified query. If no query is specified then return all videos in the Rev account.

##### query

Type: `object`

See the [video search documentation](https://revdocs.vbrick.com/reference#searchvideo) for available parameters.

##### options

Type: `object`

Additional `fetch` options, as well as:
* `maxResults`: maximum number of results to return
* `onPage(items, index, total)`: callback for each page of the results

#### `video.detailsStream(query?, options?)`

Search for videos matching the specified query + options (same as `video.search` above), then also get the `details` API results for each matched video.

Returns: an Async Generator.

Example:
```js
// get a stream of all videos modified in the last three months
const ONE_DAY = 1000 * 60 * 60 * 24;
const threeMonthsAgo = new Date(Date.now() - ONE_DAY * 30 * 3);
const videoStream = apiClient.video.detailsStream({ fromModifiedDate: threeMonthsAgo });

for await (const video of videoStream) {
    // output the custom fields and other information for each video
    const { title, whenModified, customFields } = video;
    console.log(`Video ${title}`, {whenModified, customFields });
}
```

## User API

#### `roles()`

Get the list of Roles in the Rev system

#### `create(user)`

Create a user

#### `details(userId)`
#### `getByUsername(username)`
#### `getByEmail(email)`

Get user details based on their userId, username or email

#### `addGroup(userId, groupId)`
#### `removeGroup(userId, groupId)`

Example of using the User PATCH API to add/remove a user from a group

#### `search(searchText?, options?)`

Search for users that match the given search text. leave `searchText` blank to retrieve all users.

## Group API

#### `create(group)`

Create a group

#### `delete(groupId)`

Delete the specified group

#### `search(searchText?, options?)`

Search for groups that include the specified search text

#### `list(options?)`

Return a listing of all groups in the Rev system

#### `listUsers(groupId, options?)`

Return the User IDs of all users that belong to the specified group.

#### `usersDetailStream(groupId, options?)`

Return detailed information about each user as an Async Generator.
