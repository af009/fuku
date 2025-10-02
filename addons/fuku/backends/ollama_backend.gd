extends BaseBackend
class_name OllamaBackend

func _init() -> void:
	base_url = "http://127.0.0.1:11434"
	setup_headers()

func get_chat_endpoint() -> String:
	return "/v1/chat/completions"

func get_models_endpoint() -> String:
	return "/api/tags"

func setup_headers() -> void:
	headers = ["Content-Type: application/json"]

func build_request_body(messages: Array, model: String, system_content: String = "") -> Dictionary:
	var formatted_messages: Array = []

	if not system_content.is_empty():
		formatted_messages.append({"role": "system", "content": system_content})

	for msg in messages:
		formatted_messages.append(msg)

	return {
		"model": model,
		"messages": formatted_messages
	}

func extract_message_from_response(response: Dictionary) -> String:
	if response.has("choices") and response["choices"].size() > 0:
		var choice = response["choices"][0]
		if choice.has("message") and choice["message"].has("content"):
			return choice["message"]["content"]
	return ""

func parse_models_response(response: Dictionary) -> Array:
	if not response.has("models"):
		return []

	var models: Array = []
	for model_data in response["models"]:
		if model_data.has("name"):
			models.append(model_data["name"])

	return models

func get_default_models() -> Array:
	return []

func get_provider_name() -> String:
	return "Ollama"
