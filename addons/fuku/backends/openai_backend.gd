extends BaseBackend
class_name OpenAIBackend

func _init() -> void:
	base_url = "https://api.openai.com/v1"

func get_chat_endpoint() -> String:
	return "/chat/completions"

func get_models_endpoint() -> String:
	return "/models"

func setup_headers() -> void:
	headers = ["Content-Type: application/json"]
	if not api_key.is_empty():
		headers.append("Authorization: Bearer " + api_key)

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
	if not response.has("data"):
		return get_default_models()

	var models: Array = []
	for model_data in response["data"]:
		if model_data.has("id"):
			var model_id = model_data["id"]
			if not model_id.is_empty():
				models.append(model_id)

	return models if not models.is_empty() else get_default_models()

func get_default_models() -> Array:
	return ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"]

func get_provider_name() -> String:
	return "OpenAI"
