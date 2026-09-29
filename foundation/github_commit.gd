extends RefCounted
class_name FoundationGithubCommit

const Project = preload("res://foundation/github_project.gd")
const Repository = preload("res://foundation/github_repository.gd")

var transport: Object

func _init(api: Object) -> void:
	transport = api

func commit(document: FoundationAuthoringDocument, full_name: String, branch: String, expected_head: String, message: String) -> Dictionary:
	if message.strip_edges().is_empty():
		return {"ok": false, "reason": "Enter a commit message"}
	var packaged: Dictionary = Project.package(document)
	if not packaged.ok:
		return packaged
	var snapshot_revision := document.revision
	if not document.remote_origin.is_empty() and document.remote_origin.get("repository") == full_name and document.remote_origin.get("branch") == branch and document.remote_origin.get("head") == expected_head and document.remote_origin.get("content") == packaged.scenario:
		return {"ok": false, "reason": "No authored project changes to commit"}
	var parts := Repository._repository_parts(full_name)
	if parts.is_empty() or branch.is_empty() or expected_head.is_empty():
		return {"ok": false, "reason": "Choose a repository branch with a known HEAD"}
	var prefix := "/repos/%s/%s" % [parts[0].uri_encode(), parts[1].uri_encode()]
	var branch_path := prefix + "/branches/" + branch.uri_encode()
	var branch_result: Dictionary = await transport.request(HTTPClient.METHOD_GET, branch_path)
	if not branch_result.ok:
		return branch_result
	if str(branch_result.get("data", {}).get("commit", {}).get("sha", "")) != expected_head:
		return {"ok": false, "reason": "Remote HEAD changed; fetch and integrate before committing", "incoming": true}
	var created: Dictionary = await _create_project_commit(packaged, prefix, expected_head, message)
	if not created.ok:
		return created
	if document.revision != snapshot_revision:
		return {"ok": false, "reason": "Authoring changed while preparing the commit; review and retry", "stale_snapshot": true}
	var new_head := str(created.head)
	var before_ref_update := document.snapshot_for_remote_update()
	var ref_result: Dictionary = await transport.request(HTTPClient.METHOD_PATCH, prefix + "/git/refs/heads/" + branch.uri_encode(), {"sha": new_head, "force": false})
	if not ref_result.ok:
		var checked: Dictionary = await transport.request(HTTPClient.METHOD_GET, branch_path)
		if checked.ok and str(checked.get("data", {}).get("commit", {}).get("sha", "")) == new_head:
			var later_edits := document.revision != snapshot_revision
			document.checkout_remote(full_name, branch, new_head, packaged.scenario, before_ref_update if later_edits else {})
			return {"ok": true, "head": new_head, "reason": "Commit reached GitHub after an uncertain response", "later_edits": later_edits}
		return {"ok": false, "reason": "Remote HEAD may have changed; fetch before retrying", "incoming": true, "pending_commit": new_head}
	var later_edits := document.revision != snapshot_revision
	document.checkout_remote(full_name, branch, new_head, packaged.scenario, before_ref_update if later_edits else {})
	return {"ok": true, "head": new_head, "reason": "Committed authored project", "later_edits": later_edits}

func create_project_commit(document: FoundationAuthoringDocument, full_name: String, parent_head: String, message: String) -> Dictionary:
	var packaged: Dictionary = Project.package(document)
	if not packaged.ok:
		return packaged
	return await create_packaged_commit(packaged, full_name, parent_head, message)

func create_packaged_commit(packaged: Dictionary, full_name: String, parent_head: String, message: String) -> Dictionary:
	var parts := Repository._repository_parts(full_name)
	if parts.is_empty() or parent_head.is_empty() or message.strip_edges().is_empty():
		return {"ok": false, "reason": "Choose a repository, parent HEAD and commit message"}
	var prefix := "/repos/%s/%s" % [parts[0].uri_encode(), parts[1].uri_encode()]
	return await _create_project_commit(packaged, prefix, parent_head, message)

func _create_project_commit(packaged: Dictionary, prefix: String, parent_head: String, message: String) -> Dictionary:
	var base_commit: Dictionary = await transport.request(HTTPClient.METHOD_GET, prefix + "/git/commits/" + parent_head)
	if not base_commit.ok:
		return base_commit
	var base_tree := str(base_commit.get("data", {}).get("tree", {}).get("sha", ""))
	if base_tree.is_empty():
		return {"ok": false, "reason": "Remote commit has no tree"}
	var paths: Array = packaged.files.keys()
	paths.sort()
	var entries: Array[Dictionary] = []
	for path in paths:
		var blob_result: Dictionary = await transport.request(HTTPClient.METHOD_POST, prefix + "/git/blobs", {"content": packaged.files[path], "encoding": "utf-8"})
		if not blob_result.ok:
			return blob_result
		var blob_sha := str(blob_result.get("data", {}).get("sha", ""))
		if blob_sha.is_empty():
			return {"ok": false, "reason": "GitHub did not return a project file blob"}
		entries.append({"path": path, "mode": "100644", "type": "blob", "sha": blob_sha})
	var tree_result: Dictionary = await transport.request(HTTPClient.METHOD_POST, prefix + "/git/trees", {"base_tree": base_tree, "tree": entries})
	if not tree_result.ok:
		return tree_result
	var tree_sha := str(tree_result.get("data", {}).get("sha", ""))
	if tree_sha.is_empty():
		return {"ok": false, "reason": "GitHub did not return a project tree"}
	var commit_result: Dictionary = await transport.request(HTTPClient.METHOD_POST, prefix + "/git/commits", {"message": message.strip_edges(), "tree": tree_sha, "parents": [parent_head]})
	if not commit_result.ok:
		return commit_result
	var new_head := str(commit_result.get("data", {}).get("sha", ""))
	if new_head.is_empty():
		return {"ok": false, "reason": "GitHub did not return a commit"}
	return {"ok": true, "head": new_head, "scenario": packaged.scenario}
