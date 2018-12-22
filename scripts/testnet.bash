#!/usr/bin/env bash

set -euo pipefail

declare -r DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
declare -r parent_dir="${DIR%/*}"
declare -r gparent_dir="${parent_dir%/*}"

. "$DIR/set_globals.bash"
. "$DIR/ncpus.bash"

# Config
declare -ri node="${node:-0}"
declare -r entry="${entry:-main}" # you may use main_profile here to enable profiling
declare -r node_addr="${node_addr:-127.0.0.1}"
# e.g.
# n=3 entry=main_profile BUILD_DIR="$PWD" ./scripts/multi.bash

# Install deps
"$DIR/docker/install_deps.bash"

# Use -tags="netgo multi" in bgo build below to build multu lachesis version for testing
declare args="-X github.com/Fantom-foundation/go-lachesis/src/version.GitCommit=$(git rev-parse HEAD)"
if [ "$TARGET_OS" == "linux" ]; then
  args="$args -linkmode external -extldflags -static -s -w"
fi
env GOOS="$TARGET_OS" GOARCH=amd64 go build -tags="netgo" -ldflags "$args" -o lachesis_"$TARGET_OS" "$parent_dir/cmd/lachesis/$entry.go" || exit 1

# Create peers.json and lachesis_data_dir if needed
if [ ! -d "$DATAL_DIR/lachesis_data_dir" ]; then
    echo "$DATAL_DIR/lachesis_data_dir is not found; can not run"
    exit 2
fi

GOMAXPROCS=$(($logicalCpuCount - 1)) "$BUILD_DIR/lachesis_$TARGET_OS" run --datadir "$DATAL_DIR/lachesis_data_dir/$node" --store --listen="$node_addr":12000 --log=warn --heartbeat=5s -p "$node_addr":9000 -s "$node_addr":9090 --syslog

