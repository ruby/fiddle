#!/bin/bash

set -eux

mkdir -p build
cd build

ruby /source/ext/fiddle/extconf.rb
make -j$(nproc)
/source/test/run.rb "$@"
