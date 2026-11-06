#!/usr/bin/env bash
# Runs detached; everything is logged to /opt/setup.log from inside the script
# because the caller shell mangles "2>&1" on the command line.
exec >/opt/setup.log 2>&1
set -euo pipefail
cd /

echo "=== setup start $(date -u) pid=$$ ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq || true
apt-get install -y -qq openjdk-17-jdk-headless unzip zip curl tar build-essential pkg-config || true
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
echo "[sdk] sdkmanager $(sdkmanager --version 2>/dev/null | tail -1)"

echo "[sdk] installing platform-tools / build-tools / ndk"
sdkmanager "platform-tools" "build-tools;36.0.0" "ndk;27.2.12479018" || echo "[sdk] stable set had failures"
echo "[sdk] installing platform 37"
sdkmanager "platforms;android-37" || {
  echo "[sdk] android-37 not on stable channel, trying canary"
  sdkmanager --channel=3 "platforms;android-37" || echo "[sdk] ANDROID-37 FAILED"
}
echo "[sdk] platforms: $(ls "$ANDROID_HOME/platforms" 2>/dev/null | tr '\n' ' ')"
echo "[sdk] build-tools: $(ls "$ANDROID_HOME/build-tools" 2>/dev/null | tr '\n' ' ')"
echo "[sdk] ndk: $(ls "$ANDROID_HOME/ndk" 2>/dev/null | tr '\n' ' ')"

# ---------- Rust ----------
if [ ! -x /opt/cargo/bin/cargo ]; then
  echo "[rust] installing rustup"
  curl -sSf https://sh.rustup.rs -o /tmp/rustup.sh
  RUSTUP_HOME=/opt/rustup CARGO_HOME=/opt/cargo sh /tmp/rustup.sh -y --no-modify-path --profile minimal || echo "[rust] rustup FAILED"
fi
export RUSTUP_HOME=/opt/rustup CARGO_HOME=/opt/cargo
export PATH=/opt/cargo/bin:$PATH
echo "[rust] $(cargo --version 2>&1) / $(rustc --version 2>&1)"
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android || echo "[rust] target add FAILED"
if ! command -v cargo-ndk >/dev/null 2>&1; then
  echo "[rust] installing cargo-ndk"
  cargo install cargo-ndk --locked || echo "[rust] cargo-ndk FAILED"
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
echo "java_home=$JAVA_HOME"
df -h /opt | tail -1
echo SETUP_COMPLETE
