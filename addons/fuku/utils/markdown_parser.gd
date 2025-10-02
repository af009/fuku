extends RefCounted
class_name MarkdownParser

const FukuCodeHighlighter = preload("res://addons/fuku/utils/syntax_highlighter.gd")

# Cached RegEx patterns
static var _code_block_regex: RegEx = null
static var _inline_code_regex: RegEx = null
static var _bold_regex: RegEx = null
static var _thinking_regex: RegEx = null
static var _think_regex: RegEx = null
static var _whitespace_regex: RegEx = null

# Get or create cached code block regex
static func _get_code_block_regex() -> RegEx:
	if _code_block_regex == null:
		_code_block_regex = RegEx.new()
		_code_block_regex.compile("```([^\\n]*)\\n?([\\s\\S]*?)```")
	return _code_block_regex

# Get or create cached inline code regex
static func _get_inline_code_regex() -> RegEx:
	if _inline_code_regex == null:
		_inline_code_regex = RegEx.new()
		_inline_code_regex.compile("`([^`]+)`")
	return _inline_code_regex

# Get or create cached bold regex
static func _get_bold_regex() -> RegEx:
	if _bold_regex == null:
		_bold_regex = RegEx.new()
		_bold_regex.compile("\\*\\*([^*\\n]+)\\*\\*")
	return _bold_regex

# Get or create cached thinking regex
static func _get_thinking_regex() -> RegEx:
	if _thinking_regex == null:
		_thinking_regex = RegEx.new()
		_thinking_regex.compile("<thinking>[\\s\\S]*?</thinking>")
	return _thinking_regex

# Get or create cached think regex
static func _get_think_regex() -> RegEx:
	if _think_regex == null:
		_think_regex = RegEx.new()
		_think_regex.compile("<think>[\\s\\S]*?</think>")
	return _think_regex

# Get or create cached whitespace regex
static func _get_whitespace_regex() -> RegEx:
	if _whitespace_regex == null:
		_whitespace_regex = RegEx.new()
		_whitespace_regex.compile("\\n\\n\\n+")
	return _whitespace_regex

# Format text with markdown and code blocks
static func format_text(text: String) -> String:
	var formatted_text := text

	# Step 1: Handle code blocks (```)
	formatted_text = _format_code_blocks(formatted_text)

	# Step 2: Handle inline code (`)
	formatted_text = _format_inline_code(formatted_text)

	# Step 3: Handle markdown formatting
	formatted_text = _format_markdown(formatted_text)

	return formatted_text

# Format code blocks (```)
static func _format_code_blocks(text: String) -> String:
	var formatted_text := text
	var code_matches = _get_code_block_regex().search_all(formatted_text)

	# Process in reverse order to maintain positions
	for i in range(code_matches.size() - 1, -1, -1):
		var match = code_matches[i]
		var language = match.get_string(1).strip_edges()
		var code_content = match.get_string(2).strip_edges()

		var highlighted_code = FukuCodeHighlighter.highlight_code(code_content, language)

		var formatted_block = """

[color=#6c7086]┌─ %s ─[/color]
[font_size=14][code]%s[/code][/font_size]
[color=#6c7086]└─────[/color]
""" % [language if not language.is_empty() else "code", highlighted_code]

		var start_pos = match.get_start()
		var end_pos = match.get_end()
		formatted_text = formatted_text.substr(0, start_pos) + formatted_block + formatted_text.substr(end_pos)

	return formatted_text

# Format inline code (`)
static func _format_inline_code(text: String) -> String:
	var formatted_text := text
	var inline_matches = _get_inline_code_regex().search_all(formatted_text)

	# Process in reverse order
	for i in range(inline_matches.size() - 1, -1, -1):
		var match = inline_matches[i]
		var inline_content = match.get_string(1)
		var formatted_inline = "[font_size=14][code]%s[/code][/font_size]" % inline_content

		var start_pos = match.get_start()
		var end_pos = match.get_end()
		formatted_text = formatted_text.substr(0, start_pos) + formatted_inline + formatted_text.substr(end_pos)

	return formatted_text

# Format markdown (bold, etc.)
static func _format_markdown(text: String) -> String:
	var formatted := text

	# Handle bold text
	var matches = _get_bold_regex().search_all(formatted)
	for i in range(matches.size() - 1, -1, -1):
		var match = matches[i]
		var bold_text = match.get_string(1)
		var replacement = "[b]%s[/b]" % bold_text

		var start_pos = match.get_start()
		var end_pos = match.get_end()
		formatted = formatted.substr(0, start_pos) + replacement + formatted.substr(end_pos)

	return formatted

# Remove thinking tags from text
static func remove_thinking_tags(text: String) -> String:
	var cleaned = text

	# Remove <thinking>...</thinking> tags
	cleaned = _get_thinking_regex().sub(cleaned, "", true)

	# Remove <think>...</think> tags
	cleaned = _get_think_regex().sub(cleaned, "", true)

	# Clean up extra whitespace
	cleaned = _get_whitespace_regex().sub(cleaned, "\n\n", true)

	return cleaned.strip_edges()
