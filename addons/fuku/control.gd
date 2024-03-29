@tool
extends Control

@onready var edit_model = $Header/HBoxContainer/HSplitContainer/EditModel
@onready var edit_content = $Header/HBoxContainer/HSplitContainer2/EditContent
@onready var user_prompt: LineEdit = $Footer/HBoxContainer/Prompt
@onready var model_answer: RichTextLabel = $Body/VBoxContainer/ModelAnswer
@onready var button: Button = $Footer/HBoxContainer/AskButton

var url: String = "http://localhost:11434/v1/chat/completions"
var headers = ["Content-Type: application/json"]
var model: String = "llama2"
var instruction: String = "You are a knowledgeable and concise Godot expert, providing focused guidance on using the game engine effectively."
var conversation = []
var request: HTTPRequest
var messages = []

func _ready():
	edit_model.text = model
	edit_content.text = instruction
	edit_model.text_changed.connect(_on_model_changed)
	edit_content.text_changed.connect(_on_content_changed)
	
	request = HTTPRequest.new()
	add_child(request)
	request.connect("request_completed", _on_request_completed)
	button.connect("pressed", self._on_button_pressed)
	model_answer.bbcode_enabled = true

func _on_model_changed(new_text: String):
	model = new_text

func _on_content_changed(new_text: String):
	instruction = new_text

func _on_button_pressed():
	var text_length: int = user_prompt.text.length()
	if text_length < 5:
		return

	var prompt = user_prompt.text
	var current_model = edit_model.text
	var current_instruction = edit_content.text

	# Add user prompt to conversation history
	conversation.append({"role": "user", "content": prompt})

	dialogue_request(prompt, current_instruction, current_model)
	user_prompt.text = ""


func dialogue_request(user_dialogue, content, model):
	messages = []
	messages.append({"role": "system", "content": content})
	messages.append({"role": "user", "content": user_dialogue})

	var body = JSON.new().stringify({"messages": messages, "model": model})
	var error = request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		display_error_message("An error occurred while sending the request: %s" % error)

func _on_request_completed(result, response_code, headers, body):
	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())
	if error != OK:
		display_error_message("An error occurred while parsing the response. \n*Make sure the model [b]'%s' is running[/b] in the background." % model)
		return

	var response = json.get_data()

	if response.has("error"):
		display_error_message("API error: %s" % response["error"]["message"])
		return

	if !response.has("choices") or response["choices"].size() == 0:
		display_error_message("Invalid response format")
		return

	var message = response["choices"][0]["message"]["content"]

	# Add model answer to conversation history
	conversation.append({"role": edit_model.text, "content": message})

	# Display the entire conversation history
	model_answer.clear() # Clear the RichTextLabel initially
	for msg in conversation:
		var role_text = msg["role"].capitalize()
		var content_text = format_code_blocks(msg["content"])

		if msg["role"] == "user":
			model_answer.append_text("[color=WHITE][b][bgcolor=BLACK]%s: [/bgcolor][/b][/color]\n [p]%s[/p]\n\n" % [role_text, content_text])
		else:
			model_answer.append_text("[color=#b6f7eb][b][bgcolor=BLACK]%s: [/bgcolor][/b][/color]\n [p]%s[/p]\n\n" % [role_text, content_text])

func display_error_message(error_message: String):
	push_error(error_message)
	model_answer.bbcode_text = "[color=#FF7B7B]Error: %s[/color]" % error_message
	
func format_code_blocks(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("(?:```)(\\w*)\\n?([\\s\\S]*?)(?:\\n?```)")
	
	var formatted_text = text
	
	for match in regex.search_all(text):
		var language_code = match.get_string(1)
		var code_block = match.get_string(2)
		var formatted_block = "\n[color=#B2E7CE][bgcolor=BLACK][b]%s[/b][/bgcolor][/color]\n" % code_block
		formatted_text = formatted_text.replace(match.get_string(), formatted_block)
	
	return formatted_text

