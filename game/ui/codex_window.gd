class_name CodexWindow
extends GameWindow
## The Codex window (SPEC-main-screen, "Menu"): Menu → Codex opens it; Esc or
## its close button closes it. A read-only, scrolling text with the place, NPC
## and lore pages of the current language, the same pages the AI gets as its
## Codex (Content.codex_text()). The writer's Markdown shows lightly
## formatted: headings and **bold** in bold, "- " lines as bullets.

const HEADING_COLOUR := "#e0b36a"

var text_label: RichTextLabel


func _ready() -> void:
	super()
	text_label = RichTextLabel.new()
	text_label.name = "Text"
	text_label.bbcode_enabled = true
	text_label.scroll_active = true
	text_label.selection_enabled = true
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(text_label)


func _refresh() -> void:
	text_label.text = to_bbcode(Content.codex_text())
	text_label.scroll_to_line(0)


## The writer's Markdown as safe BBCode, with CRLF or LF line ends: square
## brackets stay text; "#" headings and **bold** turn bold; "- " lines become
## bullets.
static func to_bbcode(markdown: String) -> String:
	var heading := RegEx.new()
	heading.compile("^#{1,6}\\s+(.*)$")
	var bold := RegEx.new()
	bold.compile("\\*\\*(.+?)\\*\\*")
	var lines: PackedStringArray = []
	for raw in markdown.replace("\r", "").split("\n"):
		var line := bold.sub(raw.replace("[", "[lb]"), "[b]$1[/b]", true)
		var found := heading.search(line)
		if found != null:
			line = "[color=%s][b]%s[/b][/color]" % [HEADING_COLOUR, found.get_string(1).strip_edges()]
		elif line.begins_with("- "):
			line = "  • " + line.substr(2)
		lines.append(line)
	return "\n".join(lines)
