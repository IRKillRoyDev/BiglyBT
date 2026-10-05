#!/bin/bash
# Build BiglyBT and launch the SWT UI on Linux x86_64.
# Eclipse SWT 3.130.0 is Java 17 bytecode, so JDK 17 or newer is required.
# Cocoa-only flags such as -XstartOnFirstThread are not used here.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ "$(uname -s)" != "Linux" ]; then
	echo "This script is for Linux. uname reported $(uname -s)." >&2
	exit 1
fi

if ! command -v java >/dev/null 2>&1; then
	echo "Java is not on PATH. Install Temurin or OpenJDK 17 or 21 and retry." >&2
	exit 1
fi

JAVA_SPEC="$(java -XshowSettings:properties -version 2>&1 | awk -F= '/java.specification.version/ {gsub(/ /,"",$2); print $2; exit}')"
JAVA_MAJOR="${JAVA_SPEC%%.*}"
if [ "$JAVA_MAJOR" = "1" ]; then
	JAVA_MAJOR="${JAVA_SPEC#1.}"
fi
if [ -z "$JAVA_MAJOR" ] || [ "$JAVA_MAJOR" -lt 17 ]; then
	echo "JDK 17 or newer is required (found specification ${JAVA_SPEC:-unknown})." >&2
	echo "SWT 3.130.0 is Java 17 bytecode." >&2
	exit 1
fi

ARCH="$(uname -m)"
if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "amd64" ]; then
	echo "This build is Linux x86_64 only. uname -m reported ${ARCH}." >&2
	exit 1
fi

echo "Building with Maven profile linux-x86_64 (JDK ${JAVA_SPEC})"
./mvnw -B -DskipTests -Plinux-x86_64 package

STAGE="$ROOT/uis/target/linux"
RUN_DIR="$ROOT/dist/linux"
mkdir -p "$RUN_DIR"
cp -f "$STAGE/BiglyBT.jar" "$STAGE/swt.jar" "$STAGE/commons-cli.jar" "$RUN_DIR/"

CONFIG_DIR="${BIGLYBT_CONFIG_DIR:-$HOME/.config/BiglyBT-dev}"
mkdir -p "$CONFIG_DIR"

echo "Launching from $RUN_DIR"
echo "Config directory: $CONFIG_DIR"
cd "$RUN_DIR"
exec java \
	--add-opens java.base/java.net=ALL-UNNAMED \
	-Xmx1g \
	-Dazureus.install.path="$RUN_DIR" \
	-Dazureus.config.path="$CONFIG_DIR" \
	-jar BiglyBT.jar \
	"$@"
