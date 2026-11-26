extends RefCounted
## Raw district assets (1.12): the approved district's textures are kept as files (their imports
## say `keep`) and its shaders and meshes are read as written, so the export filter carries them
## as they are (export_presets.cfg, assets/district). From the handoff's reference_io.gd.


static func texture(path: String) -> Texture2D:
	if FileAccess.file_exists(path):
		var data: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var image := Image.new()
		var err: int = ERR_FILE_UNRECOGNIZED
		match path.get_extension().to_lower():
			"png":
				err = image.load_png_from_buffer(data)
			"jpg", "jpeg":
				err = image.load_jpg_from_buffer(data)
		if err == OK:
			image.generate_mipmaps()
			return ImageTexture.create_from_image(image)
	var imported := ResourceLoader.load(path, "Texture2D") as Texture2D
	if imported == null:
		return null
	var image: Image = imported.get_image()
	if image == null or image.is_empty():
		return imported
	if image.is_compressed() and image.decompress() != OK:
		return imported
	if not image.has_mipmaps():
		image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func shader(path: String) -> Shader:
	if FileAccess.file_exists(path):
		var code: String = FileAccess.get_file_as_string(path).trim_prefix("﻿")
		if not code.is_empty():
			var program := Shader.new()
			program.code = code
			return program
	return ResourceLoader.load(path, "Shader") as Shader
