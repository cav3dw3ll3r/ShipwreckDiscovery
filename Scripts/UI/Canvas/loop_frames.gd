extends ColorRect

@export_dir var frames_path:String
@export var frame_rate = 24
@export var uv_scale = 0.1

var frames: Array[ImageTexture] = []
var current_frame = 0
var accumulator = 0

func _ready() -> void:
	# Load all images from the folder
	if frames_path == "":
		return

	var dir = DirAccess.open(frames_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir():
				var tex = ImageTexture.new()
				var img = Image.new()
				img.load(dir.get_current_dir() + "/" + file_name)
				if(img):
					tex.create_from_image(img)
				else:
					print
				frames.append(tex)
			file_name = dir.get_next()
		dir.list_dir_end()

func _process(delta: float) -> void:
	accumulator += delta
	if accumulator >= 1.0 / frame_rate:
		accumulator -= 1.0 / frame_rate
		update_tex()

func update_tex():
	if frames.size() == 0:
		return
	var mat = self.material
	mat.set_shader_parameter("frame_tex", frames[current_frame])
	mat.set_shader_parameter("uv_scale",uv_scale)
	current_frame = (current_frame + 1) % frames.size()
