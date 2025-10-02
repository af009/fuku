extends RefCounted
class_name FukuCodeHighlighter

# Cached RegEx patterns for GDScript
static var _gdscript_string_regex: RegEx = null
static var _gdscript_keyword_regex: RegEx = null
static var _gdscript_type_regex: RegEx = null

# Cached RegEx patterns for C#
static var _csharp_string_regex: RegEx = null
static var _csharp_keyword_regex: RegEx = null
static var _csharp_type_regex: RegEx = null

# Get or create cached GDScript string regex
static func _get_gdscript_string_regex() -> RegEx:
	if _gdscript_string_regex == null:
		_gdscript_string_regex = RegEx.new()
		_gdscript_string_regex.compile("\"([^\"]*)\"")
	return _gdscript_string_regex

# Get or create cached GDScript keyword regex
static func _get_gdscript_keyword_regex() -> RegEx:
	if _gdscript_keyword_regex == null:
		_gdscript_keyword_regex = RegEx.new()
		_gdscript_keyword_regex.compile("\\b(func|var|const|class|extends|if|else|elif|for|while|return|await|signal|enum)\\b")
	return _gdscript_keyword_regex

# Get or create cached GDScript type regex
static func _get_gdscript_type_regex() -> RegEx:
	if _gdscript_type_regex == null:
		_gdscript_type_regex = RegEx.new()
		_gdscript_type_regex.compile("\\b(int|float|String|bool|Array|Dictionary|Vector2|Vector3|Node|Control|Node2D)\\b")
	return _gdscript_type_regex

# Get or create cached C# string regex
static func _get_csharp_string_regex() -> RegEx:
	if _csharp_string_regex == null:
		_csharp_string_regex = RegEx.new()
		_csharp_string_regex.compile("\"([^\"]*)\"")
	return _csharp_string_regex

# Get or create cached C# keyword regex
static func _get_csharp_keyword_regex() -> RegEx:
	if _csharp_keyword_regex == null:
		_csharp_keyword_regex = RegEx.new()
		_csharp_keyword_regex.compile("\\b(public|private|protected|static|void|class|using|namespace|if|else|for|while|return|new|override)\\b")
	return _csharp_keyword_regex

# Get or create cached C# type regex
static func _get_csharp_type_regex() -> RegEx:
	if _csharp_type_regex == null:
		_csharp_type_regex = RegEx.new()
		_csharp_type_regex.compile("\\b(int|float|string|bool|Vector2|Vector3|Node|Control|Godot)\\b")
	return _csharp_type_regex

# Highlight GDScript code
static func highlight_gdscript(code: String) -> String:
	var lines = code.split("\n")

	for i in range(lines.size()):
		var line = lines[i]
		var original_line = line

		if line.strip_edges().is_empty():
			continue

		# Comments first (entire line - highest priority)
		if line.strip_edges().begins_with("#"):
			lines[i] = "[color=#6c7086]%s[/color]" % original_line
			continue

		# Process strings first to protect them from keyword highlighting
		line = _get_gdscript_string_regex().sub(line, "[color=#a6e3a1]\"$1\"[/color]", true)

		# Keywords
		line = _get_gdscript_keyword_regex().sub(line, "[color=#cba6f7]$1[/color]", true)

		# Types
		line = _get_gdscript_type_regex().sub(line, "[color=#fab387]$1[/color]", true)

		lines[i] = line

	return "\n".join(lines)

# Highlight C# code
static func highlight_csharp(code: String) -> String:
	var lines = code.split("\n")

	for i in range(lines.size()):
		var line = lines[i]
		var original_line = line

		if line.strip_edges().is_empty():
			continue

		# Comments first
		if line.strip_edges().begins_with("//"):
			lines[i] = "[color=#6c7086]%s[/color]" % original_line
			continue

		# Process strings first
		line = _get_csharp_string_regex().sub(line, "[color=#a6e3a1]\"$1\"[/color]", true)

		# Keywords
		line = _get_csharp_keyword_regex().sub(line, "[color=#cba6f7]$1[/color]", true)

		# Types
		line = _get_csharp_type_regex().sub(line, "[color=#fab387]$1[/color]", true)

		lines[i] = line

	return "\n".join(lines)

# Highlight code based on language
static func highlight_code(code: String, language: String) -> String:
	if code.strip_edges().is_empty():
		return code

	match language.to_lower():
		"gdscript", "gd":
			return highlight_gdscript(code)
		"csharp", "cs", "c#":
			return highlight_csharp(code)
		_:
			return code
