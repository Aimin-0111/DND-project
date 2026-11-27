extends RefCounted
## Layout v2 (SPEC-main-screen "Layout v2 (Beta-0.4)") on the real main scene:
## - the regions: top bar (Menu, place · clock · weather, Backpack), story on
##   the left (≈40%), world on the right (≈60%), bottom bar (HP bar and gold),
##   and no gear button left next to the action box;
## - each Menu entry's signal path (Save, Load, Language, AI settings, Close),
##   the AI mode at the top, Esc and a click outside;
## - the Backpack button and B open the empty backpack window; Esc closes it;
## - typing "b", "m" or "1" in the focused action box only types the character;
## - the dice zone: empty, centred in the world panel, ignores the mouse;
## - the minimap: 7 x 7 squares around the hero, kind colours from kinds.csv
##   for visited squares, fog for the others and off the world, the red frame
##   on the hero's square; it recentres after a travel and a load;
## - the world map window: a click on the minimap or M opens it, the whole
##   grid in the same colours with the hero marked; M, Esc, Close or a click
##   outside closes it; a click on it never travels;
## - Menu → Codex: a read-only, scrolling window with the current language's
##   Codex pages (the AI's), also from CRLF files;
## - the tracked quest at the top left of the world: the first unfinished
##   quest's title and stage in the current language, hidden when none.
## A test settings file; the runner points the saves at a test folder.

const TEST_SETTINGS := "user://__test_layout_v2.cfg"
const ENTRIES := "Panel/Margin/VBox/"
const WINDOW := "Panel/Margin/VBox/"


## Records the clicks that reach the world's viewport.
class ClickProbe:
	extends Node
	var clicks := 0

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			clicks += 1


func run() -> Array:
	var failures: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ["no SceneTree available"]
	var content = tree.root.get_node("Content")
	var real_settings: String = content.settings_path
	var start_language: String = content.language()
	content.settings_path = TEST_SETTINGS
	DirAccess.remove_absolute(TEST_SETTINGS)
	content.set_language("en")
	content.remember_language()
	Game.new_game(12345)
	var main = load("res://main.tscn").instantiate()
	tree.root.add_child(main)
	layout(main)

	failures.append_array(_region_checks(main))
	failures.append_array(_menu_checks(main, content))
	failures.append_array(_backpack_checks(main))
	failures.append_array(_key_checks(main))
	failures.append_array(_dice_zone_checks(main))
	failures.append_array(_minimap_checks(main))
	failures.append_array(_world_map_checks(main))
	failures.append_array(_codex_checks(main, content))
	failures.append_array(_tracked_quest_checks(main, content))

	tree.root.remove_child(main)
	main.free()
	for slot in ["manual", "auto"]:
		SaveSystem.delete_save(slot)
	DirAccess.remove_absolute(TEST_SETTINGS)
	content.settings_path = real_settings
	content.set_language(start_language)
	Game.new_game(12345)
	return failures


## Containers place their children one frame late and the tests run within
## one frame: sort every container now, parents first.
static func layout(node: Node) -> void:
	if node is Container:
		node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children():
		layout(child)


