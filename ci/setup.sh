#!/usr/bin/env bash
set -euo pipefail

echo "=== setup start $(date -u) ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1 || true
apt-get install -y -qq openjdk-17-jdk-headless unzip zip curl tar build-essential pkg-config >/dev/null 2>&1 || true
echo "[java] $(java -version 2>&1 | head -1)"

# ---------- Android SDK ----------
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
if [ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
  echo "[sdk] downloading cmdline-tools"
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  cd /tmp
  curl -fsSL -o cmdtools.zip "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
  rm -rf "$ANDROID_HOME/cmdline-tools/latest" "$ANDROID_HOME/cmdline-tools/cmdline-tools"
  unzip -q -o cmdtools.zip -d "$ANDROID_HOME/cmdline-tools"
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
fi
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
set +o pipefail
yes | sdkmanager --licenses >/dev/null 2>&1 || true
set -o pipefail
sdkmanager --version 2>/dev/null | tail -1

echo "[sdk] installing stable packages"
sdkmanager "platform-tools" "build-tools;36.0.0" "ndk;27.2.12479018" >/dev/null 2>&1 || echo "[sdk] some stable package failed"
sdkmanager "platforms;android-37" >/dev/null 2>&1 || {
  echo "[sdk] android-37 not on stable channel, trying canary"
  sdkmanager --channel=3 "platforms;android-37" >/dev/null 2>&1 || echo "[sdk] ANDROID-37 FAILED"
}
echo "[sdk] platforms:"; ls "$ANDROID_HOME/platforms" 2>/dev/null || true
echo "[sdk] build-tools:"; ls "$ANDROID_HOME/build-tools" 2>/dev/null || true
echo "[sdk] ndk:"; ls "$ANDROID_HOME/ndk" 2>/dev/null || true

# ---------- Rust ----------
if [ ! -x /opt/cargo/bin/cargo ]; then
  echo "[rust] installing rustup"
  curl -sSf https://sh.rustup.rs -o /tmp/rustup.sh
  RUSTUP_HOME=/opt/rustup CARGO_HOME=/opt/cargo sh /tmp/rustup.sh -y --no-modify-path --profile minimal >/dev/null
fi
export RUSTUP_HOME=/opt/rustup CARGO_HOME=/opt/cargo
export PATH=/opt/cargo/bin:$PATH
echo "[rust] $(cargo --version) / $(rustc --version)"
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android 2>&1 | tail -3 || true
if ! command -v cargo-ndk >/dev/null 2>&1; then
  echo "[rust] installing cargo-ndk"
  cargo install cargo-ndk --locked 2>&1 | tail -3
fi
echo "[rust] cargo-ndk: $(cargo ndk --version 2>&1 | head -1)"

# ---------- env file ----------
cat > /opt/strata-env.sh <<'ENVEOF'
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export RUSTUP_HOME=/opt/rustup
export CARGO_HOME=/opt/cargo
export PATH=/opt/cargo/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/usr/lib/jvm/java-17-openjdk-amd64/bin:$PATH
ENVEOF

source /opt/strata-env.sh
echo "=== setup done $(date -u) ==="
echo "java: $JAVA_HOME"
df -h /opt | tail -1
echo OK
