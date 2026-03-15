#!/usr/bin/env bash
# release.sh — Build, sign with Sparkle EdDSA, tag, and publish a new Sponge release.
#
# Usage: ./scripts/release.sh 1.3
#
# Prerequisites:
#   1. SPARKLE_PRIVATE_KEY env var set (base64 key from Sparkle's generate_keys tool)
#   2. `gh` CLI authenticated
#   3. Sparkle's `sign_update` tool in PATH (see below)
#
# To get sign_update: after adding Sparkle via Xcode SPM, it lives at:
#   ~/Library/Developer/Xcode/DerivedData/Sponge-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update
# Or download from https://github.com/sparkle-project/Sparkle/releases and add to /usr/local/bin/

set -e

VERSION="${1:?Usage: $0 <version>  e.g.  $0 1.3}"
TAG="v${VERSION}"
APP_NAME="Sponge"
ZIP_NAME="${APP_NAME}-v${VERSION}.zip"
BUILD_DIR="/Users/danielwait/Library/Developer/Xcode/DerivedData/Sponge-abyqkaxkuzaomxcgonignswyrnps/Build/Products/Debug"
APPCAST="docs/appcast.xml"

echo "==> Building ${APP_NAME} ${VERSION}..."
cd "$(dirname "$0")/.."

# Update version numbers in Xcode project
BUILD_NUMBER=$(git rev-list --count HEAD)
sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = ${VERSION}/" Sponge/Sponge.xcodeproj/project.pbxproj
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = ${BUILD_NUMBER}/" Sponge/Sponge.xcodeproj/project.pbxproj

cd Sponge && xcodebuild -scheme Sponge -configuration Debug 2>&1 | grep -E "error:|BUILD" | tail -5
cd ..

echo "==> Re-signing Sparkle XPC services with your identity..."
SIGN_IDENTITY="DD90759FF297D19E2CCA53A2622125801ECDB45C"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
SPARKLE_FW="${APP_PATH}/Contents/Frameworks/Sparkle.framework/Versions/B"
# Remove app-level XPC services if present (non-sandboxed apps must only have them in the framework)
rm -rf "${APP_PATH}/Contents/XPCServices"
codesign --force --sign "${SIGN_IDENTITY}" \
    "${SPARKLE_FW}/XPCServices/Installer.xpc" \
    "${SPARKLE_FW}/XPCServices/Downloader.xpc"
codesign --force --deep --sign "${SIGN_IDENTITY}" \
    "${SPARKLE_FW}/Updater.app"
# Re-sign the framework and app bundle after modifying contents
codesign --force --sign "${SIGN_IDENTITY}" "${SPARKLE_FW}/../.."
codesign --force --sign "${SIGN_IDENTITY}" "${APP_PATH}"

echo "==> Creating zip..."
cd "${BUILD_DIR}"
ditto -c -k --keepParent "${APP_NAME}.app" "/tmp/${ZIP_NAME}"
cd -

ZIP_PATH="/tmp/${ZIP_NAME}"
ZIP_SIZE=$(stat -f%z "${ZIP_PATH}")

echo "==> Signing with Sparkle EdDSA..."
# sign_update outputs: sparkle:edSignature="..." length="..."
SIGNATURE=$(sign_update "${ZIP_PATH}" --ed-key-file <(echo "${SPARKLE_PRIVATE_KEY}") 2>/dev/null \
    | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"//')

if [ -z "${SIGNATURE}" ]; then
    echo "ERROR: sign_update failed. Is SPARKLE_PRIVATE_KEY set and sign_update in PATH?"
    exit 1
fi

echo "Signature: ${SIGNATURE}"

echo "==> Updating appcast.xml..."
RELEASE_URL="https://github.com/danielwaitworksllc/sponge/releases/download/${TAG}/${ZIP_NAME}"
TODAY=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")
BUILD_NUMBER=$(git rev-list --count HEAD)

# Write new item to temp file (avoids awk multiline issues)
cat > /tmp/new_appcast_item.xml <<XMLEOF
        <item>
            <title>Version ${VERSION}</title>
            <pubDate>${TODAY}</pubDate>
            <sparkle:version>${BUILD_NUMBER}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <enclosure
                url="${RELEASE_URL}"
                sparkle:edSignature="${SIGNATURE}"
                length="${ZIP_SIZE}"
                type="application/octet-stream"
            />
        </item>
XMLEOF

# Insert new item before the first <item> tag
python3 -c "
content = open('${APPCAST}').read()
new_item = open('/tmp/new_appcast_item.xml').read()
marker = '<item>'
idx = content.find(marker)
result = content[:idx] + new_item + '\n' + content[idx:]
open('${APPCAST}', 'w').write(result)
"

echo "==> Committing appcast + tagging..."
git add "${APPCAST}"
git commit -m "Release ${VERSION} — update appcast.xml"
git tag "${TAG}"

echo "==> Pushing..."
git push origin main
git push origin "${TAG}"

echo "==> Creating GitHub release..."
gh release create "${TAG}" "${ZIP_PATH}" \
    --title "Sponge v${VERSION}" \
    --notes "## What's new
See [CHANGELOG.md](https://github.com/danielwaitworksllc/sponge/blob/main/CHANGELOG.md) for details.

---

## Install (first time)
1. Download **Sponge-v${VERSION}.zip** above
2. Double-click to unzip → you'll get **Sponge.app**
3. Open Terminal (⌘ Space → type Terminal → Enter) and run:
\`\`\`
xattr -cr ~/Downloads/Sponge.app
\`\`\`
4. Double-click **Sponge.app** to launch — the app walks you through setup on first run

## Already installed?
No action needed — the app updates itself automatically.

## Requirements
- macOS 26 (Tahoe) or later
- Free Gemini API key for AI notes (optional — the app guides you through it on first launch)"

echo ""
echo "✓ Released ${TAG}"
echo "  Appcast: https://danielwaitworksllc.github.io/sponge/appcast.xml"
echo "  Users will be notified automatically on next app launch."
