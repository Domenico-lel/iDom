#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/idom-whatsapp-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
swiftc -module-cache-path "$check_dir/cache" iDom/Messages/WhatsAppModels.swift Tests/WhatsAppChecks.swift -o "$check_dir/checks"
"$check_dir/checks"
