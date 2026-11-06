#!/usr/bin/env bash
set -euo pipefail
source /opt/strata-env.sh

WORK="${WORK:-/opt/strata}"
cd "$WORK"
echo "=== build start $(date -u) in $WORK ==="

if [ "${CLEAN:-0}" = "1" ]; then
  git reset --hard HEAD
  git clean -fdx -q
fi

export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$(ls "$ANDROID_HOME/ndk" | sort -V | tail -1)"
echo "[native] NDK=$ANDROID_NDK_HOME"

if [ ! -f app/src/main/jniLibs/arm64-v8a/libpdfium.so ]; then
  echo "[native] fetching pdfium"
  bash native/fetch-pdfium.sh
fi

echo "[native] cargo ndk build (this is the slow part)"
bash native/build.sh

if [ ! -f release.jks ]; then
  echo "[sign] generating keystore"
  keytool -genkeypair -v -keystore release.jks -alias strata-lszyk -keyalg RSA -keysize 4096 \
    -validity 10000 -storepass strata20261106 -keypass strata20261106 \
    -dname "CN=Strata Personal Build, OU=Personal, O=lszyk26, L=CN, ST=CN, C=CN" >/dev/null 2>&1
fi
printf 'storeFile=release.jks\nstorePassword=strata20261106\nkeyAlias=strata-lszyk\nkeyPassword=strata20261106\n' > keystore.properties
echo "sdk.dir=$ANDROID_HOME" > local.properties

echo "[gradle] version: $(grep '^strata.versionName=' gradle.properties) / $(grep '^strata.versionCode=' gradle.properties)"
./gradlew --no-daemon --stacktrace :app:assembleRelease -Pstrata.splitApks=true 2>&1 | tail -60

echo "=== artifacts ==="
ls -la app/build/outputs/apk/release/ || true
mkdir -p /opt/dist
cp app/build/outputs/apk/release/*.apk /opt/dist/ 2>/dev/null || true
ls -la /opt/dist || true
echo "=== build done $(date -u) ==="
