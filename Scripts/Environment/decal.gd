extends Decal

func process(delta:float):
	update_viewport_png()

func update_viewport_png():
	texture_albedo = $SubViewport.get_texture()
	