func _region_checks(main) -> Array:
	var failures: Array = []
	var top_bar = main.get_node_or_null("Layout/TopBar")
	var bottom_bar = main.get_node_or_null("Layout/BottomBar")
	var story: Control = main.get_node_or_null("Layout/Split/StoryPanel")
	var world_panel: Control = main.get_node_or_null("Layout/Split/WorldPanel")
	if top_bar == null or bottom_bar == null or story == null or world_panel == null:
		return ["layout v2 needs Layout/TopBar, Layout/Split/StoryPanel, Layout/Split/WorldPanel and Layout/BottomBar"]
	if main.get_node_or_null("Layout/Split/WorldPanel/WorldView/SubViewport/World") != main.world:
		failures.append("the world should be drawn inside the world panel")

	# Top bar: Menu at the left, place · clock · weather in the middle, Backpack at the right.
	var menu_button: Button = top_bar.get_node_or_null("HBox/MenuButton")
	var info: Control = top_bar.get_node_or_null("HBox/Info")
	var backpack_button: Button = top_bar.get_node_or_null("HBox/BackpackButton")
	if menu_button == null or info == null or backpack_button == null:
		failures.append("the top bar needs HBox/MenuButton, HBox/Info and HBox/BackpackButton")
	else:
		var menu_rect := menu_button.get_global_rect()
		var info_rect := info.get_global_rect()
		var backpack_rect := backpack_button.get_global_rect()
		if not (menu_rect.end.x <= info_rect.position.x + 1.0 and info_rect.end.x <= backpack_rect.position.x + 1.0):
			failures.append("top bar order: Menu, then place · clock · weather, then Backpack: %s %s %s" % [menu_rect, info_rect, backpack_rect])
		if menu_rect.position.x > 20.0 or backpack_rect.end.x < main.size.x - 20.0:
			failures.append("the Menu button sits at the top left and the Backpack button at the top right")
		if menu_button.text != Content.t("ui.menu") or menu_button.icon == null:
			failures.append("the Menu button shows the gear icon and '%s', got '%s'" % [Content.t("ui.menu"), menu_button.text])
		if backpack_button.text != Content.t("ui.backpack"):
			failures.append("the Backpack button says '%s', got '%s'" % [Content.t("ui.backpack"), backpack_button.text])
		var expected := {
			"Place": Content.t("location.mill_road.name"),
			"Clock": Content.t("ui.clock").format({"day": 1, "time": "08:00"}),
			"Weather": Content.t("weather.clear"),
		}
		for part in expected:
			var label: Label = info.get_node_or_null(part)
			if label == null or label.text != expected[part]:
				failures.append("the top bar's %s should say '%s', got '%s'" % [part, expected[part], "<none>" if label == null else label.text])

	# Story on the left (≈40%), world on the right (≈60%).
	var story_rect := story.get_global_rect()
	var world_rect := world_panel.get_global_rect()
	if story_rect.position.x > world_rect.position.x:
		failures.append("the story is on the left and the world on the right")
	var ratio := story_rect.size.x / maxf(story_rect.size.x + world_rect.size.x, 1.0)
	if absf(ratio - 0.4) > 0.03:
		failures.append("the story takes about 40%% of the width, got %d%%" % roundi(ratio * 100.0))

	# The bars: one line each, above and below the story and the world.
	var top_rect: Rect2 = top_bar.get_global_rect()
	var bottom_rect: Rect2 = bottom_bar.get_global_rect()
	if top_rect.position.y > 1.0 or top_rect.end.y > story_rect.position.y + 1.0:
		failures.append("the top bar sits above the story and the world")
	if bottom_rect.position.y < story_rect.end.y - 1.0 or absf(bottom_rect.end.y - main.size.y) > 1.0:
		failures.append("the bottom bar sits at the bottom, under the story and the world")
	if top_rect.size.y > 60.0 or bottom_rect.size.y > 60.0:
		failures.append("each bar is one line high, got %d and %d px" % [int(top_rect.size.y), int(bottom_rect.size.y)])

	# Bottom bar: the HP bar with its numbers, and gold.
	var hp = bottom_bar.get_node_or_null("HBox/HP")
	var gold: Label = bottom_bar.get_node_or_null("HBox/Gold")
	var hero: Dictionary = Game.state["hero"]
	if hp == null or gold == null:
		failures.append("the bottom bar needs HBox/HP and HBox/Gold")
	else:
		var bar: ProgressBar = hp.get_node_or_null("Bar")
		if bar == null or int(bar.value) != int(hero["hp"]) or int(bar.max_value) != int(hero["hp_max"]):
			failures.append("the HP bar should show the hero's HP")
		if hp.get_node("Name").text != Content.t("ui.hp") or hp.get_node("Value").text != "%d/%d" % [int(hero["hp"]), int(hero["hp_max"])]:
			failures.append("the HP bar shows '%s' and its numbers, got '%s' '%s'" % [Content.t("ui.hp"), hp.get_node("Name").text, hp.get_node("Value").text])
		if not gold.text.contains(str(int(Game.state["gold"]))):
			failures.append("the bottom bar shows the gold, got '%s'" % gold.text)

	# The settings button moved into the Menu: no gear left anywhere else.
	if main.find_child("SettingsButton", true, false) != null:
		failures.append("the gear button next to the action box should be gone")
	for button in main.find_children("*", "Button", true, false):
		if button != menu_button and button.icon != null and button.icon.resource_path.ends_with("gear.svg"):
			failures.append("only the Menu button shows the gear, also %s" % main.get_path_to(button))
	return failures


