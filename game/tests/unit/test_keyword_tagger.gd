extends RefCounted
## Safe BBCode, French accents and the option-C word list.


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

	return failures
