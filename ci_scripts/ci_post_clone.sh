#!/bin/sh
# Xcode Cloud runs this right after cloning the repository, before it builds.
# Shelfie.xcodeproj isn't committed (XcodeGen generates it from project.yml), so make it here.
# This file must be executable: git update-index --chmod=+x ci_scripts/ci_post_clone.sh
set -e

brew install xcodegen

cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate

echo "Generated Shelfie.xcodeproj from project.yml"