func _open_menu(main) -> void:
	if not main.menu.visible:
		main.get_node("Layout/TopBar/HBox/MenuButton").pressed.emit()


func _menu_checks(main, content) -> Array:
	var failures: Array = []
	var menu = main.get_node_or_null("WindowLayer/Menu")
	if menu == null or main.menu != menu:
		return ["the Menu should be WindowLayer/Menu (main.menu)"]
	var menu_button: Button = main.get_node("Layout/TopBar/HBox/MenuButton")
	if menu.visible:
		failures.append("the menu starts closed")
	menu_button.pressed.emit()
	if not menu.visible:
		return failures + ["the Menu button should open the menu"]
	var ai_mode: Label = menu.get_node_or_null(ENTRIES + "AiMode")
	if ai_mode == null or ai_mode.get_index() != 0 or ai_mode.text != Content.t("ui.hud_ai_copy_paste"):
		failures.append("the top of the menu shows the AI mode '%s'" % Content.t("ui.hud_ai_copy_paste"))
	for entry in ["SaveButton", "LoadButton", "Languages", "AiSettingsButton", "CloseButton"]:
		if menu.get_node_or_null(ENTRIES + entry) == null:
			failures.append("the menu needs %s" % entry)
	if not failures.is_empty():
		return failures

	# Save: the manual slot, as before.
	Game.state["gold"] = 42
	menu.get_node(ENTRIES + "SaveButton").pressed.emit()
	if menu.visible:
		failures.append("choosing Save closes the menu")
	if main.status_label.text != Content.t("ui.saved") or not FileAccess.file_exists(SaveSystem._path("manual")):
		failures.append("Menu → Save writes the manual save and says '%s', got '%s'" % [Content.t("ui.saved"), main.status_label.text])

	# Load: the newer save (bug B7), as before.
	Game.state["gold"] = 1
	_open_menu(main)
	menu.get_node(ENTRIES + "LoadButton").pressed.emit()
	if int(Game.state["gold"]) != 42 or main.status_label.text != Content.t("ui.loaded"):
		failures.append("Menu → Load loads the save (gold 42) and says '%s', got %d '%s'" % [Content.t("ui.loaded"), int(Game.state["gold"]), main.status_label.text])
	if menu.visible:
		failures.append("choosing Load closes the menu")

	# Language: the other language relabels the whole screen and is remembered.
	_open_menu(main)
	var english: Button = menu.get_node(ENTRIES + "Languages/en")
	var french: Button = menu.get_node(ENTRIES + "Languages/fr")
	if english.text != Content.t_in("ui.language_name", "en") or french.text != Content.t_in("ui.language_name", "fr"):
		failures.append("the language entries read English / Français, got '%s' / '%s'" % [english.text, french.text])
	french.pressed.emit()
	var saved := ConfigFile.new()
	saved.load(TEST_SETTINGS)
	if content.language() != "fr" or str(saved.get_value("general", "language", "")) != "fr":
		failures.append("Menu → Français switches to French and remembers it")
	if menu_button.text != Content.t_in("ui.menu", "fr") or main.act_button.text != Content.t_in("ui.act", "fr") \
			or menu.get_node(ENTRIES + "SaveButton").text != Content.t_in("ui.save", "fr"):
		failures.append("the language switch relabels the top bar, the story panel and the menu")
	if not french.disabled or english.disabled:
		failures.append("the current language's entry is the disabled one")
	_open_menu(main)
	english.pressed.emit()
	if content.language() != "en":
		failures.append("Menu → English switches back")

	# AI settings: the settings dialog of M1 (AI mode and key).
	_open_menu(main)
	var settings_dialog = menu.get_node_or_null("SettingsLayer/SettingsDialog")
	menu.get_node(ENTRIES + "AiSettingsButton").pressed.emit()
	if settings_dialog == null or not settings_dialog.visible:
		failures.append("Menu → AI settings opens the settings dialog")
	if menu.visible:
		failures.append("choosing AI settings closes the menu")
	if settings_dialog != null:
		settings_dialog.close()

	# Close, Esc, a click outside, and the Menu button again.
	_open_menu(main)
	menu.get_node(ENTRIES + "CloseButton").pressed.emit()
	if menu.visible:
		failures.append("Close closes the menu")
	_open_menu(main)
	main.get_viewport().push_input(_key(KEY_ESCAPE, 0), true)
	if menu.visible:
		failures.append("Esc closes the menu")
	_open_menu(main)
	var backdrop: Control = menu.get_node_or_null("Backdrop")
	if backdrop == null:
		failures.append("the menu needs a Backdrop that catches a click outside")
	else:
		backdrop.gui_input.emit(_click(Vector2(900, 500), true))
		if menu.visible:
			failures.append("a click outside closes the menu")
	_open_menu(main)
	menu_button.pressed.emit()
	if menu.visible:
		failures.append("the Menu button closes the open menu")
	return failures


