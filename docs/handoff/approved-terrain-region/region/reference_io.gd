extends RefCounted
## A source checkout can run before an editor import. Exported packs use Godot imports.

static func texture(path: String) -> Texture2D:
	if FileAccess.file_exists(path):
		var data := FileAccess.get_file_as_bytes(path)
		var image := Image.new()
		var err := ERR_FILE_UNRECOGNIZED
		match path.get_extension().to_lower():
			"png": err = image.load_png_from_buffer(data)
			"jpg", "jpeg": err = image.load_jpg_from_buffer(data)
		if err == OK:
			image.generate_mipmaps()
			return ImageTexture.create_from_image(image)
	var imported := ResourceLoader.load(path, "Texture2D") as Texture2D
	if imported == null:
		return null
	var image := imported.get_image()
	if image == null or image.is_empty():
		return imported
	if image.is_compressed() and image.decompress() != OK:
		return imported
	if not image.has_mipmaps():
		image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func shader(path: String) -> Shader:
	if FileAccess.file_exists(path):
		var code := FileAccess.get_file_as_string(path).trim_prefix("\ufeff")
		if not code.is_empty():
			var program := Shader.new()
			program.code = code
			return program
	return ResourceLoader.load(path, "Shader") as Shader
