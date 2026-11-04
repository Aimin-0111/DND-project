extends TextEdit
## The paste window's reply box. Every paste (Ctrl+V, Shift+Insert, the
## right-click menu) goes to the paste window, which reads the clipboard at
## that moment: on the web, Godot's own copy of the clipboard can still hold
## the prompt the game copied (bug B1).

signal paste_requested


func _paste(_caret_index: int) -> void:
	paste_requested.emit()
