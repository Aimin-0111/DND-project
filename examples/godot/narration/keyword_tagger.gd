class_name KeywordTagger
extends RefCounted
## Turns the AI's narration into safe BBCode with effect tags.
## Three ways to decide WHICH words get an effect (compared in mockups.html):
##
##   Option A - the AI writes the tags:   "The [burn]torch[/burn] gutters."
##              -> tag_option_a()
##   Option B - a word list (keywords.csv, edited by the writer):
##              "fire" -> burn            -> tag_option_b()
##   Option C - both: keep the AI's valid tags, then tag the remaining
##              words from the list       -> tag_option_c()  (recommended)
##
## In every option the text comes from the AI, so it is untrusted:
## any BBCode we did not allow ([url], [img], [font_size=500]...) is escaped
## and shown as plain text instead of being run.

const EFFECTS := ["burn", "freeze", "shock", "poison", "whisper", "holy"]

## word (lower case) -> effect name, filled from keywords.csv
var words := {}
var _word_regex: RegEx


## keywords.csv columns: effect,lang,words   (words separated by "|")
## Example row:          burn,fr,feu|flamme|flammes|brûle|brûlant|braise
func load_keywords(rows: Array, lang: String) -> void:
	words.clear()
	for row in rows:
		if row["lang"] != lang or not row["effect"] in EFFECTS:
			continue
		for w in String(row["words"]).split("|", false):
			words[w.strip_edges().to_lower()] = row["effect"]
	# One regex for all words, longest first so "flames" wins over "flame".
	var list: Array = words.keys()
	list.sort_custom(func(a, b): return a.length() > b.length())
	var escaped := PackedStringArray()
	for w in list:
		escaped.append(_regex_escape(w))
	_word_regex = RegEx.new()
	# (*UCP) = understand accented letters, (?i) = ignore case, so "Éclair"
	# matches "éclair". (?<!\p{L}) and (?!\p{L}) mean "no letter just before
	# or after": "fire" matches but "firewood" doesn't.
	_word_regex.compile("(*UCP)(?i)(?<!\\p{L})(" + "|".join(escaped) + ")(?!\\p{L})")


## Option A: only the AI's tags.
func tag_option_a(ai_text: String) -> String:
	return _allow_effect_tags(_escape_bbcode(ai_text))


## Option B: only the word list. The AI's tags (if any) are shown as text.
func tag_option_b(ai_text: String) -> String:
	return _apply_word_list(_escape_bbcode(ai_text))


## Option C: the AI's valid tags first, then the word list for the rest.
func tag_option_c(ai_text: String) -> String:
	return _apply_word_list(_allow_effect_tags(_escape_bbcode(ai_text)))


# --- helpers -----------------------------------------------------------

## Every "[" becomes "[lb]", which RichTextLabel shows as a literal "[".
## After this, the text cannot contain any working BBCode.
func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")


## Turns the escaped "[lb]burn]" back into a real "[burn]", for known effects only.
func _allow_effect_tags(text: String) -> String:
	for e in EFFECTS:
		text = text.replace("[lb]%s]" % e, "[%s]" % e)
		text = text.replace("[lb]/%s]" % e, "[/%s]" % e)
	return text


func _apply_word_list(text: String) -> String:
	if _word_regex == null or words.is_empty():
		return text
	var protected := _tagged_ranges(text)
	var out := ""
	var last := 0
	for m in _word_regex.search_all(text):
		if _inside(m.get_start(), protected):
			continue   # already inside an AI tag (Option C)
		var word := m.get_string()
		var effect: String = words[word.to_lower()]
		out += text.substr(last, m.get_start() - last)
		out += "[%s]%s[/%s]" % [effect, word, effect]
		last = m.get_end()
	return out + text.substr(last)


## Start/end positions of text already inside [effect]...[/effect].
func _tagged_ranges(text: String) -> Array:
	var re := RegEx.new()
	re.compile("(?s)\\[(" + "|".join(EFFECTS) + ")\\].*?\\[/\\1\\]")
	var ranges := []
	for m in re.search_all(text):
		ranges.append(Vector2i(m.get_start(), m.get_end()))
	return ranges


func _inside(pos: int, ranges: Array) -> bool:
	for r in ranges:
		if pos >= r.x and pos < r.y:
			return true
	return false


func _regex_escape(s: String) -> String:
	var out := ""
	for c in s:
		if c in ".^$*+?()[]{}|\\":
			out += "\\"
		out += c
	return out
