/**
 * Sample code to connect to rev and search video content
 * SEE https://github.com/vbrick/rev-client-js for more information on the rev-client library
 * 
 * DISCLAIMER: 
 *   This sample code is not an officially supported Vbrick product, and is provided AS-IS.
 */

import {RevClient, utils} from '@vbrick/rev-client';
import fs from 'node:fs/promises';




/** 
 * Enter in credentials for connecting to Vbrick Rev (User API Key + Secret)
 * @type {import("@vbrick/rev-client").Rev.Options}
 */
const config = {
    url: "https://my.rev.url",
    apiKey: "my-api-key",
    secret: "my-secret"
};


const rev = new RevClient(config);

await rev.connect();

/** @type {import('@vbrick/rev-client').Video.SearchOptions} */
const searchOptions = {
    status: 'active',
    unlisted: 'listed',
    sortField: 'whenModified',
    sortDirection: 'desc'
    };
    
    
// limiting max search results for example purposes
const maxResults = 100;

const searchPager = rev.video.search(searchOptions, { maxResults: maxResults });
const searchHits = await searchPager.exec();

/** Could also go through search results one at a time: */
// /** @type {import('@vbrick/rev-client').Video.SearchHit[]} */
// const searchHits = [];
// for await (let video of searchPager) {
//     searchHits.push(video);
// }

console.log(`Total Videos in account: ${searchPager.total}. First ${maxResults} videos:`);
console.table(searchHits, ['id', 'title', 'viewCount', 'duration']);

// get random video
const randomIndex = Math.floor(Math.random() * searchHits.length);
const sampleVideo = searchHits.at(randomIndex);
const videoId = sampleVideo.id;

console.log(`Getting details for ${videoId}`);

const details = await rev.video.details(videoId);
console.log("Details for video", {title: details.title, description: details.description, videoAccessControl: details.videoAccessControl, thumbnail: details.thumbnailUrl});

console.log("Video Owner Details:");
const user = await rev.user.details(details.owner.userId);
console.log(`"${user.firstname} ${user.lastname}" | Email: ${user.email} | Username: ${user.username}`);

if (!sampleVideo.thumbnailUrl) {
    console.warn("Video does not have thumbnail - may be audio-only");
} else {
    console.log("Downloading thumbnail to disk");

    /** @type {import("@vbrick/rev-client").Rev.Response<Blob>} */
    const {body: blob} = await rev.request('GET', `/api/v2/videos/${videoId}/thumbnail`, undefined, { responseType: 'blob' });
    const imageBuffer = Buffer.from(await blob.arrayBuffer());

    // construct filename (images are almost always .jpg, but may make sense to check mimetype)
    const extension = utils.getExtensionForMime(blob.type) ?? '.jpg';
    const outputFilePath = `${videoId}${extension}`;

    await fs.writeFile(outputFilePath, imageBuffer);
    console.log(`Wrote thumbnail to ${outputFilePath}`);
}

process.exit();