extends PanelContainer
## Modal overlay for copy-paste mode (SPEC-main-screen, "Copy-paste dialog"):
## two lines of help, the prompt, Copy prompt, the reply box, Paste, Cancel and
## Continue. Esc = Cancel. Every label follows the current language.
##
## Clipboard (bug B1): opening the window copies nothing; Copy prompt does,
## from the player's click as browsers require. Every paste into the reply box
## (Ctrl+V, Shift+Insert, right-click Paste, the Paste button) reads the system
## clipboard at that moment. On the web that read goes to the browser
## (navigator.clipboard.readText), because Godot's own copy of the clipboard is
## only refreshed after it is read, so it can still hold the copied prompt.

signal submitted(text: String)
signal cancelled

## Defines the browser read once, so the game only passes two callbacks in.
const JS_READ_CLIPBOARD := """
window.brasswakeReadClipboard = function (onText, onRefused) {
	if (!navigator.clipboard || !navigator.clipboard.readText) {
		onRefused('no clipboard API');
		return;
	}
	navigator.clipboard.readText().then(
		function (text) { onText(text); },
		function (error) { onRefused(String(error)); }
	);
};
"""

## How the window reaches the system clipboard. Tests swap these for a fake.
## write(text); read(done) then done.call(text, ok), ok false when the browser
## refused; cached() is the last text the game itself holds (on the web, what
## the browser's paste event or the last copy left there).
var clipboard_write: Callable
var clipboard_read: Callable
var clipboard_cached: Callable

var _prompt := ""
var _notice_key := ""
var _js_defined := false
## The browser callbacks of the reads in flight: they must stay alive until called.
var _js_callbacks: Array = []

@onready var title_label: Label = $VBox/Title
@onready var help_1: Label = $VBox/Help1
@onready var help_2: Label = $VBox/Help2
@onready var prompt_text: TextEdit = $VBox/PromptText
@onready var reply_text: TextEdit = $VBox/ReplyText
@onready var notice_label: Label = $VBox/Notice
@onready var copy_button: Button = $VBox/Buttons/CopyButton
@onready var paste_button: Button = $VBox/Buttons/PasteButton
@onready var submit_button: Button = $VBox/Buttons/SubmitButton
@onready var cancel_button: Button = $VBox/Buttons/CancelButton


func _init() -> void:
	clipboard_write = func(text: String) -> void: DisplayServer.clipboard_set(text)
	clipboard_read = _read_clipboard
	clipboard_cached = func() -> String: return DisplayServer.clipboard_get()


func _ready() -> void:
	visible = false
	submit_button.pressed.connect(_on_submit)
	cancel_button.pressed.connect(_on_cancel)
	copy_button.pressed.connect(_on_copy)
	paste_button.pressed.connect(paste)
	reply_text.paste_requested.connect(paste)
	Content.language_changed.connect(_on_language_changed)
	_localize()


func open(prompt: String) -> void:
	# Content files copied on Windows have CRLF line ends; the prompt box drops
	# the CRs, so copy the same LF text the player sees.
	_prompt = prompt.replace("\r\n", "\n")
	prompt_text.text = _prompt
	reply_text.text = ""
	_js_callbacks.clear()
	_show_notice("")
	visible = true
	reply_text.grab_focus()


func close() -> void:
	visible = false


## Esc = Cancel, like the settings dialog.
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel()


## Reads the clipboard now and puts its text at the reply box's caret.
func paste() -> void:
	clipboard_read.call(_on_clipboard_text)


func _on_copy() -> void:
	clipboard_write.call(_prompt)
	_show_notice("ui.prompt_copied")


func _on_clipboard_text(text: String, ok: bool) -> void:
	if not visible:
		return
	if not ok:
		# The browser said no. Its paste event may still have handed the game
		# the text, but the game's copy can also be the prompt it copied.
		text = str(clipboard_cached.call())
		if text.strip_edges().is_empty() or PromptBuilder.is_prompt_text(text):
			_show_notice("ui.paste_blocked")
			return
	if text.is_empty():
		return
	reply_text.insert_text_at_caret(text)
	reply_text.grab_focus()
	_show_notice("ui.reply_is_prompt" if PromptBuilder.is_prompt_text(reply_text.text) else "")


## Desktop: Godot reads the system clipboard at once. Web: ask the browser,
## which may ask the player once to allow it; the answer comes later.
func _read_clipboard(done: Callable) -> void:
	if not OS.has_feature("web"):
		done.call(DisplayServer.clipboard_get(), true)
		return
	if not _js_defined:
		JavaScriptBridge.eval(JS_READ_CLIPBOARD, true)
		_js_defined = true
	var on_text := JavaScriptBridge.create_callback(func(args: Array) -> void:
		done.call(str(args[0]) if args.size() > 0 else "", true))
	var on_refused := JavaScriptBridge.create_callback(func(args: Array) -> void:
		push_warning("Paste: the browser did not give the clipboard (%s)" % (str(args[0]) if args.size() > 0 else "?"))
		done.call("", false))
	_js_callbacks.append_array([on_text, on_refused])
	var window = JavaScriptBridge.get_interface("window")
	window.brasswakeReadClipboard(on_text, on_refused)


func _on_submit() -> void:
	var text := reply_text.text.strip_edges()
	close()
	submitted.emit(text)


func _on_cancel() -> void:
	close()
	cancelled.emit()


func _on_language_changed(_lang: String) -> void:
	_localize()


func _localize() -> void:
	title_label.text = Content.t("ui.paste_reply")
	help_1.text = Content.t("ui.paste_help_1")
	help_2.text = Content.t("ui.paste_help_2")
	copy_button.text = Content.t("ui.copy_prompt")
	paste_button.text = Content.t("ui.paste")
	submit_button.text = Content.t("ui.continue")
	cancel_button.text = Content.t("ui.cancel")
	_show_notice(_notice_key)


## A line for the player under the reply box (a string key, "" hides it).
func _show_notice(key: String) -> void:
	_notice_key = key
	notice_label.text = "" if key.is_empty() else Content.t(key)
	notice_label.visible = not key.is_empty()
