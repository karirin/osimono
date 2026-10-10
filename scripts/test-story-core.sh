#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
story_test_dir="$(mktemp -d "${TMPDIR:-/tmp}/osimono-story-core.XXXXXX")"
trap 'rm -rf "$story_test_dir"' EXIT
mkdir -p "$story_test_dir/Sources/osimono" "$story_test_dir/Tests/osimonoTests"
cp "$project_root/osimono/Story/StoryModels.swift" "$project_root/osimono/Story/StoryPrompt.swift" "$project_root/osimono/Story/StorySession.swift" "$story_test_dir/Sources/osimono/"
cp "$project_root/osimonoTests/StoryTests.swift" "$story_test_dir/Tests/osimonoTests/"
cat > "$story_test_dir/Package.swift" <<'EOF'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "StoryCore", platforms: [.macOS(.v13)], targets: [
    .target(name: "osimono"), .testTarget(name: "osimonoTests", dependencies: ["osimono"])
], swiftLanguageModes: [.v5])
EOF
swift test --package-path "$story_test_dir"