func _backpack_checks(main) -> Array:
	var failures: Array = []
	var window = main.get_node_or_null("WindowLayer/BackpackWindow")
	if window == null or main.backpack_window != window:
		return ["the backpack window should be WindowLayer/BackpackWindow (main.backpack_window)"]
	var button: Button = main.get_node("Layout/TopBar/HBox/BackpackButton")
	if window.visible:
		failures.append("the backpack window starts closed")
	button.pressed.emit()
	if not window.visible:
		return failures + ["the Backpack button opens the backpack window"]
	var title: Label = window.get_node_or_null(WINDOW + "Header/Title")
	var close: Button = window.get_node_or_null(WINDOW + "Header/CloseButton")
	var body: Control = window.get_node_or_null(WINDOW + "Body")
	if title == null or close == null or body == null:
		return failures + ["the backpack window needs Header/Title, Header/CloseButton and Body"]
	if title.text != Content.t("ui.backpack") or close.text != Content.t("ui.close"):
		failures.append("the backpack window shows '%s' and '%s', got '%s' '%s'" % [Content.t("ui.backpack"), Content.t("ui.close"), title.text, close.text])
	if body.get_child_count() != 0:
		failures.append("the backpack window stays empty until T3")
	if window.mouse_filter != Control.MOUSE_FILTER_IGNORE or window.get_node_or_null("Backdrop") != null:
		failures.append("the world keeps running: nothing blocks the clicks around the backpack window")
	_open_menu(main)
	if window.visible:
		failures.append("opening the menu closes the backpack window (one window at a time)")
	main.menu.close()
	button.pressed.emit()
	close.pressed.emit()
	if window.visible:
		failures.append("the close button closes the backpack window")
	button.pressed.emit()
	button.pressed.emit()
	if window.visible:
		failures.append("the Backpack button closes the open backpack window")
	return failures


## Shortcut keys only act when no text field has focus.
func _key_checks(main) -> Array:
	var failures: Array = []
	var window = main.backpack_window
	var viewport: Viewport = main.get_viewport()
	main.action_input.text = ""
	main.action_input.grab_focus()
	if main.action_input.has_method("edit"):
		main.action_input.edit()
	for letter in ["b", "m", "1"]:
		viewport.push_input(_typed(letter), true)
	if main.action_input.text != "bm1":
		failures.append("typing b, m and 1 in the action box types them, got '%s'" % main.action_input.text)
	if window.visible or main.menu.visible or main.world_map_window.visible:
		failures.append("typing in the action box opens nothing")

	main.action_input.text = ""
	viewport.gui_release_focus()
	viewport.push_input(_typed("b"), true)
	if not window.visible:
		failures.append("B opens the backpack when no text field has focus")
	viewport.push_input(_key(KEY_ESCAPE, 0), true)
	if window.visible:
		failures.append("Esc closes the backpack")
	viewport.push_input(_typed("b"), true)
	viewport.push_input(_typed("b"), true)
	if window.visible:
		failures.append("B closes the open backpack")
	if not main.action_input.text.is_empty():
		failures.append("the shortcut keys don't type into the action box, got '%s'" % main.action_input.text)
	return failures


