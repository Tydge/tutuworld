#!/bin/zsh
set -e
project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
godot_executable="${GODOT_BIN:-/Users/wangtaizhi/Desktop/Godot.app/Contents/MacOS/Godot}"
exec "$godot_executable" --path "$project_dir" --script res://tools/local_icefield_preview.gd -- --test --benchmark --warmup-test
