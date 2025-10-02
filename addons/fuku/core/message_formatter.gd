extends RefCounted
class_name MessageFormatter

# Format and display messages in RichTextLabel
static func append_message(rich_text_label: RichTextLabel, role: String, content: String, header_color: String = "#74c0fc") -> void:
	var formatted_content: String = MarkdownParser.format_text(content)

	# Add message separator
	rich_text_label.append_text("\n" + "─".repeat(50) + "\n\n")

	# Add message header
	rich_text_label.append_text("[b]%s[/b]\n\n" % role)

	# Add message content
	rich_text_label.append_text("%s\n\n" % formatted_content)

# Display error message
static func append_error(rich_text_label: RichTextLabel, error_message: String) -> void:
	var styled_error = """
[color=#6c7086]─────────────────────────────────[/color]
[color=#f38ba8][font_size=13][b]⚠️ Error[/b][/font_size][/color]

[color=#f9e2af]%s[/color]

""" % error_message

	rich_text_label.append_text(styled_error)

# Display success message
static func append_success(rich_text_label: RichTextLabel, success_message: String) -> void:
	var styled_success = """
[color=#6c7086]─────────────────────────────────[/color]
[color=#a6e3a1][font_size=14][b]✅ Success[/b][/font_size][/color]

[color=#cdd6f4]%s[/color]

""" % success_message

	rich_text_label.append_text(styled_success)

# Get model icon based on model name
static func get_model_icon(model_name: String) -> String:
	if "gpt" in model_name.to_lower():
		return "🤖"
	elif "claude" in model_name.to_lower():
		return "🧠"
	elif "gemma" in model_name.to_lower() or "llama" in model_name.to_lower():
		return "🦙"
	else:
		return "🤖"

# Display welcome message
static func show_welcome_message(rich_text_label: RichTextLabel) -> void:
	var welcome_msg = """[center][img=32]res://addons/fuku/fuku.png[/img] [color=#74c0fc][font_size=20][b]Fuku AI Assistant[/b][/font_size][/color]

[color=#a6adc8]Ready to help with your Godot 4.5 development![/color][/center]

[left][color=#6c7086][b]Getting Started:[/b][/color]

[color=#a6adc8]1. Choose your AI provider (Ollama, OpenAI, Claude, Docker, or Gemini)

2. Enter your API key if needed (Ollama and Docker don't require one)

3. Check the [b]"Save"[/b] checkbox to save your API key (optional)

4. Click [/color][color=#74c0fc]🔌 Connect[/color][color=#a6adc8] to fetch available models

5. Start chatting to get help with your Godot project![/color][/left]

[color=#45475a]""" + "═".repeat(60) + """[/color]

[color=#f38ba8][b]⚠️ Security Notice:[/b][/color]
[color=#f9e2af]Saved API keys are stored in base64 in .env. You are responsible for their security.
Fuku is not responsible for unauthorized access or misuse.[/color]"""

	rich_text_label.append_text(welcome_msg)