func _dice_zone_checks(main) -> Array:
	var failures: Array = []
	var world_panel: Control = main.get_node("Layout/Split/WorldPanel")
	var zone: Control = world_panel.get_node_or_null("DiceZone")
	if zone == null:
		return ["the world panel should hold the reserved DiceZone"]
	if zone.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		failures.append("the dice zone must ignore the mouse")
	if zone.get_child_count() != 0:
		failures.append("the dice zone stays empty in Beta-0.4")
	if absf(zone.size.x - 120.0) > 1.0 or absf(zone.size.y - 120.0) > 1.0:
		failures.append("the dice zone is about 120 x 120, got %s" % zone.size)
	var centre := zone.get_global_rect().get_center()
	if centre.distance_to(world_panel.get_global_rect().get_center()) > 2.0:
		failures.append("the dice zone is centred in the world panel")
	if zone.get_index() < world_panel.get_node("WorldView").get_index():
		failures.append("the dice zone is drawn over the world")

	# A click on the dice zone still reaches the world.
	var probe := ClickProbe.new()
	var sub_viewport: SubViewport = world_panel.get_node("WorldView/SubViewport")
	sub_viewport.add_child(probe)
	main.world.set_locked(true)
	main.get_viewport().push_input(_click(centre, true), true)
	main.get_viewport().push_input(_click(centre, false), true)
	main.world.set_locked(false)
	if probe.clicks != 1:
		failures.append("a click on the dice zone should reach the world, %d did" % probe.clicks)
	sub_viewport.remove_child(probe)
	probe.free()
	return failures


## kinds.csv: kind id -> its colour.
func _kind_colours() -> Dictionary:
	var out := {}
	for row in ContentLoader.load_csv("res://content/maps/kinds.csv"):
		out[str(row.get("id", "")).strip_edges()] = Color.html(str(row.get("colour", "")).strip_edges())
	return out


## What a square should look like: its kind's colour when visited, else fog.
func _expected(kinds: Dictionary, visited: Dictionary, at: Vector2i) -> Color:
	var map: WorldMap = Game.world_map
	if at.x < 0 or at.y < 0 or at.x >= map.width or at.y >= map.height:
		return MapView.FOG
	var id := WorldMap.square_id(at.x, at.y)
	if not visited.has(id):
		return MapView.FOG
	return kinds.get(map.kind_of(id), MapView.FOG)


## Index in the minimap's 7 x 7 cells of the square (dx, dy) from the hero's.
func _around(dx: int, dy: int) -> int:
	return (dy + 3) * 7 + (dx + 3)


func _minimap_checks(main) -> Array:
	var failures: Array = []
	var world_panel: Control = main.get_node("Layout/Split/WorldPanel")
	var minimap = world_panel.get_node_or_null("Minimap")
	if minimap == null or main.get("minimap") != minimap:
		return ["the world panel should hold the Minimap (main.minimap)"]
	var rect: Rect2 = minimap.get_global_rect()
	var panel_rect := world_panel.get_global_rect()
	if rect.end.x < panel_rect.end.x - 24.0 or rect.position.y > panel_rect.position.y + 24.0 or not panel_rect.encloses(rect):
		failures.append("the minimap sits at the top right of the world panel: %s in %s" % [rect, panel_rect])
	if minimap.get_index() < world_panel.get_node("WorldView").get_index():
		failures.append("the minimap is drawn over the world")
	if MapView.FRAME_COLOUR.r < 0.7 or MapView.FRAME_COLOUR.g > 0.3 or MapView.FRAME_COLOUR.b > 0.3:
		failures.append("the hero's frame is red, got %s" % MapView.FRAME_COLOUR)
	var kinds := _kind_colours()

	# A fake state: four visited squares around sq_24_24, the rest is fog.
	var visited := {"sq_24_24": {}, "sq_25_24": {}, "sq_24_23": {}, "sq_21_21": {}}
	minimap.refresh(Game.world_map, {"square": "sq_24_24", "squares": visited})
	if minimap.cells.size() != 49 or minimap.columns != 7 or minimap.rows != 7:
		return failures + ["the minimap shows 7 x 7 squares, got %d" % minimap.cells.size()]
	var wrong := 0
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if minimap.cells[_around(dx, dy)] != _expected(kinds, visited, Vector2i(24 + dx, 24 + dy)):
				wrong += 1
	if wrong != 0:
		failures.append("minimap: %d of 49 squares have the wrong colour (visited: kind colour, else fog)" % wrong)
	for id in visited:
		var at := WorldMap.coords(id)
		var want: Color = kinds.get(Game.world_map.kind_of(id), Color.BLACK)
		if minimap.cells[_around(at.x - 24, at.y - 24)] != want:
			failures.append("the visited square %s should be filled with its kind's colour %s" % [id, want])
	if minimap.cells[_around(2, 2)] != MapView.FOG:
		failures.append("an unvisited square is fog")
	if minimap.frame_index != _around(0, 0):
		failures.append("the red frame is on the hero's square (the middle), got %d" % minimap.frame_index)

	# At the corner of the world: the squares off the world are fog.
	minimap.refresh(Game.world_map, {"square": "sq_0_0", "squares": {"sq_0_0": {}, "sq_1_0": {}}})
	for off in [_around(-1, 0), _around(0, -1), _around(-3, -3), _around(3, -1)]:
		if minimap.cells[off] != MapView.FOG:
			failures.append("squares off the world are fog (cell %d)" % off)
	if minimap.cells[_around(1, 0)] != _expected(kinds, {"sq_1_0": {}}, Vector2i(1, 0)):
		failures.append("at the corner the visited neighbour keeps its kind's colour")

	# The real state: it recentres after a travel and after a load.
	Game.state_changed.emit(Game.state)
	var start := WorldMap.coords(str(Game.state["square"]))
	if minimap.origin + Vector2i(3, 3) != start:
		failures.append("the minimap is centred on the hero's square %s, got %s" % [start, minimap.origin + Vector2i(3, 3)])
	Game.set_hero_cell(Vector2i(31, 0))
	Game.apply_turn({}, [{"type": "travel", "to": "north"}])
	var north := start + Vector2i(0, -1)
	if WorldMap.coords(str(Game.state["square"])) != north:
		return failures + ["travel north should apply"]
	if minimap.origin + Vector2i(3, 3) != north:
		failures.append("after a travel the minimap recentres on %s, got %s" % [north, minimap.origin + Vector2i(3, 3)])
	var squares: Dictionary = Game.state["squares"]
	if minimap.cells[_around(0, 0)] != _expected(kinds, squares, north) or minimap.cells[_around(0, 1)] != _expected(kinds, squares, start):
		failures.append("after a travel the new square and the one left behind show their kind's colours")
	main._on_save()
	Game.set_hero_cell(Vector2i(31, 63))
	Game.apply_turn({}, [{"type": "travel", "to": "south"}])
	if minimap.origin + Vector2i(3, 3) != start:
		failures.append("travelling back recentres on %s" % start)
	main._on_load()
	if minimap.origin + Vector2i(3, 3) != north:
		failures.append("after a load the minimap recentres on the saved square %s, got %s" % [north, minimap.origin + Vector2i(3, 3)])
	return failures


