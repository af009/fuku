extends BaseBackend
class_name GeminiBackend

# Google Gemini API backend
# https://ai.google.dev/gemini-api/docs

func _init() -> void:
	base_url = "https://generativelanguage.googleapis.com"
	setup_headers()

func get_chat_endpoint() -> String:
	# Note: Model name is added dynamically in build_request_body
	return "/v1beta/models"

func get_models_endpoint() -> String:
	return "/v1beta/models"

func setup_headers() -> void:
	# Gemini uses x-goog-api-key header instead of Authorization
	headers = ["Content-Type: application/json"]
	if not api_key.is_empty():
		headers.append("x-goog-api-key: " + api_key)

func set_api_key(key: String) -> void:
	api_key = key
	setup_headers()

func build_request_body(messages: Array, model: String, system_content: String = "") -> Dictionary:
	var contents: Array = []

	# Add system instruction if provided (Gemini handles it differently)
	# System instructions go in a separate field, not in contents
	var has_system = not system_content.is_empty()

	# Convert messages to Gemini format
	for msg in messages:
		var role = msg.get("role", "user")
		var content = msg.get("content", "")

		# Gemini uses "model" instead of "assistant"
		if role == "assistant":
			role = "model"

		contents.append({
			"role": role,
			"parts": [{"text": content}]
		})

	var body = {
		"contents": contents
	}

	# Add system instruction if provided
	if has_system:
		body["systemInstruction"] = {
			"parts": [{"text": system_content}]
		}

	return body

func extract_message_from_response(response: Dictionary) -> String:
	# Gemini response format:
	# { "candidates": [{ "content": { "parts": [{ "text": "..." }] } }] }
	if response.has("candidates") and response["candidates"].size() > 0:
		var candidate = response["candidates"][0]
		if candidate.has("content"):
			var content = candidate["content"]
			if content.has("parts") and content["parts"].size() > 0:
				var parts = content["parts"]
				if parts[0].has("text"):
					return parts[0]["text"]
	return ""

func parse_models_response(response: Dictionary) -> Array:
	if not response.has("models"):
		return []

	var models: Array = []
	for model_data in response["models"]:
		if model_data.has("name"):
			# Extract model name from full path: "models/gemini-2.5-flash" -> "gemini-2.5-flash"
			var full_name = model_data["name"]
			var model_name = full_name.split("/")[-1]

			# Only include generateContent-capable models
			if model_data.has("supportedGenerationMethods"):
				var methods = model_data["supportedGenerationMethods"]
				if "generateContent" in methods:
					models.append(model_name)

	return models

func get_default_models() -> Array:
	return [
		"gemini-2.5-flash",
		"gemini-2.5-pro",
		"gemini-1.5-flash",
		"gemini-1.5-pro"
	]

func get_provider_name() -> String:
	return "Google Gemini"

# Override to add model name to endpoint and API key as query parameter
func get_full_chat_url(model: String) -> String:
	return base_url + "/v1beta/models/" + model + ":generateContent?key=" + api_key
