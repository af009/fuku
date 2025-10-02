extends RefCounted
class_name ChatManager

var conversation: Array = []
var system_instruction: String = ""

# Add message to conversation
func add_message(role: String, content: String) -> void:
	conversation.append({"role": role, "content": content})

# Get conversation history
func get_conversation() -> Array:
	return conversation

# Clear conversation history
func clear_conversation() -> void:
	conversation.clear()

# Set system instruction
func set_system_instruction(instruction: String) -> void:
	system_instruction = instruction

# Get system instruction
func get_system_instruction() -> String:
	return system_instruction

# Get last message
func get_last_message() -> Dictionary:
	if conversation.is_empty():
		return {}
	return conversation[-1]

# Get conversation size
func get_conversation_size() -> int:
	return conversation.size()
