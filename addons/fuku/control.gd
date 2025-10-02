@tool
extends Control

# Loading animation patterns
const LOADING_DOT_PATTERNS: Array[String] = ["●  ", "●● ", "●●●", " ●●", "  ●"]

# Core managers
var chat_manager: ChatManager
var backend_manager: BackendManager
var config_manager: ConfigManager

# loading
var is_loading: bool = false
var spinner_tween: Tween = null
var pattern_timer: Timer = null
var current_pattern_index: int = 0

# HTTP request node
var request: HTTPRequest

# UI reference (will be created from scene)
@onready var chat_ui: Control = self

# Current state
var current_backend_type: BackendManager.BackendType = BackendManager.BackendType.OLLAMA

func _ready() -> void:
	if not is_node_ready():
		await ready

	_initialize_managers()
	_setup_ui_connections()
	_load_configuration()

# Initialize core managers
func _initialize_managers() -> void:
	# Create HTTP request node
	request = HTTPRequest.new()
	add_child(request)

	# Initialize managers
	chat_manager = ChatManager.new()
	backend_manager = BackendManager.new(request)
	config_manager = ConfigManager.new()

	# Connect backend manager signals
	backend_manager.models_fetched.connect(_on_models_fetched)
	backend_manager.response_received.connect(_on_response_received)
	backend_manager.error_occurred.connect(_on_error_occurred)

	# Set default system instruction
	chat_manager.set_system_instruction(SettingsPanel.DEFAULT_SYSTEM_INSTRUCTION)

# Setup UI signal connections
func _setup_ui_connections() -> void:
	# Get UI components
	var chat_display = $VBoxContainer/Body/VBoxContainer/ModelAnswer
	var user_prompt = $VBoxContainer/Footer/HBoxContainer/Prompt
	var send_button = $VBoxContainer/Footer/HBoxContainer/AskButton
	var clear_chat_button = $VBoxContainer/Footer/HBoxContainer/ClearChatButton
	var header_collapse_button = $VBoxContainer/HeaderCollapse
	var loading_container = $VBoxContainer/Body/VBoxContainer/ChatHeader/LoadingContainer

	# Setup chat display
	if chat_display:
		chat_display.bbcode_enabled = true
		chat_display.scroll_following = true
		chat_display.selection_enabled = true
		chat_display.add_theme_color_override("default_color", SettingsPanel.COLOR_DEFAULT_TEXT)
		chat_display.add_theme_color_override("selection_color", SettingsPanel.COLOR_SELECTION)
		MessageFormatter.show_welcome_message(chat_display)

	# Connect settings panel UI elements directly
	var provider_option = $VBoxContainer/Header/HBoxContainer/ProviderOption
	var api_key_input = $VBoxContainer/Header/HBoxContainer/APIKeyContainer/APIKeyInput
	var save_key_checkbox = $VBoxContainer/Header/HBoxContainer/APIKeyContainer/SaveKeyCheckbox
	var model_option = $VBoxContainer/Header/HBoxContainer/EditModel
	var instruction_input = $VBoxContainer/Header/HBoxContainer/EditContent
	var connect_button = $VBoxContainer/Body/VBoxContainer/ChatHeader/ConnectButton
	var retry_button = $VBoxContainer/Body/VBoxContainer/ChatHeader/RetryButton
	var load_env_button = $VBoxContainer/Header/HBoxContainer/ButtonContainer/LoadEnvButton

	# Initialize model dropdown
	if model_option:
		model_option.clear()
		model_option.add_item("Click Connect to fetch models")
		model_option.disabled = true

	# Show connect button initially, hide others
	if connect_button:
		connect_button.show()
	if retry_button:
		retry_button.hide()
	if load_env_button:
		load_env_button.hide()

	# Set button icons from editor theme
	if send_button and Engine.is_editor_hint():
		var editor_theme = EditorInterface.get_editor_theme()
		if editor_theme:
			send_button.icon = editor_theme.get_icon("Play", "EditorIcons")
	if clear_chat_button and Engine.is_editor_hint():
		var editor_theme = EditorInterface.get_editor_theme()
		if editor_theme:
			clear_chat_button.icon = editor_theme.get_icon("Remove", "EditorIcons")

	if provider_option:
		provider_option.item_selected.connect(_on_provider_changed)
	if api_key_input:
		api_key_input.text_changed.connect(_on_api_key_changed)
	if model_option:
		model_option.item_selected.connect(_on_model_selected)
	if instruction_input:
		# TextEdit uses text_changed signal (same as LineEdit)
		instruction_input.text_changed.connect(_on_system_instruction_changed)
	if connect_button:
		connect_button.pressed.connect(_on_connect_requested)
	if retry_button:
		retry_button.pressed.connect(_on_retry_requested)
	if load_env_button:
		load_env_button.pressed.connect(_on_reload_env_requested)

	# Connect user input signals
	if user_prompt:
		user_prompt.text_submitted.connect(_on_text_submitted)
	if send_button:
		send_button.pressed.connect(_on_send_pressed)
	if clear_chat_button:
		clear_chat_button.pressed.connect(_on_clear_chat_pressed)
	if header_collapse_button:
		header_collapse_button.pressed.connect(_on_header_collapse_pressed)

	# Hide loading initially
	if loading_container:
		loading_container.visible = false

	# Setup header state
	_update_header_state(true)

