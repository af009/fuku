extends RefCounted
class_name ConfigManager

signal api_key_changed(backend_name: String, api_key: String)

var env_handler: EnvHandler
var current_backend: String = "ollama"
var api_keys: Dictionary = {}

func _init() -> void:
	env_handler = EnvHandler.new()

# Load API keys from .env file
func load_api_keys() -> void:
	var env_vars = env_handler.load_env_file()

	api_keys.clear()

	if env_vars.has("OPENAI_API_KEY"):
		var decoded_key = env_handler.decode_base64(env_vars["OPENAI_API_KEY"])
		if not decoded_key.is_empty():
			api_keys["openai"] = decoded_key

	if env_vars.has("CLAUDE_API_KEY"):
		var decoded_key = env_handler.decode_base64(env_vars["CLAUDE_API_KEY"])
		if not decoded_key.is_empty():
			api_keys["claude"] = decoded_key

	if env_vars.has("GEMINI_API_KEY"):
		var decoded_key = env_handler.decode_base64(env_vars["GEMINI_API_KEY"])
		if not decoded_key.is_empty():
			api_keys["gemini"] = decoded_key

# Save API key to .env file
func save_api_key(backend_name: String, api_key: String) -> bool:
	if api_key.is_empty():
		return false

	api_keys[backend_name] = api_key

	var env_vars = env_handler.load_env_file()
	var key_name = _get_env_key_name(backend_name)

	if not key_name.is_empty():
		env_vars[key_name] = env_handler.encode_base64(api_key)
		var success = env_handler.save_env_file(env_vars)
		if success:
			api_key_changed.emit(backend_name, api_key)
		return success

	return false

# Get API key for specific backend
func get_api_key(backend_name: String) -> String:
	return api_keys.get(backend_name, "")

# Get environment variable key name for backend
func _get_env_key_name(backend_name: String) -> String:
	match backend_name.to_lower():
		"openai":
			return "OPENAI_API_KEY"
		"claude":
			return "CLAUDE_API_KEY"
		"gemini":
			return "GEMINI_API_KEY"
		_:
			return ""

# Set current backend
func set_current_backend(backend_name: String) -> void:
	current_backend = backend_name

# Get current backend
func get_current_backend() -> String:
	return current_backend