func _world_map_checks(main) -> Array:
	var failures: Array = []
	var window = main.get_node_or_null("WindowLayer/WorldMapWindow")
	if window == null or main.get("world_map_window") != window:
		return ["the world map window should be WindowLayer/WorldMapWindow (main.world_map_window)"]
	var viewport: Viewport = main.get_viewport()
	var map: WorldMap = Game.world_map
	if window.visible:
		failures.append("the world map starts closed")

	# A click on the minimap opens it, and doesn't reach the world.
	var probe := ClickProbe.new()
	var sub_viewport: SubViewport = main.get_node("Layout/Split/WorldPanel/WorldView/SubViewport")
	sub_viewport.add_child(probe)
	var spot: Vector2 = main.minimap.get_global_rect().get_center()
	viewport.push_input(_click(spot, true), true)
	viewport.push_input(_click(spot, false), true)
	var clicks := probe.clicks
	sub_viewport.remove_child(probe)
	probe.free()
	if not window.visible:
		return failures + ["a click on the minimap opens the world map"]
	layout(window)
	if clicks != 0:
		failures.append("the click on the minimap doesn't reach the world")
	var title: Label = window.get_node(WINDOW + "Header/Title")
	if title.text != Content.t("ui.world_map") or window.get_node(WINDOW + "Header/CloseButton").text != Content.t("ui.close"):
		failures.append("the world map window shows '%s' and '%s'" % [Content.t("ui.world_map"), Content.t("ui.close")])

	# The whole grid, in the minimap's colours, with the hero marked.
	var view = window.get_node_or_null(WINDOW + "Body/Map")
	if view == null:
		return failures + ["the world map window needs Body/Map"]
	if view.columns != map.width or view.rows != map.height or view.cells.size() != map.width * map.height:
		failures.append("the world map shows the whole %d x %d grid, got %d x %d" % [map.width, map.height, view.columns, view.rows])
	else:
		var kinds := _kind_colours()
		var squares: Dictionary = Game.state["squares"]
		var wrong := 0
		for y in map.height:
			for x in map.width:
				if view.cells[y * map.width + x] != _expected(kinds, squares, Vector2i(x, y)):
					wrong += 1
		if wrong != 0:
			failures.append("world map: %d squares have the wrong colour" % wrong)
		var hero := WorldMap.coords(str(Game.state["square"]))
		if view.frame_index != hero.y * map.width + hero.x:
			failures.append("the world map marks the hero's square")
	if (window.painted != null) != ResourceLoader.exists(WorldMapWindow.PAINTED_PATH) or view.painted != window.painted:
		failures.append("without maps/world-painted.png the world map uses the flat colours")
	if WorldMapWindow.load_painted("res://content/maps/world.png") == null:
		failures.append("an imported image can be the painted map")

	# Read-only: a click on the map changes nothing and keeps it open.
	var square_before := str(Game.state["square"])
	var cell_before: Variant = Game.state["hero_cell"].duplicate()
	var map_spot: Vector2 = view.get_global_rect().get_center()
	viewport.push_input(_click(map_spot, true), true)
	viewport.push_input(_click(map_spot, false), true)
	if str(Game.state["square"]) != square_before or Game.state["hero_cell"] != cell_before or main._busy or not window.visible:
		failures.append("a click on the world map never travels (and keeps it open)")

	# M, Esc, the close button and a click outside close it; M opens it.
	viewport.gui_release_focus()
	viewport.push_input(_typed("m"), true)
	if window.visible:
		failures.append("M closes the world map")
	viewport.push_input(_typed("m"), true)
	if not window.visible:
		failures.append("M opens the world map")
	viewport.push_input(_key(KEY_ESCAPE, 0), true)
	if window.visible:
		failures.append("Esc closes the world map")
	viewport.push_input(_typed("m"), true)
	window.get_node(WINDOW + "Header/CloseButton").pressed.emit()
	if window.visible:
		failures.append("the close button closes the world map")
	viewport.push_input(_typed("m"), true)
	viewport.push_input(_click(Vector2(4, main.size.y - 4), true), true)
	viewport.push_input(_click(Vector2(4, main.size.y - 4), false), true)
	if window.visible:
		failures.append("a click outside closes the world map")
	return failures


