extends Node

func _ready():
	if OS.get_name() == "Android":
		request_permissions()
	else:
		call_deferred("load_main")


func request_permissions() -> void:
	if OS.request_permissions():
		mount_and_launch()
	else:
		$Timer.start() # retry

func analyze_vfs(root_path: String, critical_files: Array):
	var state = {
		"total_files": 0,
		"found": {}
	}
	
	for f in critical_files:
		state["found"][f] = "MISSING"

	_recursive_scan(root_path, critical_files, state)

func _recursive_scan(path: String, targets: Array, state: Dictionary):
	var dir = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		if dir.current_is_dir():
			# Recurse
			_recursive_scan(path + file_name + "/", targets, state)
		else:
			state["total_files"] += 1
			
			# Check against targets
			for target in targets:
				if file_name == target:
					state["found"][target] = "FOUND (Exact) at " + path
				elif file_name == target + ".remap":
					state["found"][target] = "FOUND (Remapped .remap) at " + path
				elif file_name.trim_suffix(".remap") == target:
					state["found"][target] = "FOUND (Remapped) at " + path
				elif file_name.to_lower() == target.to_lower():
					state["found"][target] = "FOUND (Case Mismatch) at " + path
					
		file_name = dir.get_next()

func mount_and_launch():
	var pck_dir := "/sdcard/Android/obb/com.mi.shipwreckD"
	# ^ Choose whatever directory you store your multi-PCKs in

	var dir := DirAccess.open(pck_dir)
	if dir == null:
		push_error("PCK directory not found: " + pck_dir)
		return

	dir.list_dir_begin()
	var dir_name = dir.get_next()
	var mounted_any = false

	while dir_name != "":
		if not dir.current_is_dir():
			if dir_name.ends_with(".pck"):
				var full_path = pck_dir+"/" + dir_name

				if ProjectSettings.load_resource_pack(full_path,false):
					analyze_vfs("res://",["Main.tscn"])
					mounted_any = true
				else:
					push_error("Failed to mount: " + full_path)

		dir_name = dir.get_next()

	dir.list_dir_end()

	if not mounted_any:
		push_error("No PCK files mounted!")
		return
	
	# Pre-launch checks
	launch_with_age_compliance()

func launch_with_age_compliance() -> void:
	# 1. Non-Android/Editor Safety Check
	if OS.get_name() != "Android":
		print("PC mode detected. Bypassing Meta Platform SDK initialization.")
		call_deferred("load_main")
		return

	# 2. Verify Godot registered the GDExtension singleton globally
	if Engine.has_singleton("MetaPlatformSDK") or ClassDB.class_exists("MetaPlatformSDK"):
		print("Meta Platform SDK Extension detected. Initializing...")
		
		var init_msg = await MetaPlatformSDK.initialize_platform_async("32767209856226296").completed
		print("Init MSG: "+str(init_msg))
		if init_msg.is_error():
			push_warning("Meta SDK Init Failed: " + str(init_msg.error))
			call_deferred("load_main")
			return
			
		print("Meta SDK successfully initialized. Querying age category...")

		# 3. Request the Age Category from the platform
		var age_msg = await MetaPlatformSDK.user_age_category_get_async().completed
		print("AGE_MSG: "+str(age_msg.data))
		if not age_msg or age_msg.is_error():
			push_warning("Could not retrieve age category: " + str(age_msg.error))
		else:
			# age_msg.data contains the resulting profile structure
			var age_category:MetaPlatformSDK_UserAccountAgeCategory = age_msg.get_user_account_age_category()
			print("User Age Category verified: ", age_category)
			
			# Universal platform gate check (Optional)
			# Standard strings returned are typically: "CH" (Child 10-12), "TN" (Teen), "AD" (Adult)
			if age_category.age_category==1:
				print("User is classified as a child. (No action needed since game is completely offline).")
			#if age_category.age_category==2:
				#pass
			#if age_category.age_category==3:
				#pass
	else:
		push_warning("CRITICAL: MetaPlatformSDK singleton is missing from the GDExtension runtime registry.")

	# 4. Safe landing to hand off to your PCK loading process
	call_deferred("load_main")

func load_main():
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")
