#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/idom-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
swiftc -module-cache-path "$check_dir/cache" iDom/Core/PersonalData.swift Tests/CoreChecks.swift -o "$check_dir/checks"
"$check_dir/checks"
