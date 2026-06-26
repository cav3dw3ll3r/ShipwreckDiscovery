@tool
extends EditorPlugin

const MANIFEST_PATH := "res://assets.manifest.json"
const REPORT_PATH := "res://.godot/asset_manifest_checker/last_report.json"

const MENU_CHECK := "Asset Manifest: Check Assets Now"
const MENU_REFRESH := "Asset Manifest: Refresh From Local Assets"
const MENU_OPEN := "Asset Manifest: Open Manifest"

const REQUIRED_ASSET_ROOTS := [
	"Meshes",
	"Audio",
	"Images",
	"Resources/Scannable/Wrecks/videos",
]

const PREFAB_BINARY_ROOT := "Prefabs"
const ROOT_EXPORT_EXTENSIONS := ["pck", "apk", "aab", "zip"]
const BINARY_EXTENSIONS := [
	"glb",
	"gltf",
	"fbx",
	"blend",
	"obj",
	"dae",
	"stl",
	"3ds",
	"xcf",
	"psd",
	"kra",
	"tga",
	"dds",
	"exr",
	"hdr",
	"png",
	"jpg",
	"jpeg",
	"webp",
	"bmp",
	"gif",
	"wav",
	"mp3",
	"ogg",
	"flac",
	"mp4",
	"ogv",
	"webm",
	"m4v",
	"mkv",
	"mov",
	"avi",
]

var _dialog: AcceptDialog


func _enter_tree() -> void:
	add_tool_menu_item(MENU_CHECK, Callable(self, "_check_assets_now"))
	add_tool_menu_item(MENU_REFRESH, Callable(self, "_refresh_manifest_from_local_assets"))
	add_tool_menu_item(MENU_OPEN, Callable(self, "_open_manifest"))
	call_deferred("_run_startup_check")


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_CHECK)
	remove_tool_menu_item(MENU_REFRESH)
	remove_tool_menu_item(MENU_OPEN)
	_save_shutdown_report()
	if is_instance_valid(_dialog):
		_dialog.queue_free()


func _run_startup_check() -> void:
	var report := _build_quick_report()
	call_deferred("_show_startup_report", report)


func _show_startup_report(report: Dictionary) -> void:
	if _has_report_issues(report):
		push_warning("Asset Manifest Checker: quick check found issues: %s" % report.get("summary", {}))
	else:
		print("Asset Manifest Checker: quick check passed.")
	_show_report(report, "Asset Manifest Startup Check")


func _check_assets_now() -> void:
	var report := _build_quick_report()
	_show_report(report, "Asset Manifest Check")


func _refresh_manifest_from_local_assets() -> void:
	var manifest := _build_manifest_from_local_assets()
	if _write_json(MANIFEST_PATH, manifest):
		var report := _build_quick_report()
		_show_report(report, "Asset Manifest Refreshed")
		get_editor_interface().get_resource_filesystem().scan()
	else:
		push_error("Asset Manifest Checker: failed to write %s." % MANIFEST_PATH)


func _open_manifest() -> void:
	var absolute_path := ProjectSettings.globalize_path(MANIFEST_PATH)
	OS.shell_open(absolute_path)


func _save_shutdown_report() -> void:
	var report := _build_quick_report()
	_ensure_report_dir()
	_write_json(REPORT_PATH, report)


