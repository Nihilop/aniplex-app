#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# release.sh — bump version, commit, tag, push
# Usage: ./release.sh <version>   e.g.  ./release.sh 1.2.0
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "❌ Usage: ./release.sh <version>  (e.g. 1.2.0)"
  exit 1
fi

# Validate semver-ish format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Version must be x.y.z — got: $VERSION"
  exit 1
fi

PUBSPEC="pubspec.yaml"
TAG="v$VERSION"

# ── 1. Bump pubspec.yaml version ─────────────────────────────────────────────
# Flutter build numbers: use the commit count as build number
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo "1")
NEW_VERSION="$VERSION+$BUILD_NUMBER"

echo "📝 Updating $PUBSPEC → version: $NEW_VERSION"
# Replace the version line (works on macOS + Linux with different sed flavours)
if sed --version 2>/dev/null | grep -q GNU; then
  sed -i "s/^version: .*/version: $NEW_VERSION/" "$PUBSPEC"
else
  # macOS BSD sed
  sed -i '' "s/^version: .*/version: $NEW_VERSION/" "$PUBSPEC"
fi

# ── 2. Commit the version bump ───────────────────────────────────────────────
echo "📦 Committing version bump..."
git add "$PUBSPEC"
git commit -m "chore: release $TAG"

# ── 3. Create annotated tag ──────────────────────────────────────────────────
echo "🏷️  Tagging $TAG..."
git tag -a "$TAG" -m "Release $TAG"

# ── 4. Push branch + tag ─────────────────────────────────────────────────────
BRANCH=$(git symbolic-ref --short HEAD)
echo "🚀 Pushing $BRANCH + $TAG..."
git push origin "$BRANCH"
git push origin "$TAG"

echo ""
echo "✅ Released $TAG — GitHub Actions will build the APK automatically."
echo "   Watch the run at: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/actions"
