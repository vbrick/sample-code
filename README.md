# Vbrick Sample Code

This repository holds various sample code and examples for using the [Vbrick Rev](https://vbrick.com/enterprise-video-platform/) API.

Refer to the Vbrick [documentation](https://revdocs.vbrick.com/reference) for more information.

Note: Sample code provided here are examples. This sample code is distributed "as is", with no warranty expressed or implied, and no guarantee for accuracy or applicability to your purpose.

## Contents

### Open API
* [`openapi.json`](openapi.json) - A OpenAPI v3 specification of the Rev APIs

### Postman

* [`vbrick_postman_collection.json`](vbrick_postman_collection.json) - A [Postman](https://www.postman.com/) collection that demonstrates logging in via Username / User API key as well as accessing some common API endpoints

### javascript

* [`rev-client-js`](https://github.com/vbrick/rev-client-js) - isomorphic (node.js/browser/deno) client library for interacting with Rev API.

### node
* [`rev-client`](nodejs/rev-client) - **DEPRECATED** a Typescript wrapper around the Rev API - see full featured [`rev-client-js`](https://github.com/vbrick/rev-client-js) library above
* [`minimal-sample.js`](nodejs/minimal-sample.js) - a minimal no-depenancy example of authenticating with Rev and then making an API request

### python
* [`rev-client-python`](https://github.com/vbrick/rev-client-python) - python library for interacting with Rev API

### .Net

* [`RevAPi`](dotnet/RevAPi) - A sample .Net project for using OAuth with Rev
