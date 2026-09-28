extends Node
class_name FoundationGithubApi

const API_ROOT := "https://api.github.com"

var access_token := ""

func request(method: int, path: String, body: Dictionary = {}) -> Dictionary:
	if access_token.is_empty():
		return {"ok": false, "status": 401, "reason": "Sign in to GitHub first"}
	var http := HTTPRequest.new()
	http.max_redirects = 0
	add_child(http)
	var headers := ["Accept: application/vnd.github+json", "Authorization: Bearer " + access_token, "X-GitHub-Api-Version: 2026-03-10", "User-Agent: The-Incredible-Diary"]
	var payload := ""
	if method != HTTPClient.METHOD_GET:
		headers.append("Content-Type: application/json")
		payload = JSON.stringify(body)
	var start := http.request(API_ROOT + path, headers, method, payload)
	if start != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "reason": "GitHub network request could not start"}
	var completed: Array = await http.request_completed
	http.queue_free()
	var response_code := int(completed[1])
	if int(completed[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "reason": "GitHub network request failed"}
	if response_code == 401:
		return {"ok": false, "status": 401, "reason": "GitHub sign-in expired or was denied"}
	if response_code == 403:
		return {"ok": false, "status": 403, "reason": "GitHub access was denied"}
	if response_code < 200 or response_code >= 300:
		return {"ok": false, "status": response_code, "reason": "GitHub returned HTTP %d" % response_code}
	var decoded := JSON.new()
	if decoded.parse((completed[3] as PackedByteArray).get_string_from_utf8()) != OK:
		return {"ok": false, "status": response_code, "reason": "GitHub returned invalid JSON"}
	return {"ok": true, "status": response_code, "data": decoded.data}
