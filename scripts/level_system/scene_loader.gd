class_name SceneLoader
extends Node
## Manages asynchronous loading and unloading of scenes using ResourceLoader.
## Provides signals for progress tracking, completion, and error handling with retry logic.

# --- Signals ---
signal scene_loaded(scene: PackedScene)
signal load_progress_updated(progress: float)
signal load_failed(path: String, error: String)

# --- State ---
var _loading_path: String = ""
var _is_loading: bool = false
var _retry_count: int = 0
const MAX_RETRIES: int = 1

# --- Public Methods ---

## Requests asynchronous loading of a scene. Guards against duplicate requests.
func request_load(scene_path: String) -> void:
	if _is_loading:
		push_warning("SceneLoader: Already loading a scene, ignoring request for: " + scene_path)
		return
	_loading_path = scene_path
	_is_loading = true
	_retry_count = 0
	_start_load(scene_path)


## Fire-and-forget preloading during Entre_Nivel to minimize wait times.
func preload_scene(scene_path: String) -> void:
	ResourceLoader.load_threaded_request(scene_path)


## Safely unloads a scene by calling queue_free() on its root node.
func unload_scene(scene_root: Node) -> void:
	if scene_root and is_instance_valid(scene_root):
		scene_root.queue_free()


# --- Private Methods ---

func _start_load(path: String) -> void:
	var error := ResourceLoader.load_threaded_request(path)
	if error != OK:
		_handle_load_error("Failed to start threaded load: " + str(error))
		return
	set_process(true)


func _process(_delta: float) -> void:
	if not _is_loading:
		set_process(false)
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_loading_path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if progress.size() > 0:
				load_progress_updated.emit(progress[0])
		ResourceLoader.THREAD_LOAD_LOADED:
			var resource := ResourceLoader.load_threaded_get(_loading_path)
			_is_loading = false
			set_process(false)
			scene_loaded.emit(resource as PackedScene)
		ResourceLoader.THREAD_LOAD_FAILED:
			_handle_load_error("Threaded load failed for: " + _loading_path)


func _handle_load_error(error_msg: String) -> void:
	push_error("SceneLoader: " + error_msg)
	if _retry_count < MAX_RETRIES:
		_retry_count += 1
		push_warning("SceneLoader: Retrying load (attempt %d)" % (_retry_count + 1))
		_start_load(_loading_path)
	else:
		_is_loading = false
		set_process(false)
		load_failed.emit(_loading_path, error_msg)