func _build_quick_report() -> Dictionary:
	var manifest := _read_manifest()
	var manifest_entries := _manifest_entries_by_path(manifest)
	var report := {
		"schema_version": 1,
		"checked_at": Time.get_datetime_string_from_system(true, true),
		"manifest_path": _project_path(MANIFEST_PATH),
		"summary": {
			"ok": 0,
			"missing": 0,
			"changed": 0,
			"extra": 0,
		},
		"missing": [],
		"changed": [],
		"extra": [],
		"ok": [],
	}

	if not FileAccess.file_exists(MANIFEST_PATH):
		report["changed"].append({
			"path": _project_path(MANIFEST_PATH),
			"reason": "Manifest file is missing. Use '%s' to create it." % MENU_REFRESH,
		})
		report["summary"]["changed"] += 1
		return report

	for path in manifest_entries.keys():
		var expected: Dictionary = manifest_entries[path]
		var res_path := "res://%s" % path
		if not FileAccess.file_exists(res_path):
			report["missing"].append({
				"path": path,
				"package": expected.get("package", ""),
				"reason": "Listed in manifest but not found locally.",
			})
			report["summary"]["missing"] += 1
			continue

		var actual_size := _file_size_for_project_path(path)
		var expected_size := int(expected.get("size", -1))
		if expected_size >= 0 and actual_size != expected_size:
			report["changed"].append({
				"path": path,
				"package": expected.get("package", ""),
				"reason": "size %s != %s" % [actual_size, expected_size],
				"expected_size": expected_size,
				"actual_size": actual_size,
			})
			report["summary"]["changed"] += 1
		else:
			report["ok"].append(path)
			report["summary"]["ok"] += 1

	return report


func _build_manifest_from_local_assets() -> Dictionary:
	var local_assets := _discover_local_assets(true)
	var entries := []
	var paths := local_assets.keys()
	paths.sort()

	for path in paths:
		var asset: Dictionary = local_assets[path]
		entries.append({
			"path": path,
			"package": asset.get("package", ""),
			"size": asset.get("size", 0),
			"sha256": asset.get("sha256", ""),
			"modified_time": asset.get("modified_time", 0),
			"external_location": "Pending",
		})

	return {
		"schema_version": 1,
		"generated_at": Time.get_datetime_string_from_system(true, true),
		"asset_roots": REQUIRED_ASSET_ROOTS + [PREFAB_BINARY_ROOT],
		"entries": entries,
	}


func _read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}

	var text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Asset Manifest Checker: %s is not valid manifest JSON." % MANIFEST_PATH)
		return {}

	return data


func _manifest_entries_by_path(manifest: Dictionary) -> Dictionary:
	var entries_by_path := {}
	var entries = manifest.get("entries", [])
	if typeof(entries) != TYPE_ARRAY:
		return entries_by_path

	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var path := _normalize_project_path(str(entry.get("path", "")))
		if path.is_empty():
			continue
		entry["path"] = path
		entries_by_path[path] = entry

	return entries_by_path


func _discover_local_assets(include_hashes: bool) -> Dictionary:
	var assets := {}

	for root in REQUIRED_ASSET_ROOTS:
		_scan_asset_directory(root, root, assets, include_hashes, true)

	_scan_asset_directory(PREFAB_BINARY_ROOT, PREFAB_BINARY_ROOT, assets, include_hashes, true)
	_scan_root_exports(assets, include_hashes)

	return assets


func _scan_asset_directory(root: String, package_name: String, assets: Dictionary, include_hashes: bool, binary_only: bool) -> void:
	var res_root := "res://%s" % root
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(res_root)):
		return

	_scan_asset_directory_recursive(res_root, package_name, assets, include_hashes, binary_only)


func _scan_asset_directory_recursive(res_dir: String, package_name: String, assets: Dictionary, include_hashes: bool, binary_only: bool) -> void:
	var dir := DirAccess.open(res_dir)
	if dir == null:
		return

	for file_name in dir.get_files():
		var res_path := "%s/%s" % [res_dir, file_name]
		var project_path := _project_path(res_path)
		if binary_only and not _has_extension(project_path, BINARY_EXTENSIONS):
			continue
		assets[project_path] = _asset_entry(project_path, package_name, include_hashes)

	for directory_name in dir.get_directories():
		if directory_name.begins_with("."):
			continue
		_scan_asset_directory_recursive("%s/%s" % [res_dir, directory_name], package_name, assets, include_hashes, binary_only)


