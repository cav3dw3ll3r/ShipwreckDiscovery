@tool
extends EditorPlugin

var panel

func _enter_tree():
	# Create a custom panel
	panel = PanelContainer.new()
	panel.name = "Terrain Generator"
	
	# Add UI components to the panel
	var vbox = VBoxContainer.new()
	
	var heightmap_label = Label.new()
	heightmap_label.text = "Heightmap Texture:"
	vbox.add_child(heightmap_label)
	
	var heightmap_path = FileDialog.new()
	heightmap_path.mode = FileDialog.FILE_MODE_OPEN_FILE
	heightmap_path.filters = ["*.png", "*.jpg"]
	vbox.add_child(heightmap_path)
	
	var generate_button = Button.new()
	generate_button.text = "Generate Terrain"
	generate_button.connect("pressed", _on_generate_button_pressed)
	vbox.add_child(generate_button)
	
	panel.add_child(vbox)
	
	# Add the panel to the editor
	add_control_to_dock(DOCK_SLOT_LEFT_UL, panel)

func _exit_tree():
	# Remove the panel when the plugin is disabled
	self.remove_control_from_docks(panel)

func _on_generate_button_pressed():
	var heightmap_texture_path =                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        
	if heightmap_texture_path == "":
		return
	
	# Generate the terrain mesh (implement your existing logic here)
	var mesh = generate_terrain_mesh(heightmap_texture_path)
	if mesh:
		save_mesh_to_file(mesh, "res://generated_terrain.mesh")

func generate_terrain_mesh(heightmap_path: String) -> Mesh:
	var image = Image.new()
	image.load(heightmap_path)
	image.lock()
	
	var mesh = ArrayMesh.new()
	var vertices = []
	var uvs = []
	var indices = []
	
	# Create vertices from the heightmap
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var height = image.get_pixel(x, y).r
			vertices.append(Vector3(x, height * 10, y))  # Scale the height as needed
			uvs.append(Vector2(x / image.get_width(), y / image.get_height()))
	
	# Generate indices for a grid (triangle strip)
	for y in range(image.get_height() - 1):
		for x in range(image.get_width() - 1):
			var i = y * image.get_width() + x
			indices.append(i)
			indices.append(i + 1)
			indices.append(i + image.get_width())
			indices.append(i + 1)
			indices.append(i + image.get_width() + 1)
			indices.append(i + image.get_width())
	
	# Create the mesh surface
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, [vertices, uvs], indices)
	image.unlock()
	return mesh

func save_mesh_to_file(mesh: Mesh, save_path: String):
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	ResourceSaver.save(save_path, mesh)