# Load configuration and initial state
func _load_configuration() -> void:
	config_manager.load_api_keys()

	# Set backend to Ollama by default
	_switch_backend(BackendManager.BackendType.OLLAMA)

	# Load API key for current backend
	_update_backend_api_key()


# Switch to different backend
func _switch_backend(backend_type: BackendManager.BackendType) -> void:
	current_backend_type = backend_type
	backend_manager.set_backend(backend_type)
	config_manager.set_current_backend(_get_backend_name(backend_type))

	# Update API key for new backend
	_update_backend_api_key()

# Update backend with API key from config
func _update_backend_api_key() -> void:
	var backend_name = _get_backend_name(current_backend_type)
	var api_key = config_manager.get_api_key(backend_name)
	backend_manager.update_api_key(api_key)

	# Update UI
	var api_key_input = $VBoxContainer/Header/HBoxContainer/APIKeyContainer/APIKeyInput
	var save_key_checkbox = $VBoxContainer/Header/HBoxContainer/APIKeyContainer/SaveKeyCheckbox

	if api_key_input:
		if api_key.is_empty():
			api_key_input.text = ""
			var placeholder = ""
			if backend_name == "ollama" or backend_name == "docker":
				placeholder = SettingsPanel.PLACEHOLDER_NO_KEY_NEEDED
			else:
				placeholder = SettingsPanel.PLACEHOLDER_ENTER_KEY_TEMPLATE % backend_name.capitalize()
			api_key_input.placeholder_text = placeholder
			# Uncheck save checkbox when no key is loaded
			if save_key_checkbox:
				save_key_checkbox.button_pressed = false
		else:
			api_key_input.text = SettingsPanel.MASKED_API_KEY_DISPLAY
			# Check save checkbox since we loaded a saved key
			if save_key_checkbox:
				save_key_checkbox.button_pressed = true

# Get backend name from type
func _get_backend_name(backend_type: BackendManager.BackendType) -> String:
	match backend_type:
		BackendManager.BackendType.OLLAMA:
			return "ollama"
		BackendManager.BackendType.OPENAI:
			return "openai"
		BackendManager.BackendType.CLAUDE:
			return "claude"
		BackendManager.BackendType.DOCKER:
			return "docker"
		BackendManager.BackendType.GEMINI:
			return "gemini"
	return "ollama"

# Signal handlers
func _on_provider_changed(index: int) -> void:
	_switch_backend(index as BackendManager.BackendType)
	backend_manager.fetch_models()

func _on_api_key_changed(new_text: String) -> void:
	if new_text == SettingsPanel.MASKED_API_KEY_DISPLAY:
		return # Don't update if it's the masked display

	var backend_name = _get_backend_name(current_backend_type)
	var save_key_checkbox = $VBoxContainer/Header/HBoxContainer/APIKeyContainer/SaveKeyCheckbox

	# Only save to .env if checkbox is checked
	if save_key_checkbox and save_key_checkbox.button_pressed:
		var success = config_manager.save_api_key(backend_name, new_text)
		if success:
			_show_api_key_saved_message()

	# Always update the backend with the key (for current session)
	backend_manager.update_api_key(new_text)

func _on_model_selected(index: int) -> void:
	var model_option = $VBoxContainer/Header/HBoxContainer/EditModel
	if model_option:
		var model_name = model_option.get_item_text(index)
		backend_manager.set_model(model_name)