## The Codex lines missing from what the window shows (Markdown marks aside).
func _missing_codex_lines(codex: String, shown: String) -> Array:
	var missing: Array = []
	for raw in codex.split("\n"):
		var line := raw.strip_edges().trim_prefix("## ").trim_prefix("- ").replace("**", "").strip_edges()
		if not line.is_empty() and not shown.contains(line):
			missing.append(line)
	return missing


func _codex_checks(main, content) -> Array:
	var failures: Array = []
	var window = main.get_node_or_null("WindowLayer/CodexWindow")
	if window == null or main.get("codex_window") != window:
		return ["the Codex window should be WindowLayer/CodexWindow (main.codex_window)"]
	var entry: Button = main.menu.get_node_or_null(ENTRIES + "CodexButton")
	if entry == null:
		return ["the menu needs a Codex entry (CodexButton)"]
	var order := []
	for name in ["SaveButton", "LoadButton", "Languages", "CodexButton", "AiSettingsButton", "CloseButton"]:
		order.append(main.menu.get_node(ENTRIES + name).get_index())
	var sorted := order.duplicate()
	sorted.sort()
	if order != sorted:
		failures.append("the menu lists Save, Load, Language, Codex, AI settings, Close")
	var viewport: Viewport = main.get_viewport()
	for lang in ["en", "fr"]:
		content.set_language(lang)
		if entry.text != Content.t_in("ui.codex", lang):
			failures.append("(%s) the menu entry says '%s'" % [lang, Content.t_in("ui.codex", lang)])
		_open_menu(main)
		entry.pressed.emit()
		if not window.visible or main.menu.visible:
			failures.append("(%s) Menu → Codex opens the Codex window and closes the menu" % lang)
			continue
		var text = window.get_node_or_null(WINDOW + "Body/Text")
		if not (text is RichTextLabel) or not text.scroll_active:
			return failures + ["the Codex window shows a read-only, scrolling Body/Text"]
		var title: Label = window.get_node(WINDOW + "Header/Title")
		if title.text != Content.t_in("ui.codex", lang):
			failures.append("(%s) the Codex window's title is '%s'" % [lang, Content.t_in("ui.codex", lang)])
		var missing := _missing_codex_lines(Content.codex_text(), text.get_parsed_text())
		if Content.codex_text().strip_edges().is_empty() or not missing.is_empty():
			failures.append("(%s) the Codex window shows the AI's Codex pages, missing %s" % [lang, str(missing.slice(0, 3))])
		viewport.push_input(_key(KEY_ESCAPE, 0), true)
		if window.visible:
			failures.append("(%s) Esc closes the Codex window" % lang)

	# A language switch while it is open; its close button.
	content.set_language("en")
	_open_menu(main)
	entry.pressed.emit()
	content.set_language("fr")
	var shown: String = window.get_node(WINDOW + "Body/Text").get_parsed_text()
	if not _missing_codex_lines(Content.codex_text(), shown).is_empty():
		failures.append("the open Codex window follows a language switch")
	content.set_language("en")
	window.get_node(WINDOW + "Header/CloseButton").pressed.emit()
	if window.visible:
		failures.append("the close button closes the Codex window")

	# The writer's files: CRLF line ends, and square brackets stay plain text.
	var bbcode: String = CodexWindow.to_bbcode("## Oda\r\n- **Id** : oda\r\n[b]not bold[/b]\r\n")
	if bbcode.contains("\r") or not bbcode.contains("[lb]b]not bold") or not bbcode.contains("[b]Id[/b]"):
		failures.append("the Codex shows CRLF files and square brackets as plain text: %s" % bbcode.c_escape())
	return failures


