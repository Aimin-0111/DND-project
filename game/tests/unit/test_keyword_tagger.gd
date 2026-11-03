extends RefCounted
## Safe BBCode, French accents, the option-C word list, and how the story
## panel shows the six effects.

const ALL_SIX := "[burn]fire[/burn] [freeze]frost[/freeze] [shock]spark[/shock] [poison]venom[/poison] [whisper]murmur[/whisper] [holy]radiant[/holy]"
const ALL_SIX_STILL := "[color=#ff8a3d]fire[/color] [color=#9fd8ff]frost[/color] [color=#ffe066]spark[/color] [color=#8fd16a]venom[/color] [color=#b9b3c9]murmur[/color] [color=#ffe9a8]radiant[/color]"
const ALL_SIX_TEXT := "fire frost spark venom murmur radiant"


func run() -> Array:
	var failures: Array = []
	var tagger := KeywordTagger.new()
	tagger.load_keywords(Content.table("keywords"), "fr")

	var french := tagger.tag_option_c("La braise rouge, le givre bleu et l'éclair blanc.")
	if not "[burn]braise[/burn]" in french:
		failures.append("FR burn word was not tagged: %s" % french)
	if not "[freeze]givre[/freeze]" in french:
		failures.append("FR freeze word was not tagged: %s" % french)
	if not "[shock]éclair[/shock]" in french:
		failures.append("FR shock word was not tagged: %s" % french)

	var english := KeywordTagger.new()
	english.load_keywords(Content.table("keywords"), "en")
	var text := english.tag_option_c("The fire, the frost and the lightning.")
	if not "[burn]fire[/burn]" in text:
		failures.append("EN burn word was not tagged: %s" % text)
	if not "[freeze]frost[/freeze]" in text:
		failures.append("EN freeze word was not tagged: %s" % text)

	var unsafe := english.tag_option_c("[url=https://evil]click[/url] and [font_size=500]boom[/font_size]")
	if "[url=" in unsafe:
		failures.append("unsafe BBCode was not escaped")
	if "[font_size" in unsafe:
		failures.append("font_size BBCode was not escaped")
	if not "[lb]url=https://evil]click[lb]/url]" in unsafe:
		failures.append("escaped URL does not look like literal text: %s" % unsafe)

	var ai_tagged := english.tag_option_c("[burn]fire[/burn] and fire again")
	if ai_tagged.count("[burn]") != 2:
		failures.append("option C should keep the AI tag and tag the second word: %s" % ai_tagged)
	if ai_tagged.count("[/burn]") != 2:
		failures.append("option C produced unbalanced burn tags: %s" % ai_tagged)

	var plain := KeywordTagger.new()
	var five := plain.tag_option_a("[holy]a[/holy] [holy]b[/holy] [holy]c[/holy] [holy]d[/holy] [holy]e[/holy]")
	if five.count("[holy]") != 4 or not " e" in five:
		failures.append("only the first 4 AI tags should be kept, the 5th word stays: %s" % five)

	var long_tag := plain.tag_option_a("[burn]%s[/burn]" % "x".repeat(40))
	if "[burn]" in long_tag or not "x".repeat(40) in long_tag:
		failures.append("a tag around 40 characters should be removed, its text kept: %s" % long_tag)

	var nested := plain.tag_option_a("[burn]a [freeze]b[/freeze] c[/burn]")
	if "[burn]" in nested or "[freeze]" in nested:
		failures.append("nested tags should show as plain text: %s" % nested)

	var unclosed := plain.tag_option_a("[burn]fire and more")
	if "[burn]" in unclosed:
		failures.append("an unclosed tag should show as plain text: %s" % unclosed)

	var many := english.tag_option_c("fire fire fire fire fire fire fire fire fire fire")
	if many.count("[burn]") != 6:
		failures.append("at most 6 words should animate per entry: %s" % many)

	failures.append_array(_panel_checks())
	failures.append_array(_motion_checks())
	return failures


## The story panel never shows a raw effect tag. Poison, whisper and holy move
## in a new entry; old entries and reduce motion turn all six effects into
## their still colours. A RichTextLabel only updates every frame while it holds
## a moving effect, so is_processing_internal() tells whether any word moves.
func _panel_checks() -> Array:
	var failures: Array = []
	for effect in ["poison", "whisper", "holy"]:
		var panel := _new_panel()
		panel.add_entry("A [%s]word[/%s] here." % [effect, effect])
		var shown := panel.get_parsed_text()
		if "[" in shown or not "A word here." in shown:
			failures.append("%s should show without a raw tag: '%s'" % [effect, shown])
		if not panel.is_processing_internal():
			failures.append("%s should move in a new entry" % effect)
		_free_panel(panel)

	var calm := _new_panel()
	calm.reduce_motion = true
	calm.add_entry(ALL_SIX)
	failures.append_array(_still_failures(calm, "with reduce motion"))
	var colours: String = calm._freeze_effects(ALL_SIX, calm.STILL_COLORS.keys())
	if colours != ALL_SIX_STILL:
		failures.append("still colours should match SPEC-narration: %s" % colours)
	_free_panel(calm)

	var old := _new_panel()
	old.add_entry(ALL_SIX)
	for _i in old.animated_entries - 1:
		old.add_entry("Later text.")
	if not old.is_processing_internal():
		failures.append("an entry should move while it is one of the newest %d" % old.animated_entries)
	old.add_entry("Later text.")
	failures.append_array(_still_failures(old, "once %d newer entries follow" % old.animated_entries))
	_free_panel(old)
	return failures


func _still_failures(panel: RichTextLabel, when: String) -> Array:
	var failures: Array = []
	var shown := panel.get_parsed_text()
	if "[" in shown or not ALL_SIX_TEXT in shown:
		failures.append("all six effects should show as plain words %s: '%s'" % [when, shown])
	if panel.is_processing_internal():
		failures.append("no word should move %s" % when)
	return failures


## The later effects stay readable: letters only move up and down, by at most
## 2 px, so neighbours never overlap, and whisper never fades below half.
func _motion_checks() -> Array:
	var failures: Array = []
	var fx := CharFXTransform.new()
	for effect in [PoisonEffect.new(), WhisperEffect.new(), HolyEffect.new()]:
		for step in 200:
			fx.elapsed_time = step * 0.05
			fx.relative_index = step % 9
			fx.offset = Vector2.ZERO
			fx.color = Color.WHITE
			effect._process_custom_fx(fx)
			if fx.offset.x != 0.0 or absf(fx.offset.y) > 2.0 or fx.color.a < 0.5:
				failures.append("%s should stay small and readable at %.2f s: offset %s, alpha %.2f"
						% [effect.bbcode, fx.elapsed_time, fx.offset, fx.color.a])
				break
	return failures


func _new_panel() -> RichTextLabel:
	var panel: RichTextLabel = load("res://narration/narration_panel.gd").new()
	(Engine.get_main_loop() as SceneTree).root.add_child(panel)
	return panel


func _free_panel(panel: RichTextLabel) -> void:
	panel.get_parent().remove_child(panel)
	panel.free()