func _on_system_instruction_changed() -> void:
	var instruction_input = $VBoxContainer/Header/HBoxContainer/EditContent
	if instruction_input:
		chat_manager.set_system_instruction(instruction_input.text)

func _on_connect_requested() -> void:
	backend_manager.fetch_models()
	_hide_connect_button()

func _on_retry_requested() -> void:
	backend_manager.fetch_models()

func _on_reload_env_requested() -> void:
	config_manager.load_api_keys()
	_update_backend_api_key()

	var chat_display = $VBoxContainer/Body/VBoxContainer/ModelAnswer
	if chat_display:
		MessageFormatter.append_success(chat_display, "Reloaded API keys from .env file")

func _on_text_submitted(_text: String) -> void:
	_send_message()

func _on_send_pressed() -> void:
	_send_message()

func _on_clear_chat_pressed() -> void:
	# Clear conversation history
	chat_manager.clear_conversation()

	# Clear chat display (don't re-show welcome message)
	var chat_display = $VBoxContainer/Body/VBoxContainer/ModelAnswer
	if chat_display:
		chat_display.clear()

func _on_header_collapse_pressed() -> void:
	var settings_panel = $VBoxContainer/Header
	_update_header_state(!settings_panel.visible)

func _update_header_state(is_expanded: bool) -> void:
	var settings_panel = $VBoxContainer/Header
	var header_collapse_button = $VBoxContainer/HeaderCollapse

	settings_panel.visible = is_expanded
	header_collapse_button.text = "▼ Settings" if is_expanded else "▶ Settings"

# Send message to AI
func _send_message() -> void:
	var user_prompt = $VBoxContainer/Footer/HBoxContainer/Prompt
	var model_option = $VBoxContainer/Header/HBoxContainer/EditModel

	var prompt = user_prompt.text.strip_edges()
	if prompt.length() < 5:
		_display_error("Prompt too short.")
		return

	if model_option and model_option.disabled:
		_display_error("No models available for selected provider.")
		_show_retry_button()
		return

	# Clear welcome message on first interaction
	var chat_display = $VBoxContainer/Body/VBoxContainer/ModelAnswer
	if chat_display and chat_manager.get_conversation().is_empty():
		chat_display.clear()

	# Add user message to conversation
	chat_manager.add_message("user", prompt)
	_display_user_message(prompt)

	# Clear input
	user_prompt.text = ""

	# Show loading
	_show_loading("Thinking...")

	# Send request
	var model = backend_manager.get_model()
	var system_instruction = chat_manager.get_system_instruction()
	var conversation = chat_manager.get_conversation()

	backend_manager.send_chat_request(conversation, model, system_instruction)

# Backend response handlers
func _on_models_fetched(models: Array) -> void:
	var model_option = $VBoxContainer/Header/HBoxContainer/EditModel
	if model_option:
		model_option.clear()

		if models.is_empty():
			model_option.add_item("No models available")
			model_option.disabled = true
			_show_retry_button()
			return

		for model_name in models:
			model_option.add_item(model_name)

		model_option.selected = 0
		model_option.disabled = false
		_hide_retry_button()
		_hide_connect_button()

	# Set first model as default
	if not models.is_empty():
		backend_manager.set_model(models[0])

func _on_response_received(message: String) -> void:
	_hide_loading()

	# Add to conversation
	chat_manager.add_message("assistant", message)

	# Display message
	var model = backend_manager.get_model()
	_display_model_message(message, model)

func _on_error_occurred(error_message: String) -> void:
	_hide_loading()
	_display_error(error_message)
	_show_retry_button()

# UI display methods
func _display_user_message(message: String) -> void:
	var chat_display = $VBoxContainer/Body/VBoxContainer/ModelAnswer
	if chat_display:
		MessageFormatter.append_message(chat_display, "👤 You", message, "#74c0fc")

func _display_model_message(message: String, model_name: String) -> void:
	var chat_display = $VBoxContainer/Body/VBoxContainer/ModelAnswer
	if chat_display:
		var icon = MessageFormatter.get_model_icon(model_name)
		var cleaned_message = MarkdownParser.remove_thinking_tags(message)
		MessageFormatter.append_message(chat_display, icon + " " + model_name, cleaned_message, "#a6e3a1")

