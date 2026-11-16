#!/usr/bin/env bash
# Builds the sideloadable Android APK (arm64 + armv7, landscape, touch).
# Needs: Godot 4.7.2 with its Android export templates, an Android SDK with
# build-tools and platform-tools, JDK 17+, and the project's signing keystore.
# Keep the same keystore for every build, or the tablet refuses the update.
#   ANDROID_SDK=/opt/android-sdk \
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/acorn-release.keystore \
#   GODOT_ANDROID_KEYSTORE_RELEASE_USER=acorn \
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=... \
#   tools/android/build_apk.sh [out.apk]
set -euo pipefail
cd "$(dirname "$0")/../.."
out="${1:-build/acorn-mathematics.apk}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?set the keystore path}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?set the keystore password}"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-acorn}"

# Godot reads the SDK and JDK paths from editor settings, not the environment.
sdk="${ANDROID_SDK:-${ANDROID_HOME:-/opt/android-sdk}}"
jdk="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"
ver="$(godot --version | cut -d. -f1-2)"
mkdir -p ~/.config/godot "$(dirname "$out")"
cat > ~/.config/godot/editor_settings-"$ver".tres <<TRES
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$sdk"
export/android/java_sdk_path = "$jdk"
TRES

godot --headless --path . --import </dev/null >/dev/null 2>&1 || true
godot --headless --path . --export-release Android "$out" </dev/null
"$sdk"/build-tools/*/apksigner verify "$out"
echo "built $out"
