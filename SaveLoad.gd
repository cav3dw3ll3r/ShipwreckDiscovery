extends Node
class_name SaveSystem

const SAVE_FORMAT_VERSION := 4
const SAVE_FILE_NAME := "game_save.json"
const SAVE_FORMAT_VERSION_KEY := "SAVE_FORMAT_VERSION"

# Save directory where game data will be stored
var save_dir = "user://"
var saveable_entities: Array = []
var data: Dictionary = {}

func register_saveable(saveable):
	saveable_entities.append(saveable)

func remove_saveable(saveable):
	saveable_entities.erase(saveable)

func save_all():
	for entity in saveable_entities:
		data[entity.uuid]=entity.get_state()
	write_to_file()

func save_node(uuid:String):
	pass

func restore_all():
	var to_remove = []
	for entity in saveable_entities:
		if not is_instance_valid(entity):
			to_remove.append(entity)

	for entity in to_remove:
		saveable_entities.erase(entity)
	for entity in saveable_entities:
		if entity.uuid in data:
			entity.restore_state(data[entity.uuid])
		elif entity.has_method("initialize_new_campaign"):
			entity.initialize_new_campaign()

func restore_node(uuid:String):
	pass

# Function to save the game data to a file
func write_to_file():
	data[SAVE_FORMAT_VERSION_KEY] = SAVE_FORMAT_VERSION
	var file = FileAccess.open(save_dir + SAVE_FILE_NAME, FileAccess.WRITE)
	if file:
		# Serialize and save the game data
		file.store_line(JSON.stringify(data))  # Assuming gameData has a `data` dictionary
		file.close()

# Function to load the game data from a file
func read_from_file():
	var save_path = save_dir + SAVE_FILE_NAME
	if not FileAccess.file_exists(save_path):
		data = {}
		return

	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		data = {}
		return

	var json_data = file.get_as_text()
	var parsed_data = JSON.parse_string(json_data)  # Load data back into the game
	file.close()

	if typeof(parsed_data) != TYPE_DICTIONARY:
		data = {}
		_delete_save_file()
		return

	data = parsed_data
	if int(data.get(SAVE_FORMAT_VERSION_KEY, 0)) < SAVE_FORMAT_VERSION:
		data = {}
		_delete_save_file()

func _delete_save_file():
	var dir = DirAccess.open(save_dir)
	if dir:
		dir.remove(SAVE_FILE_NAME)
