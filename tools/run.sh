#!/bin/bash
# usage: tools/run.sh build | tools/run.sh shot <scene> steps...
G="/c/Users/jitti/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe"
F='^\s*at:|WARNING: A surface|^Godot Engine|leaked|RID alloc|PagedAlloc|still in use|instance dependency|Ogg Vorbis|old surface format|^\s*$|^OpenGL API|backtrace|^\s*\[[0-9]+\]'
cd /d/GameLab5
if [ "$1" = build ]; then "$G" --headless --path . res://tools/build.tscn 2>&1 | grep -Ev "$F" | grep -v "^saved"; echo build done
else scene=$2; shift 2; "$G" --path . --rendering-driver opengl3 --resolution 1280x720 res://tools/shot.tscn -- --scene=$scene "$@" 2>&1 | grep -Ev "$F"; fi
