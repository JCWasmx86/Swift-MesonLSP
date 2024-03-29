#!/usr/bin/env bash
meson setup _release --buildtype release -Db_lto=true
ninja -C _release || exit 1
./_release/tests/libcxathrow/cxathrowtest
cp _release/src/mesonlsp mesonlsp
rm -rf _release
meson setup _build --buildtype debug
ninja -C _build || ninja -C _build -j1 || exit 1
ninja -C _build test || ninja -C _build test -j1 || exit 1
./_build/tests/libcxathrow/cxathrowtest
cp _build/src/mesonlsp mesonlsp.debug
zip -9 "$1".zip mesonlsp.debug mesonlsp
sudo cp "$1".zip / || true
cp "$1".zip / || true
