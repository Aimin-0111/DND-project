extends RefCounted
## Prompt order, allowed ids and placement of the language/action turn input.


func run() -> Array:
	var failures: Array = []
	var state := GameState.new_game(7)
	var allowed := Content.allowed_ids()
	allowed["skills"] = GameState.allowed_skills(state)

	var prompt := PromptBuilder.build(
		state,
		"Je traverse le pont.",
		"RULES-MARKER",
		"CODEX-MARKER",
		allowed,
		"fr",
	)
	var text := PromptBuilder.to_single_text(prompt)

	var order := [
		"=== RULES ===",
		"=== CODEX ===",
		"=== STORY SO FAR ===",
		"=== STATE ===",
		"=== ALLOWED IDS ===",
		"=== TURN INPUT ===",
	]
	var previous := -1
	for marker in order:
		var position := text.find(marker)
		if position == -1:
			failures.append("prompt is missing '%s'" % marker)
		elif position < previous:
			failures.append("prompt order is wrong at '%s'" % marker)
		else:
			previous = position

	if not '"language": "fr"' in text:
		failures.append("language must be in TURN INPUT")
	if not "Je traverse le pont." in text:
		failures.append("player action must be in TURN INPUT")
	if not "old_mill" in text:
		failures.append("allowed locations must be visible to the AI")
	if not "Stealth" in text:
		failures.append("allowed skills must be visible to the AI")
	if not "RULES-MARKER" in str(prompt["rules"]):
		failures.append("rules were not passed through")

	return failures