func _display_error(error_message: String) -> void:
	var chat_display = $VBoxContainer/Body/VBoxContainer/ModelAnswer
	if chat_display:
		# Clear welcome message before showing error
		if chat_manager.get_conversation().is_empty():
			chat_display.clear()

		MessageFormatter.append_error(chat_display, error_message)

func _show_loading(text: String = "Processing...") -> void:
	var loading_container = $VBoxContainer/Body/VBoxContainer/ChatHeader/LoadingContainer
	var loading_text = $VBoxContainer/Body/VBoxContainer/ChatHeader/LoadingContainer/LoadingText
	var send_button = $VBoxContainer/Footer/HBoxContainer/AskButton

	if loading_container:
		loading_container.visible = true
	if loading_text:
		loading_text.text = text
	if send_button:
		send_button.disabled = true

	_start_spinner_animation()

func _hide_loading() -> void:
	is_loading = false
	var loading_container = $VBoxContainer/Body/VBoxContainer/ChatHeader/LoadingContainer
	var send_button = $VBoxContainer/Footer/HBoxContainer/AskButton
	var loading_spinner = $VBoxContainer/Body/VBoxContainer/ChatHeader/LoadingContainer/LoadingSpinner

	if loading_container:
		loading_container.visible = false
	if send_button:
		send_button.disabled = false

	# Stop pattern timer
	if pattern_timer:
		pattern_timer.stop()

	# Clean up tween
	if spinner_tween and spinner_tween.is_valid():
		spinner_tween.kill()
		spinner_tween = null

	# Reset spinner appearance
	if loading_spinner:
		loading_spinner.modulate.a = 1.0

func _start_spinner_animation() -> void:
	is_loading = true
	var loading_spinner = $VBoxContainer/Body/VBoxContainer/ChatHeader/LoadingContainer/LoadingSpinner

	if not loading_spinner:
		return

	# Kill existing tween if any
	if spinner_tween and spinner_tween.is_valid():
		spinner_tween.kill()

	# Create smooth pulsing animation using Tween
	spinner_tween = create_tween().set_loops()
	spinner_tween.tween_property(loading_spinner, "modulate:a", 0.3, 0.6).from(1.0)
	spinner_tween.tween_property(loading_spinner, "modulate:a", 1.0, 0.6).from(0.3)

	# Create timer for dot pattern rotation (more efficient than while loop)
	if not pattern_timer:
		pattern_timer = Timer.new()
		pattern_timer.wait_time = 0.3
		pattern_timer.timeout.connect(_on_pattern_timer_timeout)
		add_child(pattern_timer)

	current_pattern_index = 0
	pattern_timer.start()

func _on_pattern_timer_timeout() -> void:
	var loading_spinner = $VBoxContainer/Body/VBoxContainer/ChatHeader/LoadingContainer/LoadingSpinner
	if not loading_spinner or not is_loading:
		return

	loading_spinner.text = LOADING_DOT_PATTERNS[current_pattern_index]
	current_pattern_index = (current_pattern_index + 1) % LOADING_DOT_PATTERNS.size()

func _show_connect_button() -> void:
	var connect_button = $VBoxContainer/Body/VBoxContainer/ChatHeader/ConnectButton
	var retry_button = $VBoxContainer/Body/VBoxContainer/ChatHeader/RetryButton
	if connect_button:
		connect_button.show()
	if retry_button:
		retry_button.hide()

func _hide_connect_button() -> void:
	var connect_button = $VBoxContainer/Body/VBoxContainer/ChatHeader/ConnectButton
	if connect_button:
		connect_button.hide()

func _show_retry_button() -> void:
	var connect_button = $VBoxContainer/Body/VBoxContainer/ChatHeader/ConnectButton
	var retry_button = $VBoxContainer/Body/VBoxContainer/ChatHeader/RetryButton
	if connect_button:
		connect_button.hide()
	if retry_button:
		retry_button.show()

func _hide_retry_button() -> void:
	var retry_button = $VBoxContainer/Body/VBoxContainer/ChatHeader/RetryButton
	if retry_button:
		retry_button.hide()

func _show_api_key_saved_message() -> void:
	var chat_display = $VBoxContainer/Body/VBoxContainer/ModelAnswer
	if chat_display:
		MessageFormatter.append_success(chat_display, "✓ API key saved to .env (base64 encoded)")
