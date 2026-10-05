#!/bin/bash
# Build BiglyBT and launch the SWT UI on Apple Silicon.
# Cocoa SWT must start on the first thread, so this script passes
# -XstartOnFirstThread. It does not build an Install4j .app bundle.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ "$(uname -s)" != "Darwin" ]; then
	echo "This script is for macOS. uname reported $(uname -s)." >&2
	exit 1
fi

if ! command -v java >/dev/null 2>&1; then
	echo "Java is not on PATH. Install Temurin JDK 17 or 21 and retry." >&2
	exit 1
fi

JAVA_SPEC="$(java -XshowSettings:properties -version 2>&1 | awk -F= '/java.specification.version/ {gsub(/ /,"",$2); print $2; exit}')"
JAVA_MAJOR="${JAVA_SPEC%%.*}"
if [ "$JAVA_MAJOR" = "1" ]; then
	JAVA_MAJOR="${JAVA_SPEC#1.}"
fi
if [ -z "$JAVA_MAJOR" ] || [ "$JAVA_MAJOR" -lt 17 ]; then
	echo "JDK 17 or newer is required (found specification ${JAVA_SPEC:-unknown})." >&2
	echo "SWT ${SWT_NOTE:-3.130.0} is Java 17 bytecode. Temurin 21 is the version to install." >&2
	exit 1
fi

ARCH="$(uname -m)"
if [ "$ARCH" != "arm64" ] && [ "$ARCH" != "aarch64" ]; then
	echo "This build is Apple Silicon only. uname -m reported ${ARCH}." >&2
	exit 1
fi

echo "Building with Maven profile mac-aarch64 (JDK ${JAVA_SPEC})"
./mvnw -DskipTests -Pmac-aarch64 package

STAGE="$ROOT/uis/target/macos"
RUN_DIR="$ROOT/dist/macos"
mkdir -p "$RUN_DIR/dll"
cp -f "$STAGE/BiglyBT.jar" "$STAGE/swt.jar" "$STAGE/commons-cli.jar" "$RUN_DIR/"

if [ -f "$ROOT/core/lib/libOSXAccess/libOSXAccess_10.5.jnilib" ]; then
	cp -f "$ROOT/core/lib/libOSXAccess/libOSXAccess_10.5.jnilib" "$RUN_DIR/dll/"
elif command -v make >/dev/null 2>&1 && [ -d /Applications/Xcode.app ]; then
	echo "Building optional libOSXAccess (Finder integration). The UI still runs if this fails."
	if make -C "$ROOT/core/lib/libOSXAccess"; then
		cp -f "$ROOT/core/lib/libOSXAccess/libOSXAccess_10.5.jnilib" "$RUN_DIR/dll/"
	else
		echo "libOSXAccess was not built. Continuing without it."
	fi
else
	echo "Skipping libOSXAccess (Xcode not installed). Drive detection and a few Mac integrations stay off."
fi

CONFIG_DIR="${BIGLYBT_CONFIG_DIR:-$HOME/Library/Application Support/BiglyBT-dev}"
mkdir -p "$CONFIG_DIR"

echo "Launching from $RUN_DIR"
echo "Config directory: $CONFIG_DIR"
cd "$RUN_DIR"
exec java \
	-XstartOnFirstThread \
	--add-opens java.base/java.net=ALL-UNNAMED \
	-Xmx1g \
	-Dazureus.install.path="$RUN_DIR" \
	-Dazureus.config.path="$CONFIG_DIR" \
	-jar BiglyBT.jar \
	"$@"
