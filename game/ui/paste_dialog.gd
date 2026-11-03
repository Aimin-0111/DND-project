extends PanelContainer
## Modal overlay for copy-paste mode. It shows the prompt as a fallback and
## collects the AI reply.

signal submitted(text: String)
signal cancelled

@onready var title_label: Label = $VBox/Title
@onready var prompt_text: TextEdit = $VBox/PromptText
@onready var reply_text: TextEdit = $VBox/ReplyText
@onready var submit_button: Button = $VBox/Buttons/SubmitButton
@onready var cancel_button: Button = $VBox/Buttons/CancelButton


func _ready() -> void:
	visible = false
	title_label.text = Content.t("ui.paste_reply")
	submit_button.text = Content.t("ui.continue")
	cancel_button.text = Content.t("ui.cancel")
	submit_button.pressed.connect(_on_submit)
	cancel_button.pressed.connect(_on_cancel)


func open(prompt: String) -> void:
	prompt_text.text = prompt
	reply_text.text = ""
	visible = true
	reply_text.grab_focus()


func close() -> void:
	visible = false


func _on_submit() -> void:
	var text := reply_text.text.strip_edges()
	close()
	submitted.emit(text)


func _on_cancel() -> void:
	close()
	cancelled.emit()
