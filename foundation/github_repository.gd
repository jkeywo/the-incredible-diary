extends RefCounted
class_name FoundationGithubRepository

const Project = preload("res://foundation/github_project.gd")

var transport: Object

func _init(api: Object) -> void:
	transport = api

func list_repositories() -> Dictionary:
	var repositories: Array[Dictionary] = []
	var page := 1
	while true:
		var path := "/user/repos?affiliation=owner,collaborator,organization_member&per_page=100"
		if page > 1:
			path += "&page=%d" % page
		var response: Dictionary = await transport.request(HTTPClient.METHOD_GET, path)
		if not response.ok:
			return response
		if not response.data is Array:
			return {"ok": false, "reason": "GitHub repository list is invalid"}
		for item in response.data:
			if item is Dictionary and item.get("full_name") is String:
				var permissions: Variant = item.get("permissions", {})
				repositories.append({"full_name": item.full_name, "default_branch": item.get("default_branch", "main"), "can_push": bool(permissions.get("push", false)) if permissions is Dictionary else false})
		if response.data.size() < 100:
			break
		page += 1
	return {"ok": true, "repositories": repositories}

func list_branches(full_name: String) -> Dictionary:
	var parts := _repository_parts(full_name)
	if parts.is_empty():
		return {"ok": false, "reason": "Choose a valid GitHub repository"}
	var branches: Array[Dictionary] = []
	var page := 1
	while true:
		var path := "/repos/%s/%s/branches?per_page=100" % [parts[0].uri_encode(), parts[1].uri_encode()]
		if page > 1:
			path += "&page=%d" % page
		var response: Dictionary = await transport.request(HTTPClient.METHOD_GET, path)
		if not response.ok:
			return response
		if not response.data is Array:
			return {"ok": false, "reason": "GitHub branch list is invalid"}
		for item in response.data:
			if item is Dictionary and item.get("name") is String and item.get("commit", {}) is Dictionary:
				branches.append({"name": item.name, "head": str(item.commit.get("sha", ""))})
		if response.data.size() < 100:
			break
		page += 1
	return {"ok": true, "branches": branches}

func open_project(full_name: String, branch: String) -> Dictionary:
	var parts := _repository_parts(full_name)
	if parts.is_empty() or branch.is_empty():
		return {"ok": false, "reason": "Choose a repository and branch"}
	var prefix := "/repos/%s/%s" % [parts[0].uri_encode(), parts[1].uri_encode()]
	var branch_result: Dictionary = await transport.request(HTTPClient.METHOD_GET, prefix + "/branches/" + branch.uri_encode())
	if not branch_result.ok:
		return branch_result
	var branch_data: Variant = branch_result.get("data")
	if not branch_data is Dictionary or not branch_data.get("commit", {}) is Dictionary:
		return {"ok": false, "reason": "GitHub branch response is invalid"}
	var head := str(branch_data.commit.get("sha", ""))
	if head.is_empty():
		return {"ok": false, "reason": "GitHub branch has no commit"}
	var commit_result: Dictionary = await transport.request(HTTPClient.METHOD_GET, prefix + "/git/commits/" + head)
	if not commit_result.ok:
		return commit_result
	var tree_sha := str(commit_result.get("data", {}).get("tree", {}).get("sha", ""))
	if tree_sha.is_empty():
		return {"ok": false, "reason": "GitHub commit has no tree"}
	var tree_result: Dictionary = await transport.request(HTTPClient.METHOD_GET, prefix + "/git/trees/" + tree_sha + "?recursive=1")
	if not tree_result.ok:
		return tree_result
	var tree: Variant = tree_result.get("data")
	if not tree is Dictionary or tree.get("truncated", false) or not tree.get("tree") is Array:
		return {"ok": false, "reason": "GitHub project tree is incomplete"}
	var blob_ids := {}
	for entry in tree.tree:
		if entry is Dictionary and entry.get("type") == "blob" and str(entry.get("path", "")) in [Project.MANIFEST_PATH, Project.SCENARIO_PATH]:
			blob_ids[entry.path] = str(entry.get("sha", ""))
	if not blob_ids.has(Project.MANIFEST_PATH):
		return {"ok": false, "reason": "Repository has no Incredible Diary project manifest"}
	var files := {}
	for path in [Project.MANIFEST_PATH, Project.SCENARIO_PATH]:
		if not blob_ids.has(path):
			continue
		var blob_result: Dictionary = await transport.request(HTTPClient.METHOD_GET, prefix + "/git/blobs/" + str(blob_ids[path]))
		if not blob_result.ok:
			return blob_result
		var blob: Variant = blob_result.get("data")
		if not blob is Dictionary or blob.get("encoding") != "base64" or not blob.get("content") is String:
			return {"ok": false, "reason": "GitHub project file is invalid"}
		files[path] = Marshalls.base64_to_raw(str(blob.content)).get_string_from_utf8()
	var opened: Dictionary = Project.open_files(files)
	if not opened.ok:
		return opened
	return {"ok": true, "content": opened.content, "head": head, "repository": full_name, "branch": branch}

static func _repository_parts(full_name: String) -> PackedStringArray:
	var parts := full_name.split("/")
	if parts.size() != 2 or parts[0].is_empty() or parts[1].is_empty() or parts[0].contains("..") or parts[1].contains(".."):
		return PackedStringArray()
	return parts
