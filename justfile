#!/usr/bin/env just --justfile

set shell := ["bash", "-c"]

default:
    @just --list

build:
    zig build

build-video:
    zig build -Dvideo=true

run-demo name:
    zig build run-{{ name }}

run-mouse-demo:
    zig build run-mouse_demo

run-win-demo:
    zig build run-win_demo

run-simple-game:
    zig build run-simple_game

clean:
    rm -rf zig-cache zig-out
