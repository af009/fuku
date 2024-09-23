@tool
extends Control

@onready var header_collapse_button: Button = $VBoxContainer/HeaderCollapse
@onready var header: PanelContainer = $VBoxContainer/Header
@onready var edit_model: OptionButton = $VBoxContainer/Header/HBoxContainer/HSplitContainer/EditModel
@onready var edit_content: LineEdit = $VBoxContainer/Header/HBoxContainer/HSplitContainer2/EditContent
@onready var user_prompt: LineEdit = $VBoxContainer/Footer/HBoxContainer/Prompt
@onready var model_answer: RichTextLabel = $VBoxContainer/Body/VBoxContainer/ModelAnswer
@onready var button: Button = $VBoxContainer/Footer/HBoxContainer/AskButton

var url: String = "http://localhost:11434/v1/chat/completions"
var headers = ["Content-Type: application/json"]
var model: String = ""
var instruction: String = """
You are an expert GDScript developer and Godot 4.3 specialist. Provide precise and concise responses that follow these guidelines:

1. Best Practices:
   - Use Godot's built-in features and patterns.
   - Follow the GDScript style guide (PascalCase for classes, snake_case for functions/variables).
   - Prefer typed variables and functions for clarity and performance.

2. Performance:
   - Recommend efficient algorithms and data structures.
   - Use signals over polling, and limit _physics_process to when it's necessary.
   - Suggest optimizations, especially for mobile platforms.

3. Code Formatting:
   - Format with tabs and limit line length to 100 characters.
   - Use descriptive variable and function names.

4. Godot 4.3 Features:
   - Suggest relevant nodes, scene structures, and new features in Godot 4.3.
   - Favor Godot's built-in methods over custom solutions.

5. Error Handling and Debugging:
   - Include error checking and recommend Godot-specific debugging methods.

6. Scalability and Maintainability:
   - Offer scalable solutions, encourage modular design, and separation of concerns.

7. Documentation:
   - Use brief comments for complex logic and recommend Godot's documentation tools (e.g., ##).

Relate responses to Godot's implementation and provide code examples ready for use in the script editor.
"""

var conversation = []
var request: HTTPRequest

func fetch_running_models() -> void:
	var list_models_url: String = "http://localhost:11434/api/tags"
	var error: Error = request.request(list_models_url, headers, HTTPClient.METHOD_GET)
	
	if error != OK:
		display_error_message("Unable to fetch running models.")

func _ready():
	if not is_node_ready():
		await ready

	edit_model.clear()
	edit_model.add_item("Fetching models...")
	edit_model.disabled = true
	edit_content.text = instruction
	edit_model.item_selected.connect(_on_model_selected)
	edit_content.text_changed.connect(_on_content_changed)
	
	request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_request_completed)
	button.pressed.connect(_on_button_pressed)
	user_prompt.text_submitted.connect(_on_enter_pressed)
	
	model_answer.bbcode_enabled = true
	model_answer.scroll_following = true
	model_answer.selection_enabled = true
	
	header_collapse_button.pressed.connect(_on_header_collapse_pressed)
	_update_header_state(true)  # Start with the header expanded
	
	fetch_running_models()

func _on_model_selected(index: int) -> void:
	model = edit_model.get_item_text(index)

func _on_content_changed(new_text: String):
	instruction = new_text

func _on_button_pressed():
	send_request()

func _on_enter_pressed(_text: String):
	send_request()

func _on_header_collapse_pressed() -> void:
	_update_header_state(!header.visible)

func _update_header_state(is_expanded: bool) -> void:
	header.visible = is_expanded
	header_collapse_button.text = "▼ Settings" if is_expanded else "▶ Settings"

func send_request():
	var prompt = user_prompt.text.strip_edges()
	if prompt.length() < 5:
		display_error_message("Your prompt is too short. Please provide more details for a better response.")
		return

	conversation.append({"role": "user", "content": prompt})
	display_user_message(prompt)
	
	var current_model = edit_model.get_item_text(edit_model.selected)
	var current_instruction = edit_content.text

	dialogue_request(prompt, current_instruction, current_model)
	user_prompt.text = ""

