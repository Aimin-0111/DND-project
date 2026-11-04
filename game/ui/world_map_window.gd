class_name WorldMapWindow
extends GameWindow
## The world map window (SPEC-main-screen, "Minimap and world map"): a click
## on the minimap or M opens it; M, Esc, its close button or a click outside
## closes it. It shows the whole world grid in the minimap's colours and fog,
## with the red frame on the hero's square. When the artist adds
## content/maps/world-painted.png (any size, the proportions of world.png), it
## is drawn under the fog instead of the flat colours. Read-only: clicking a
## square never travels; travel stays the DM's decision.

const PAINTED_PATH := "res://content/maps/world-painted.png"

var view: MapView
## The painted map, or null (then the flat colours show).
var painted: Texture2D


func _ready() -> void:
	super()
	painted = load_painted(PAINTED_PATH)
	view = MapView.new()
	view.name = "Map"
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.painted = painted
	body.add_child(view)
	Game.state_changed.connect(_on_state_changed)


## An imported image as a texture (imported as a texture or as an image),
## or null when there is none.
static func load_painted(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = load(path)
	if resource is Image:
		return ImageTexture.create_from_image(resource as Image)
	return resource as Texture2D


func _refresh() -> void:
	view.refresh(Game.world_map, Game.state)


func _on_state_changed(_state: Dictionary) -> void:
	if visible:
		_refresh()
