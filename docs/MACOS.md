# Run BiglyBT on Apple Silicon

This builds a local SWT UI from this fork. It is not the Install4j `.app` from biglybt.com. There is no signed application bundle. The window and the rest of the Java client are what this path runs.

This path is Apple Silicon only (`arm64`).

Tested build: Maven package against Eclipse SWT `3.130.0` Cocoa `aarch64` (natives `4969r18`) on JDK 21. That SWT jar is Java 17 bytecode.

## Prerequisites

1. An Apple Silicon Mac. `uname -m` must be `arm64`.
2. Temurin JDK 21 (JDK 17 is the minimum). Check with `java -version`.
3. Xcode is optional. It is only used to compile `libOSXAccess_10.5.jnilib` for arm64. Without that library the UI still starts. Finder integration, some file icons, and “prevent sleep” stay unavailable.

No SWT jar is stored in git. Maven downloads it from Maven Central.

## Build and launch

From the repository root:

```bash
chmod +x scripts/run-macos.sh
./scripts/run-macos.sh
```

The script:

1. Runs `./mvnw -DskipTests -Pmac-aarch64 package`.
2. Copies `BiglyBT.jar`, `swt.jar`, and `commons-cli.jar` into `dist/macos/`. The jar manifest loads SWT from the next-door `swt.jar`. Cocoa SWT will not start unless the JVM is given `-XstartOnFirstThread`. The launch also opens `java.base/java.net` so the DNS hook can install.
3. Starts the UI with a separate config directory so this build does not write into an installed BiglyBT profile.

Config directory: `~/Library/Application Support/BiglyBT-dev`

Override it with:

```bash
BIGLYBT_CONFIG_DIR="$HOME/biglybt-dev-config" ./scripts/run-macos.sh
```

Extra arguments are passed through to `com.biglybt.ui.Main`.

## Build only

On an Apple Silicon Mac the `mac-aarch64` profile turns on by itself:

```bash
./mvnw -DskipTests package
```

Staged files land in `uis/target/macos/`.

To launch that directory yourself:

```bash
cd uis/target/macos
java -XstartOnFirstThread \
  --add-opens java.base/java.net=ALL-UNNAMED \
  -Xmx1g \
  -Dazureus.install.path="$PWD" \
  -Dazureus.config.path="$HOME/Library/Application Support/BiglyBT-dev" \
  -jar BiglyBT.jar
```

`-XstartOnFirstThread` is required. Without it SWT aborts before opening a window.

`--add-opens java.base/java.net=ALL-UNNAMED` lets the client install its tracker DNS hook. On JDK 17 and newer that hook touches a private `InetAddress` field. Without the flag, startup prints `InaccessibleObjectException` and continues with the JDK resolver.

## Optional native library

```bash
make -C core/lib/libOSXAccess
mkdir -p dist/macos/dll
cp core/lib/libOSXAccess/libOSXAccess_10.5.jnilib dist/macos/dll/
```

The makefile builds an arm64 library and needs Xcode. `scripts/run-macos.sh` runs this when Xcode is installed.

## What is still missing

- A `BiglyBT.app` bundle. Upstream builds that with Install4j, and that project is not in this repository.
- Code signing and notarization. Launching via `java -jar` does not need them.
- `libOSXAccess`, until the native library is built.
