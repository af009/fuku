extends RefCounted
class_name BackendManager

signal models_fetched(models: Array)
signal response_received(message: String)
signal error_occurred(error_message: String)

var current_backend: BaseBackend
var http_request: HTTPRequest
var selected_model: String = ""

enum BackendType { OLLAMA, OPENAI, CLAUDE, DOCKER, GEMINI }

func _init(request_node: HTTPRequest) -> void:
	http_request = request_node
	http_request.request_completed.connect(_on_request_completed)
	set_backend(BackendType.OLLAMA)

# Set the active backend
func set_backend(backend_type: BackendType, api_key: String = "") -> void:
	match backend_type:
		BackendType.OLLAMA:
			current_backend = OllamaBackend.new()
		BackendType.OPENAI:
			current_backend = OpenAIBackend.new()
		BackendType.CLAUDE:
			current_backend = ClaudeBackend.new()
		BackendType.DOCKER:
			current_backend = DockerBackend.new()
		BackendType.GEMINI:
			current_backend = GeminiBackend.new()

	if not api_key.is_empty():
		current_backend.set_api_key(api_key)

# Fetch available models from backend
func fetch_models() -> void:
	var endpoint = current_backend.get_models_endpoint()

	if endpoint.is_empty():
		var default_models = current_backend.get_default_models()
		models_fetched.emit(default_models)
		return

	_make_request(endpoint, HTTPClient.METHOD_GET)

# Send chat request to backend
func send_chat_request(messages: Array, model: String, system_content: String = "") -> void:
	var body = current_backend.build_request_body(messages, model, system_content)

	# Check if backend has custom URL builder (for Gemini)
	if current_backend.has_method("get_full_chat_url"):
		var url = current_backend.get_full_chat_url(model)
		var error: Error = http_request.request(url, current_backend.headers, HTTPClient.METHOD_POST, JSON.stringify(body))
		if error != OK:
			error_occurred.emit("Unable to make request to: " + url)
	else:
		var endpoint = current_backend.get_chat_endpoint()
		_make_request(endpoint, HTTPClient.METHOD_POST, JSON.stringify(body))

# Make HTTP request
func _make_request(endpoint: String, method: int, body: String = "") -> void:
	var url = current_backend.base_url + endpoint

	# Add API key as query parameter for Gemini models endpoint
	if current_backend is GeminiBackend and endpoint.contains("/models") and not endpoint.contains("generateContent"):
		url += "?key=" + current_backend.api_key

	var error: Error = http_request.request(url, current_backend.headers, method, body)

	if error != OK:
		error_occurred.emit("Unable to make request to: " + url)

# Handle HTTP request completion
func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		var provider_name = current_backend.get_provider_name()
		var error_msg = _format_error_message(response_code, body.get_string_from_utf8(), provider_name)
		error_occurred.emit(error_msg)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		error_occurred.emit("Invalid JSON response.")
		return

	var response: Dictionary = json.data

	if response.has("models") or response.has("data"):
		var models = current_backend.parse_models_response(response)
		models_fetched.emit(models)
	elif response.has("choices") or response.has("content") or response.has("candidates"):
		var message = current_backend.extract_message_from_response(response)
		if message.is_empty():
			error_occurred.emit("Failed to extract message from response")
		else:
			response_received.emit(message)
	else:
		error_occurred.emit("Unexpected response format")

# Update API key for current backend
func update_api_key(api_key: String) -> void:
	if current_backend:
		current_backend.set_api_key(api_key)

# Set selected model
func set_model(model: String) -> void:
	selected_model = model

# Get selected model
func get_model() -> String:
	return selected_model

