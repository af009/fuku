@tool
extends Control

@onready var edit_model = $Header/HBoxContainer/HSplitContainer/EditModel
@onready var edit_content = $Header/HBoxContainer/HSplitContainer2/EditContent
@onready var user_prompt: LineEdit = $Footer/HBoxContainer/Prompt
@onready var model_answer: RichTextLabel = $Body/VBoxContainer/ModelAnswer
@onready var button: Button = $Footer/HBoxContainer/AskButton

var url: String = "http://localhost:11434/v1/chat/completions"
var headers = ["Content-Type: application/json"]
# default model
var model: String = "deepseek-coder:33b"
# default content "instruction"
var instruction: String = "You are a expert Godot developer who prioritizes writing clean, straightforward code that is easy to understand and maintain. When providing explanations, keep them concise and focus on the essential points without unnecessary verbosity. Your goal is to convey complex concepts in a simple and digestible manner for Godot developers of all skill levels."
var messages = []
var request: HTTPRequest

func _ready():
	edit_model.text = model
	edit_content.text = instruction
	edit_model.text_changed.connect(_on_model_changed)
	edit_content.text_changed.connect(_on_content_changed)
	request = HTTPRequest.new()
	add_child(request)
	request.connect("request_completed", _on_request_completed)
	button.connect("pressed", self._on_button_pressed)

func _on_model_changed(new_text: String):
	model = new_text
	#print("Model updated to: ", model)

func _on_content_changed(new_text: String):
	instruction = new_text
	#print("Model updated to: ", instruction)

func _on_button_pressed():
	var text_length: int = user_prompt.text.length()
	if text_length < 5:
		return

	var prompt = user_prompt.text
	var current_model = edit_model.text
	var current_instruction = edit_content.text
	
	dialogue_request(prompt, current_instruction , current_model )
	user_prompt.text = ""
	model_answer.text = ""

func dialogue_request(user_dialogue, content, model):
	messages.append({
		"role": "system",
		"content": content
	})
	messages.append({
		"role": "user",
		"content": user_dialogue
	})

	var body = JSON.new().stringify({
		"messages": messages,
		"model": model
	})

	var error = request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("An error occurred while sending the request: %s" % error)

func _on_request_completed(result, response_code, headers, body):
	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())
	if error != OK:
		push_error("An error occurred while parsing the response: %s" % error)
		model_answer.bbcode_text = "An error occurred while parsing the response."
		return

	var response = json.get_data()
	if response.has("error"):
		push_error("API error: %s" % response["error"]["message"])
		model_answer.bbcode_text = "An error occurred: %s" % response["error"]["message"]
		return

	if !response.has("choices") or response["choices"].size() == 0:
		push_error("Invalid response format")
		model_answer.bbcode_text = "An error occurred: Invalid response format."
		return

	var message = response["choices"][0]["message"]["content"]
	model_answer.bbcode_text = "[i]" + message + "[/i]"

	
	


