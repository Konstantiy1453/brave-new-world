extends RefCounted
## Picture quality. Standard is Godot's Compatibility renderer (OpenGL 3.3, any graphics card);
## high is Forward+ (Vulkan or Direct3D 12), which adds ambient occlusion, soft shadows, bloom and
## lamp lights. The choice lives in a project-settings override in the player's folder
## (`application/config/project_settings_override`), which Godot reads before it opens the window,
## so it applies on the next start. A computer that cannot run Forward+ starts in Compatibility on
## its own (`rendering/rendering_device/fallback_to_opengl3`). Anti-aliasing applies at once.

const OVERRIDE: String = "user://graphics_override.cfg"
const SECTION: String = "rendering"
const METHOD_KEY: String = "renderer/rendering_method"
const HIGH: String = "forward_plus"
const STANDARD: String = "gl_compatibility"
## Anti-aliasing levels, saved in settings.cfg as visual/aa.
const AA_OFF: String = "off"
const AA_MEDIUM: String = "medium"
const AA_HIGH: String = "high"
const AA_LEVELS: Array[String] = [AA_OFF, AA_MEDIUM, AA_HIGH]
const AA_DEFAULT: String = AA_HIGH

## What was chosen when this run started, read once: a fallback is a start with high quality
## chosen that runs the standard renderer; a choice made since then waits for a restart.
static var _started: String = ""


## The renderer this run uses: "forward_plus", "mobile" or "gl_compatibility".
static func running() -> String:
	return RenderingServer.get_current_rendering_method()


static func high_running() -> bool:
	return running() != STANDARD


## The renderer the player chose for the next start.
static func chosen() -> String:
	var file := ConfigFile.new()
	if file.load(OVERRIDE) != OK:
		return STANDARD
	return str(file.get_value(SECTION, METHOD_KEY, STANDARD))


## Saves the choice for the next start. Standard removes the override, so the project's own
## settings apply again.
static func choose(method: String) -> void:
	if method == STANDARD:
		if FileAccess.file_exists(OVERRIDE):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(OVERRIDE))
		return
	var file := ConfigFile.new()
	file.set_value(SECTION, METHOD_KEY, method)
	file.save(OVERRIDE)


## The choice this run started with. main.gd reads it first thing, before anything can change it.
static func start_choice() -> String:
	if _started == "":
		_started = chosen()
	return _started


## This run started with high quality chosen, but the computer could not run it: Godot fell back
## to Compatibility.
static func fell_back() -> bool:
	return start_choice() == HIGH and running() == STANDARD


## The choice differs from what runs, and a restart would change that: not when this computer
## already fell back from high quality.
static func restart_pending() -> bool:
	if chosen() == HIGH:
		return running() == STANDARD and not fell_back()
	return running() != STANDARD


## Multisampling smooths the edges of models, roads and terrain in both renderers; Forward+ adds
## SMAA for the edges inside textures and shaders.
static func apply_anti_aliasing(viewport: Viewport, level: String) -> void:
	match level:
		AA_OFF:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		AA_MEDIUM:
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		_:
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = (
				Viewport.SCREEN_SPACE_AA_SMAA
				if high_running()
				else Viewport.SCREEN_SPACE_AA_DISABLED
			)


## What the settings page says about the renderer.
static func status_text() -> String:
	if fell_back() and chosen() == HIGH:
		return "已选择高画质，但这台电脑的显卡不支持 Vulkan 或 Direct3D 12，已自动以标准画质运行"
	var now: String = "高画质（Forward+）" if high_running() else "标准画质（兼容渲染）"
	if restart_pending():
		var next: String = "高画质" if chosen() == HIGH else "标准画质"
		return "当前：%s · 重启游戏后改为%s" % [now, next]
	return "当前：" + now