# Format error message with provider-specific context
func _format_error_message(response_code: int, response_text: String, provider_name: String) -> String:
	var error_msg = ""

	# Specific handling for common HTTP errors
	match response_code:
		0:
			# Connection failed - most common issue
			error_msg = _get_connection_error_message(provider_name)
		401:
			error_msg = "❌ Authentication Failed\n\n"
			error_msg += "Your API key for %s is incorrect or has expired.\n" % provider_name
			error_msg += "Please check your API key and try again."
		403:
			error_msg = "🚫 Access Denied\n\n"
			error_msg += "Your API key doesn't have permission to access %s.\n" % provider_name
			error_msg += "Please verify your subscription status and API key permissions."
		404:
			error_msg = "🔍 Not Found\n\n"
			error_msg += "The %s API endpoint was not found.\n" % provider_name
			error_msg += "This might indicate a service issue or incorrect configuration."
		429:
			error_msg = "⏱️ Rate Limit Exceeded\n\n"
			error_msg += "You've made too many requests to %s.\n" % provider_name
			error_msg += "Please wait a few moments and try again."
		500, 502, 503:
			error_msg = "⚠️ Server Error\n\n"
			error_msg += "%s is experiencing technical difficulties (HTTP %s).\n" % [provider_name, response_code]
			error_msg += "This is temporary - please try again in a few moments."
		_:
			error_msg = "❌ Connection Error\n\n"
			error_msg += "%s returned an error (HTTP %s).\n" % [provider_name, response_code]
			error_msg += "Please check your internet connection and try again."

	# Try to extract additional error details from response and detect specific error types
	if not response_text.is_empty():
		var json := JSON.new()
		if json.parse(response_text) == OK:
			var error_data = json.data
			if error_data.has("error"):
				var error_detail = ""
				var error_type = ""
				var error_code = ""

				if typeof(error_data["error"]) == TYPE_DICTIONARY:
					if error_data["error"].has("message"):
						error_detail = error_data["error"]["message"]
					if error_data["error"].has("type"):
						error_type = error_data["error"]["type"]
					if error_data["error"].has("code"):
						error_code = error_data["error"]["code"]
				elif typeof(error_data["error"]) == TYPE_STRING:
					error_detail = error_data["error"]

				# Check for quota/billing errors
				if error_type == "insufficient_quota" or "quota" in error_detail.to_lower() or "billing" in error_detail.to_lower():
					error_msg = "💳 Quota Exceeded\n\n"
					error_msg += "Your %s account has exceeded its quota or has insufficient credits.\n\n" % provider_name
					error_msg += "To fix this:\n"
					error_msg += "1. Check your billing details at the provider's dashboard\n"
					error_msg += "2. Add credits or upgrade your plan\n"
					error_msg += "3. Verify your payment method is valid\n\n"
					error_msg += "Details: " + error_detail
					return error_msg

				# Add details to existing error message
				if not error_detail.is_empty():
					error_msg += "\n\nDetails: " + error_detail

	return error_msg

# Get user-friendly connection error message based on provider
func _get_connection_error_message(provider_name: String) -> String:
	var msg = "🔌 Connection Failed\n\n"

	match provider_name:
		"Ollama":
			msg += "Can't connect to Ollama. It looks like Ollama isn't running.\n\n"
			msg += "To fix this:\n"
			msg += "1. Start Ollama (run 'ollama serve' in terminal)\n"
			msg += "2. Or install Ollama from: https://ollama.ai\n"
			msg += "3. Make sure Ollama is running on http://127.0.0.1:11434"
		"Docker Model Runner":
			msg += "Can't connect to Docker Model Runner.\n\n"
			msg += "To fix this:\n"
			msg += "1. Make sure Docker Desktop is running\n"
			msg += "2. Enable Model Runner TCP access:\n"
			msg += "   docker desktop enable model-runner --tcp=12434\n"
			msg += "3. Verify models are available: docker model ls"
		"OpenAI":
			msg += "Can't connect to OpenAI's servers.\n\n"
			msg += "To fix this:\n"
			msg += "1. Check your internet connection\n"
			msg += "2. Verify OpenAI's service status at: status.openai.com\n"
			msg += "3. Check if your API key is valid"
		"Claude":
			msg += "Can't connect to Anthropic's Claude API.\n\n"
			msg += "To fix this:\n"
			msg += "1. Check your internet connection\n"
			msg += "2. Verify your API key is correct\n"
			msg += "3. Check Anthropic's status at: status.anthropic.com"
		"Google Gemini":
			msg += "Can't connect to Google's Gemini API.\n\n"
			msg += "To fix this:\n"
			msg += "1. Check your internet connection\n"
			msg += "2. Verify your API key from: aistudio.google.com\n"
			msg += "3. Ensure the API key has proper permissions"
		_:
			msg += "%s is not responding.\n\n" % provider_name
			msg += "Please check:\n"
			msg += "1. Your internet connection\n"
			msg += "2. The service is running\n"
			msg += "3. Your configuration is correct"

	return msg
