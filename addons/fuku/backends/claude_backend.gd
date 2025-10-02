extends BaseBackend
class_name ClaudeBackend

func _init() -> void:
	base_url = "https://api.anthropic.com/v1"

func get_chat_endpoint() -> String:
	return "/messages"

func get_models_endpoint() -> String:
	return "" # Claude doesn't have a models list endpoint

func setup_headers() -> void:
	headers = ["Content-Type: application/json"]
	if not api_key.is_empty():
		headers.append("x-api-key: " + api_key)
		headers.append("anthropic-version: 2023-06-01")

func build_request_body(messages: Array, model: String, system_content: String = "") -> Dictionary:
	var formatted_messages: Array = []

	# Claude requires user message first, system content goes in a separate field
	# Combine system content with first user message
	var first_message_content = system_content
	if not system_content.is_empty():
		first_message_content += "\n\n"

	if messages.size() > 0 and messages[0].has("content"):
		first_message_content += messages[0]["content"]
		formatted_messages.append({"role": "user", "content": first_message_content})

		# Add remaining messages
		for i in range(1, messages.size()):
			formatted_messages.append(messages[i])
	else:
		formatted_messages.append({"role": "user", "content": first_message_content})

	return {
		"model": model,
		"max_tokens": get_max_tokens(),
		"messages": formatted_messages
	}

func extract_message_from_response(response: Dictionary) -> String:
	if response.has("content") and response["content"].size() > 0:
		var content_item = response["content"][0]
		if content_item.has("text"):
			return content_item["text"]
	return ""

func parse_models_response(_response: Dictionary) -> Array:
	return get_default_models()

func get_default_models() -> Array:
	return [
		"claude-sonnet-4-5-20250929",
		"claude-opus-4-1-20250805",
		"claude-opus-4-20250514",
		"claude-sonnet-4-20250514",
		"claude-3-7-sonnet-20250219",
		"claude-3-5-haiku-20241022",
		"claude-3-haiku-20240307"
	]

func get_max_tokens() -> int:
	return 4096

func get_provider_name() -> String:
	return "Claude"
