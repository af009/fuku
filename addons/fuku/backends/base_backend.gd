extends RefCounted
class_name BaseBackend

# Abstract base class for AI backend providers
# All backend implementations should inherit from this class

signal response_received(response: Dictionary)
signal error_occurred(error_message: String)
signal models_fetched(models: Array)

var base_url: String = ""
var headers: Array = []
var api_key: String = ""

# Abstract method to be implemented by child classes
func get_chat_endpoint() -> String:
	push_error("get_chat_endpoint() must be implemented by child class")
	return ""

# Abstract method to be implemented by child classes
func get_models_endpoint() -> String:
	push_error("get_models_endpoint() must be implemented by child class")
	return ""

# Abstract method to be implemented by child classes
func build_request_body(messages: Array, model: String, system_content: String = "") -> Dictionary:
	push_error("build_request_body() must be implemented by child class")
	return {}

# Abstract method to be implemented by child classes
func extract_message_from_response(response: Dictionary) -> String:
	push_error("extract_message_from_response() must be implemented by child class")
	return ""

# Abstract method to be implemented by child classes
func parse_models_response(response: Dictionary) -> Array:
	push_error("parse_models_response() must be implemented by child class")
	return []

# Virtual method for setting up headers with API key
func setup_headers() -> void:
	headers = ["Content-Type: application/json"]

# Virtual method to get default models if API doesn't provide list
func get_default_models() -> Array:
	return []

# Virtual method to get max tokens (0 means no limit or use API default)
func get_max_tokens() -> int:
	return 0

# Helper to set API key
func set_api_key(key: String) -> void:
	api_key = key
	setup_headers()

# Virtual method to get provider display name
func get_provider_name() -> String:
	return "AI Provider"
