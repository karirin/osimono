#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

if [[ "${1:-}" == "--inside-emulator" ]]; then
  node --test functions/test/community-profile.test.js functions/test/community-emulator.test.js
  if [[ "${COMMUNITY_RUN_IOS_TESTS:-0}" == "1" ]]; then
    node functions/test/prepare-swift-emulator.js
    verification_dir="$(mktemp -d /tmp/osimono-community-qa.XXXXXX)"
    if TEST_RUNNER_COMMUNITY_DATABASE_EMULATOR_TEST=1 xcodebuild test \
      -project osimono.xcodeproj -scheme osimono -configuration Debug \
      -destination "${COMMUNITY_TEST_DESTINATION:-platform=iOS Simulator,name=osimono Story QA}" \
      -derivedDataPath "${COMMUNITY_DERIVED_DATA:-/tmp/osimono-community-dd}" \
      -resultBundlePath "$verification_dir/Tests.xcresult" \
      -only-testing:osimonoTests/CommunityOshiTests \
      -only-testing:osimonoTests/CommunityOshiVisualTests \
      -only-testing:osimonoTests/CommunityOshiFirebaseTests \
      -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
      > "$verification_dir/xcodebuild.log" 2>&1; then
      printf 'iOS tests passed. Results: %s\n' "$verification_dir"
    else
      tail -60 "$verification_dir/xcodebuild.log"
      exit 1
    fi
  fi
  exit 0
fi

if ! java -version >/dev/null 2>&1 && [[ -x '/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java' ]]; then
  export PATH="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin:$PATH"
fi
firebase emulators:exec --only database,storage --project demo-community \
  --config functions/test/firebase.json 'bash scripts/test-community-oshis.sh --inside-emulator'