func dialogue_request(user_dialogue: String, content: String, model: String) -> void:
	var messages: Array[Dictionary] = [
		{"role": "system", "content": content},
		{"role": "user", "content": user_dialogue}
	]
	
	var body: String = JSON.stringify({"messages": messages, "model": model})
	var error: Error = request.request(url, headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		display_error_message("Unable to send request.")

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		display_error_message("Unable to connect to the Ollama server. Please ensure it's running and try again.")
		return

	var json := JSON.new()
	var error: Error = json.parse(body.get_string_from_utf8())
	
	if error != OK:
		display_error_message("We encountered an issue parsing the server response. Error code: %d. Please try again." % error)
		return
	
	var response: Variant = json.data
	if response is Dictionary:
		if response.has("models"):
			handle_model_list_response(response.get("models", []))
		elif response.has("choices"):
			handle_chat_completion_response(response)
		else:
			display_error_message("Unexpected response format. Response: %s" % JSON.stringify(response))
	else:
		display_error_message("Unexpected response type. Expected Dictionary, got: %s. Response: %s" % [typeof(response), JSON.stringify(response)])

func handle_model_list_response(models: Array) -> void:
	if models.is_empty():
		display_error_message("No models found. Please ensure at least one model is available.")
		return
	
	edit_model.clear()
	var model_names: Array = models.map(func(model): return model.get("name", ""))
	for model_name in model_names:
		edit_model.add_item(model_name)
	
	if not model_names.is_empty():
		edit_model.selected = 0
		model = model_names[0]  # Set the first model as default
	else:
		display_error_message("No valid model found.")
	
	edit_model.disabled = false

func handle_chat_completion_response(response: Dictionary) -> void:
	if response.has("choices") and response["choices"] is Array and not response["choices"].is_empty():
		var message: String = response["choices"][0]["message"]["content"]
		conversation.append({"role": edit_model.get_item_text(edit_model.selected), "content": message})
		display_model_message(message)

		# Force UI update
		await get_tree().process_frame
		ensure_scrolled_to_bottom()
	else:
		display_error_message("Unexpected chat completion response format. Response: %s" % JSON.stringify(response))

func display_user_message(message: String) -> void:
	append_message_to_display("User", message, "white")
	ensure_scrolled_to_bottom()

func display_model_message(message: String) -> void:
	var model_name = edit_model.get_item_text(edit_model.selected)
	append_message_to_display(model_name.capitalize(), message, "#b6f7eb")
	ensure_scrolled_to_bottom()

func append_message_to_display(role: String, content: String, color: String) -> void:
	if not is_instance_valid(model_answer):
		push_error("Model answer is missing.")
		return

	var formatted_content: String = format_code_blocks(content)
	model_answer.append_text("[color=%s][b][bgcolor=black]%s:[/bgcolor][/b][/color]\n[p]%s[/p]\n\n" % [color, role, formatted_content])

func ensure_scrolled_to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	model_answer.scroll_to_line(model_answer.get_line_count() - 1)

func display_error_message(error_message: String) -> void:
	push_error("Error: " + error_message)
	if is_instance_valid(model_answer):
		model_answer.append_text("[color=#FF7B7B]⚠️ %s[/color]\n\n" % error_message)
	ensure_scrolled_to_bottom()

func format_code_blocks(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("(?:```)(\\w*)\\n?([\\s\\S]*?)(?:\\n?```)")
	
	var formatted_text := text
	
	for match in regex.search_all(text):
		var code_block := match.get_string(2)
		var formatted_block := "\n[code][b][color=#b6f7eb]%s[/color][/b][/code]\n" % code_block
		formatted_text = formatted_text.replace(match.get_string(), formatted_block)
	
	return formatted_text

func reset_conversation() -> void:
	conversation.clear()
	if is_instance_valid(model_answer):
		model_answer.clear()
	else:
		push_error("Model answer is missing.")