func _scan_root_exports(assets: Dictionary, include_hashes: bool) -> void:
	var dir := DirAccess.open("res://")
	if dir == null:
		return

	for file_name in dir.get_files():
		if not _has_extension(file_name, ROOT_EXPORT_EXTENSIONS):
			continue
		assets[file_name] = _asset_entry(file_name, "Root exports", include_hashes)


func _asset_entry(project_path: String, package_name: String, include_hash: bool) -> Dictionary:
	var entry := {
		"path": project_path,
		"package": package_name,
		"size": _file_size_for_project_path(project_path),
		"modified_time": FileAccess.get_modified_time("res://%s" % project_path),
	}
	if include_hash:
		entry["sha256"] = _sha256_for_project_path(project_path)
	return entry


func _file_size_for_project_path(project_path: String) -> int:
	var file := FileAccess.open("res://%s" % project_path, FileAccess.READ)
	if file == null:
		return -1
	var size := file.get_length()
	file.close()
	return size


func _sha256_for_project_path(project_path: String) -> String:
	return FileAccess.get_sha256("res://%s" % project_path)


func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.store_string("\n")
	file.close()
	return true


func _load_report(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


func _ensure_report_dir() -> void:
	var absolute_dir := ProjectSettings.globalize_path("res://.godot/asset_manifest_checker")
	DirAccess.make_dir_recursive_absolute(absolute_dir)


func _has_report_issues(report: Dictionary) -> bool:
	if report.is_empty() or not report.has("summary"):
		return false
	var summary: Dictionary = report["summary"]
	return int(summary.get("missing", 0)) > 0 or int(summary.get("changed", 0)) > 0 or int(summary.get("extra", 0)) > 0


func _show_report(report: Dictionary, title: String) -> void:
	if not is_instance_valid(_dialog):
		_dialog = AcceptDialog.new()
		_dialog.min_size = Vector2i(900, 600)
		get_editor_interface().get_base_control().add_child(_dialog)

	for child in _dialog.get_children():
		_dialog.remove_child(child)
		child.queue_free()

	_dialog.title = title
	_dialog.get_ok_button().text = "Close"

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.text = _format_report(report)
	_dialog.add_child(label)
	_dialog.popup_centered()


func _format_report(report: Dictionary) -> String:
	if report.is_empty():
		return "[b]Asset manifest report is empty.[/b]"

	var summary: Dictionary = report.get("summary", {})
	var lines := [
		"[b]Asset Manifest Checker[/b]",
		"Checked: %s" % report.get("checked_at", "unknown"),
		"Manifest: %s" % report.get("manifest_path", _project_path(MANIFEST_PATH)),
		"",
		"OK: %s   Missing: %s   Changed: %s   Extra: %s" % [
			summary.get("ok", 0),
			summary.get("missing", 0),
			summary.get("changed", 0),
			summary.get("extra", 0),
		],
		"",
	]

	if not _has_report_issues(report):
		lines.append("[color=green]All manifest assets are up to date.[/color]")
		return "\n".join(lines)

	_append_issue_section(lines, "Missing", report.get("missing", []))
	_append_issue_section(lines, "Changed", report.get("changed", []))
	_append_issue_section(lines, "Extra", report.get("extra", []))

	return "\n".join(lines)


func _append_issue_section(lines: Array, title: String, issues: Array) -> void:
	if issues.is_empty():
		return
	lines.append("[b]%s[/b]" % title)
	for issue in issues:
		if typeof(issue) == TYPE_DICTIONARY:
			lines.append("- %s: %s" % [issue.get("path", ""), issue.get("reason", "")])
		else:
			lines.append("- %s" % str(issue))
	lines.append("")


func _project_path(path: String) -> String:
	return _normalize_project_path(path)


func _normalize_project_path(path: String) -> String:
	var normalized := path.replace("\\", "/")
	if normalized.begins_with("res://"):
		normalized = normalized.substr(6)
	while normalized.begins_with("/"):
		normalized = normalized.substr(1)
	return normalized


func _has_extension(path: String, extensions: Array) -> bool:
	var extension := path.get_extension().to_lower()
	return extensions.has(extension)
