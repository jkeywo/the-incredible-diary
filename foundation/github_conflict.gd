extends RefCounted
class_name FoundationGithubConflict

const Project = preload("res://foundation/github_project.gd")
const Repository = preload("res://foundation/github_repository.gd")
const Commit = preload("res://foundation/github_commit.gd")

var transport: Object
var repository: FoundationGithubRepository
var writer: FoundationGithubCommit

func _init(api: Object) -> void:
	transport = api
	repository = Repository.new(api)
	writer = Commit.new(api)

func preserve(document: FoundationAuthoringDocument) -> Dictionary:
	var origin: Dictionary = document.remote_origin
	if origin.is_empty():
		return {"ok": false, "reason": "Open a GitHub project before preserving a conflict"}
	var source_document := document
	if not document.validate().is_empty() and not document.pending_conflict_local.is_empty():
		source_document = FoundationAuthoringDocument.new(document.pending_conflict_local)
	var packaged: Dictionary = Project.package(source_document)
	if not packaged.ok:
		return {"ok": false, "reason": "Correct the local authored project before preserving the conflict: " + str(packaged.reason)}
	var snapshot_revision := document.revision
	var fingerprint := JSON.stringify(packaged.files).sha256_text().substr(0, 16)
	var branch_name := "diary-conflict/" + fingerprint
	var full_name := str(origin.repository)
	var parts := Repository._repository_parts(full_name)
	if parts.is_empty():
		return {"ok": false, "reason": "GitHub repository name is invalid"}
	var prefix := "/repos/%s/%s" % [parts[0].uri_encode(), parts[1].uri_encode()]
	var ref_path := prefix + "/git/ref/heads/" + branch_name.uri_encode()
	var existing: Dictionary = await transport.request(HTTPClient.METHOD_GET, ref_path)
	if existing.ok:
		var opened: Dictionary = await repository.open_project(full_name, branch_name)
		var normalized: Variant = JSON.parse_string(str(packaged.files[Project.SCENARIO_PATH]))
		if not opened.ok or opened.content != normalized:
			return {"ok": false, "reason": "Conflict branch already exists with different content; inspect it on GitHub", "branch": branch_name}
		if document.revision != snapshot_revision:
			return {"ok": false, "reason": "Authoring changed while checking the conflict branch; review and retry", "stale_snapshot": true}
		return _record_handoff(document, fingerprint, branch_name, str(existing.get("data", {}).get("object", {}).get("sha", "")), full_name, str(origin.branch))
	if int(existing.get("status", 0)) != 404:
		return existing
	var created: Dictionary = await writer.create_packaged_commit(packaged, full_name, str(origin.head), "Preserve local Incredible Diary conflict")
	if not created.ok:
		return created
	if document.revision != snapshot_revision:
		return {"ok": false, "reason": "Authoring changed while preparing the conflict branch; review and retry", "stale_snapshot": true}
	var new_head := str(created.head)
	var ref_result: Dictionary = await transport.request(HTTPClient.METHOD_POST, prefix + "/git/refs", {"ref": "refs/heads/" + branch_name, "sha": new_head})
	if not ref_result.ok:
		var checked: Dictionary = await transport.request(HTTPClient.METHOD_GET, ref_path)
		if not checked.ok or str(checked.get("data", {}).get("object", {}).get("sha", "")) != new_head:
			return {"ok": false, "reason": "Conflict branch creation is uncertain; check GitHub before retrying", "branch": branch_name}
	var later_edits := document.revision != snapshot_revision
	var result := _record_handoff(document, fingerprint, branch_name, new_head, full_name, str(origin.branch))
	result["later_edits"] = later_edits
	if later_edits:
		result["reason"] = "Earlier authored snapshot preserved on a conflict branch; newer local edits still need preserving"
	return result

func _record_handoff(document: FoundationAuthoringDocument, fingerprint: String, branch_name: String, head: String, full_name: String, target_branch: String) -> Dictionary:
	var url := "https://github.com/%s/compare/%s...%s?expand=1" % [full_name, target_branch.uri_encode(), branch_name.uri_encode()]
	document.record_conflict_handoff({"fingerprint": fingerprint, "branch": branch_name, "head": head, "repository": full_name, "target_branch": target_branch, "url": url})
	return {"ok": true, "branch": branch_name, "head": head, "url": url, "reason": "Local authored project preserved on a conflict branch"}
