class_name KeywordTagger
extends RefCounted
## Turns AI narration into safe BBCode with effect tags.
## Option C: keep the AI's valid [burn]...[/burn] tags, then tag remaining
## words from keywords.csv. Any other BBCode is escaped and shown as text.

const EFFECTS := ["burn", "freeze", "shock", "poison", "whisper", "holy"]

var words: Dictionary = {}
var _word_regex: RegEx


## `rows` are keyword rows for the active language from Content.keywords().
func load_keywords(rows: Array, lang: String) -> void:
	words.clear()
	for row in rows:
		if str(row.get("lang", "")) != lang or not str(row.get("effect", "")) in EFFECTS:
			continue
		var effect := str(row["effect"])
		for word in str(row.get("words", "")).split("|", false):
			var cleaned := word.strip_edges().to_lower()
			if not cleaned.is_empty():
				words[cleaned] = effect
	_word_regex = null
	if words.is_empty():
		return
	var list: Array = words.keys()
	list.sort_custom(func(a, b): return a.length() > b.length())
	var escaped := PackedStringArray()
	for word in list:
		escaped.append(_regex_escape(word))
	_word_regex = RegEx.new()
	# (*UCP) understands accents, (?i) ignores case, and the lookarounds avoid
	# matching "fire" inside "firewood".
	_word_regex.compile("(*UCP)(?i)(?<!\\p{L})(" + "|".join(escaped) + ")(?!\\p{L})")


## Option A: only the AI's tags.
func tag_option_a(ai_text: String) -> String:
	return _allow_effect_tags(_escape_bbcode(ai_text))


## Option B: only the word list. The AI's tags are shown as text.
func tag_option_b(ai_text: String) -> String:
	return _apply_word_list(_escape_bbcode(ai_text))


## Option C: the AI's valid tags first, then the word list for the rest.
func tag_option_c(ai_text: String) -> String:
	return _apply_word_list(_allow_effect_tags(_escape_bbcode(ai_text)))


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")


func _allow_effect_tags(text: String) -> String:
	for effect in EFFECTS:
		text = text.replace("[lb]%s]" % effect, "[%s]" % effect)
		text = text.replace("[lb]/%s]" % effect, "[/%s]" % effect)
	return text


func _apply_word_list(text: String) -> String:
	if _word_regex == null or words.is_empty():
		return text
	var protected := _tagged_ranges(text)
	var out := ""
	var last := 0
	for match in _word_regex.search_all(text):
		if _inside(match.get_start(), protected):
			continue
		var word := match.get_string()
		var effect: String = words[word.to_lower()]
		out += text.substr(last, match.get_start() - last)
		out += "[%s]%s[/%s]" % [effect, word, effect]
		last = match.get_end()
	return out + text.substr(last)


func _tagged_ranges(text: String) -> Array:
	var re := RegEx.new()
	re.compile("(?s)\\[(" + "|".join(EFFECTS) + ")\\].*?\\[/\\1\\]")
	var ranges := []
	for match in re.search_all(text):
		ranges.append(Vector2i(match.get_start(), match.get_end()))
	return ranges


func _inside(position: int, ranges: Array) -> bool:
	for value in ranges:
		if position >= value.x and position < value.y:
			return true
	return false


func _regex_escape(text: String) -> String:
	var out := ""
	for character in text:
		if character in ".^$*+?()[]{}|\\":
			out += "\\"
		out += character
	return out
