#!/usr/bin/env bash
# Smoke test inside the image (needs network for the Go download):
#   docker run --rm --entrypoint bash -v "$PWD/test:/test:ro" IMAGE /test/smoke.sh
set -euo pipefail

echo "== tools"
for t in bash git gh jq yq curl gcc make tar zip unzip xz zstd file shellcheck python3 docker sudo; do
  command -v "$t" >/dev/null || { echo "missing: $t"; exit 1; }
done
yq --version
gh --version | head -1
date --version | head -1 # GNU date
sudo -n true

echo "== entrypoint refuses to start without RUNNER_URL"
if out=$(/usr/local/bin/entrypoint.sh 2>&1); then echo "unexpected success"; exit 1; fi
grep -q RUNNER_URL <<<"$out"

echo "== Go in the tool cache like actions/setup-go, cgo build and race test"
arch=$(dpkg --print-architecture)
v=$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1)
dir=$RUNNER_TOOL_CACHE/go/${v#go}/$arch
mkdir -p "$dir"
curl -fsSL "https://go.dev/dl/$v.linux-$arch.tar.gz" | tar -xz -C "$dir" --strip-components=1
export PATH=$dir/bin:$PATH
work=$(mktemp -d)
cd "$work"
go mod init smoke >/dev/null 2>&1
cat >smoke_test.go <<'EOF'
package smoke

import (
	"sync"
	"testing"
)

func TestParallel(t *testing.T) {
	var mu sync.Mutex
	var wg sync.WaitGroup
	n := 0
	for range 8 {
		wg.Add(1)
		go func() { defer wg.Done(); mu.Lock(); n++; mu.Unlock() }()
	}
	wg.Wait()
	if n != 8 {
		t.Fatal(n)
	}
}
EOF
go version
go test -race ./...
echo "== OK"
