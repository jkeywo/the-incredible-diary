extends RefCounted
class_name FoundationGithubSync

const Merge = preload("res://foundation/github_merge.gd")

var repository: FoundationGithubRepository

func _init(project_repository: FoundationGithubRepository) -> void:
	repository = project_repository

func fetch(document: FoundationAuthoringDocument) -> Dictionary:
	var origin: Dictionary = document.remote_origin
	if origin.is_empty():
		return {"ok": false, "reason": "Open a GitHub project first"}
	return await repository.open_project(str(origin.repository), str(origin.branch))

func integrate(document: FoundationAuthoringDocument, fetched: Dictionary) -> Dictionary:
	if not fetched.ok:
		return fetched
	var origin: Dictionary = document.remote_origin
	if origin.is_empty() or fetched.repository != origin.repository or fetched.branch != origin.branch:
		return {"ok": false, "reason": "Fetched project does not match the open repository branch"}
	if fetched.head == origin.head:
		return {"ok": true, "reason": "Already at remote HEAD", "head_changed": false, "needs_commit": document.candidate() != origin.content}
	var errors: Array[String] = document.validate()
	if not errors.is_empty():
		return {"ok": false, "reason": "Local draft needs correction before integrating incoming content", "errors": errors, "remote": fetched.content}
	var local: Dictionary = document.candidate()
	var merged: Dictionary = Merge.combine(origin.content, local, fetched.content)
	if not merged.ok:
		if not merged.get("errors", []).is_empty() and merged.get("candidate", {}) is Dictionary:
			document.stage_invalid_merge(merged.candidate, merged.errors, local)
		return {"ok": false, "reason": merged.reason, "conflicts": merged.get("conflicts", []), "errors": merged.get("errors", []), "remote": fetched.content, "candidate": merged.get("candidate", {})}
	var adopted: Dictionary = merged.content
	if adopted != document.content:
		document.replace_content(adopted, "Integrate remote authored content")
	document.checkout_remote(str(origin.repository), str(origin.branch), str(fetched.head), fetched.content)
	return {"ok": true, "reason": "Integrated remote authored content", "head_changed": true, "needs_commit": adopted != fetched.content, "content": adopted}
