"""Tests for the map checks in content_check.py (Python standard library only).

Usage:
    python3 tools/test_content_check.py

Each test copies game/content/ into a temporary folder, breaks one thing
(a pixel, a size, a marker, a table row) and checks that the content check
reports it with the right file and position.
"""

from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

import content_check
from pngio import read_png, write_png

CONTENT = content_check.DEFAULT_CONTENT


class MapCheckTest(unittest.TestCase):
    def setUp(self) -> None:
        self.folder = Path(tempfile.mkdtemp())
        self.content = self.folder / "content"
        shutil.copytree(CONTENT, self.content, ignore=shutil.ignore_patterns("*.import"))

    def tearDown(self) -> None:
        shutil.rmtree(self.folder)

    def run_check(self) -> tuple[list[str], list[str]]:
        problems: list[str] = []
        warnings: list[str] = []
        keys = content_check.check_strings(self.content, ["fr", "en"], problems)
        content_check.check_maps(self.content, keys, problems, warnings)
        return problems, warnings

    def paint(self, relative: str, pixels: dict[tuple[int, int], tuple[int, int, int]]) -> None:
        path = self.content / relative
        width, height, rows = read_png(path)
        for (x, y), colour in pixels.items():
            rows[y][x] = colour + (255,)
        write_png(path, width, height, rows, alpha=False)

    def edit(self, relative: str, old: str, new: str) -> None:
        path = self.content / relative
        text = path.read_text(encoding="utf-8")
        self.assertIn(old, text)
        path.write_text(text.replace(old, new), encoding="utf-8")

    def assert_reported(self, messages: list[str], *parts: str) -> None:
        for message in messages:
            if all(part in message for part in parts):
                return
        self.fail(f"no message with {parts} in {messages}")

    def test_real_content_passes(self) -> None:
        problems, warnings = self.run_check()
        self.assertEqual(problems, [])
        self.assertEqual(warnings, [])

    def test_unknown_colour_in_world_map(self) -> None:
        self.paint("maps/world.png", {(3, 5): (0x12, 0x34, 0x56)})
        problems, _ = self.run_check()
        self.assert_reported(problems, "world.png", "unknown colour #123456 at (3, 5)")

    def test_unknown_colour_in_square(self) -> None:
        self.paint("maps/squares/mill-road.png", {(10, 12): (0xff, 0x00, 0x00)})
        problems, _ = self.run_check()
        self.assert_reported(problems, "mill-road.png", "unknown colour #ff0000 at (10, 12)")

    def test_many_unknown_colours_are_counted(self) -> None:
        self.paint("maps/world.png", {(x, 47): (1, 2, 3) for x in range(30)})
        problems, _ = self.run_check()
        self.assertEqual(sum("unknown colour #" in problem for problem in problems), 20)
        self.assert_reported(problems, "world.png", "and 10 more pixels")

    def test_wrong_square_size(self) -> None:
        write_png(self.content / "maps/squares/mill-road.png", 32, 32, [[(76, 154, 60)] * 32] * 32, alpha=False)
        problems, _ = self.run_check()
        self.assert_reported(problems, "mill-road.png", "32 x 32", "must be 64 x 64")

    def test_marker_outside_its_square(self) -> None:
        self.edit("data/locations.csv", "mill_road,sq_24_24,16,31", "mill_road,sq_24_24,70,31")
        problems, _ = self.run_check()
        self.assert_reported(problems, "locations.csv:2", "'mill_road'", "outside its square")

    def test_marker_on_blocked_tile(self) -> None:
        self.edit("data/locations.csv", "mill_road,sq_24_24,16,31", "mill_road,sq_24_24,45,10")
        problems, _ = self.run_check()
        self.assert_reported(problems, "locations.csv:2", "(45, 10)", "blocked tile (water)")

    def test_marker_in_a_square_that_is_not_hand_made(self) -> None:
        self.edit("data/locations.csv", "mill_road,sq_24_24,16,31", "mill_road,sq_3_3,16,31")
        problems, _ = self.run_check()
        self.assert_reported(problems, "locations.csv:2", "'sq_3_3'", "not a hand-made square")

    def test_place_without_square_is_a_warning(self) -> None:
        self.edit("data/locations.csv", "mill_road,sq_24_24,16,31", "mill_road,,,")
        problems, warnings = self.run_check()
        self.assertEqual(problems, [])
        self.assert_reported(warnings, "'mill_road'", "never reach it")

    def test_hand_made_square_off_the_world_map(self) -> None:
        self.edit("maps/squares.csv", "mill-road.png,24,24,road", "mill-road.png,60,24,road")
        problems, _ = self.run_check()
        self.assert_reported(problems, "squares.csv:2", "off the world map (48 x 48)")
        self.assert_reported(problems, "world.png", "(24, 24) is magenta")

    def test_hand_made_pixel_not_magenta_is_a_warning(self) -> None:
        self.paint("maps/world.png", {(24, 24): (0xe8, 0xc2, 0x7a)})
        problems, warnings = self.run_check()
        self.assertEqual(problems, [])
        self.assert_reported(warnings, "squares.csv:2", "magenta")

    def test_exit_facing_a_square_the_hero_cannot_enter(self) -> None:
        self.paint("maps/world.png", {(24, 23): (0x3a, 0x7b, 0xd5)})
        problems, warnings = self.run_check()
        self.assertEqual(problems, [])
        self.assert_reported(warnings, "mill-road.png", "4 exit tile(s) on the north edge", "(24, 23) (lake)")

    def test_obstacle_marked_walkable(self) -> None:
        self.edit("maps/tiles.csv", "tree,#1d4d24,false,obstacle,3", "tree,#1d4d24,true,obstacle,3")
        problems, _ = self.run_check()
        self.assert_reported(problems, "tiles.csv:5", "obstacle", "walkable must be false")

    def test_tileset_index_outside_the_tileset(self) -> None:
        self.edit("maps/tiles.csv", "wheel,#c9a227,false,obstacle,14", "wheel,#c9a227,false,obstacle,40")
        problems, _ = self.run_check()
        self.assert_reported(problems, "tiles.csv", "tileset_index 40 is outside the tileset")

    def test_generator_tile_missing(self) -> None:
        self.edit("maps/tiles.csv", "reeds,#b5b84a,false,obstacle,13\n", "")
        problems, _ = self.run_check()
        self.assert_reported(problems, "tiles.csv", "needs a tile with id 'reeds'")

    def test_kind_without_name_and_without_recipe(self) -> None:
        self.edit("maps/kinds.csv", "mountain,#7a7a7a,false\n", "mountain,#7a7a7a,false\ndesert,#e0c070,true\n")
        problems, warnings = self.run_check()
        self.assert_reported(problems, "kinds.csv:9", "kind.desert.name")
        self.assert_reported(warnings, "kinds.csv:9", "no recipe for 'desert'")

    def test_duplicate_colour(self) -> None:
        self.edit("maps/kinds.csv", "hills,#b08a4f,true", "hills,#8fd16a,true")
        problems, _ = self.run_check()
        self.assert_reported(problems, "kinds.csv:4", "#8fd16a is already used by 'meadow'")


if __name__ == "__main__":
    unittest.main()