func _tracked_quest_checks(main, content) -> Array:
	var failures: Array = []
	var world_panel: Control = main.get_node("Layout/Split/WorldPanel")
	var label = world_panel.get_node_or_null("TrackedQuest")
	if not (label is Label) or main.get("tracked_quest") != label:
		return ["the world panel should hold the TrackedQuest label (main.tracked_quest)"]
	Game.new_game(12345)
	for lang in ["en", "fr"]:
		content.set_language(lang)
		var want := Content.t("ui.tracked_quest").format({
			"title": Content.t("quest.the_silent_mill.title"),
			"stage": Content.t("quest.the_silent_mill.stage0"),
		})
		if not label.visible or label.text != want:
			failures.append("(%s) the tracked quest shows '%s', got '%s'" % [lang, want, label.text])
	content.set_language("en")
	layout(main)
	var rect: Rect2 = label.get_global_rect()
	var panel_rect := world_panel.get_global_rect()
	if rect.position.x > panel_rect.position.x + 24.0 or rect.position.y > panel_rect.position.y + 24.0 or not panel_rect.encloses(rect):
		failures.append("the tracked quest sits at the top left of the world panel: %s in %s" % [rect, panel_rect])
	if rect.intersects(main.minimap.get_global_rect()):
		failures.append("the tracked quest doesn't cover the minimap")
	if label.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		failures.append("the tracked quest does nothing when clicked (the click goes to the world)")

	# The stage moves on through core; a finished quest hides the label.
	Game.apply_turn({"quest_updates": [{"id": "the_silent_mill", "stage": 1}]}, [])
	if not label.text.ends_with(Content.t("quest.the_silent_mill.stage1")):
		failures.append("the tracked quest follows the quest's stage, got '%s'" % label.text)
	Game.apply_turn({"quest_updates": [{"id": "the_silent_mill", "stage": 2, "done": true}]}, [])
	if label.visible:
		failures.append("the tracked quest hides when no quest is running")
	Game.state["quests"] = {}
	Game.state_changed.emit(Game.state)
	if label.visible:
		failures.append("the tracked quest hides with no quest at all")
	# Hand-edited saves: broken entries are skipped.
	Game.state["quests"] = {"the_silent_mill": "broken", "unknown_quest": {"stage": "x"}}
	Game.state_changed.emit(Game.state)
	if label.visible:
		failures.append("broken quest entries show nothing")
	Game.new_game(12345)
	if not label.visible:
		failures.append("a new game tracks its quest again")
	return failures


func _key(keycode: Key, unicode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.unicode = unicode
	event.pressed = true
	return event


func _typed(letter: String) -> InputEventKey:
	var codes := {"b": KEY_B, "m": KEY_M, "1": KEY_1}
	return _key(codes[letter], letter.unicode_at(0))


func _click(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	return event
