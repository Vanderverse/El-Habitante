#!/usr/bin/env bash
# Reproduce las herramientas en Linux x86_64 sin sudo ni modificaciones de fuentes.
set -euo pipefail
habitante_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$habitante_repo/tool/cloud_env.sh"
[[ "$(uname -sm)" == 'Linux x86_64' ]] || {
  echo 'Este instalador es para el entorno cloud Linux x86_64. Ver README para tu PC.' >&2
  exit 1
}
mkdir -p "$HABITANTE_TOOLCHAINS/downloads"

fetch_verified() {
  local url="$1" destination="$2" checksum="$3"
  if [[ ! -f "$destination" ]] || ! echo "$checksum  $destination" | sha256sum -c --status; then
    curl --fail --show-error --location --output "$destination.part" "$url"
    echo "$checksum  $destination.part" | sha256sum -c -
    mv "$destination.part" "$destination"
  fi
}

if [[ ! -x "$JAVA_HOME/bin/javac" ]]; then
  fetch_verified \
    'https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13%2B9/OpenJDK21U-jdk_x64_linux_hotspot_21.0.13_9.tar.gz' \
    "$HABITANTE_TOOLCHAINS/downloads/jdk.tar.gz" \
    'd7f5d5cf865a2902b70ff549b97586a7d3f234e016f041ab447ea740c7d66d1c'
  mkdir -p "$HABITANTE_TOOLCHAINS/java"
  tar -xzf "$HABITANTE_TOOLCHAINS/downloads/jdk.tar.gz" -C "$HABITANTE_TOOLCHAINS/java"
fi

if [[ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]]; then
  fetch_verified \
    'https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip' \
    "$HABITANTE_TOOLCHAINS/downloads/android-commandlinetools.zip" \
    '0877a1d048fe4a24efe2eff536ca4223f7adeb58648bb81909d33c446918cfa8'
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  unzip -q "$HABITANTE_TOOLCHAINS/downloads/android-commandlinetools.zip" -d "$ANDROID_HOME/cmdline-tools"
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
fi

habitante_flutter_revision=c197ca5199e9ee5661e865596c9c07294dfab51c
if [[ ! -d "$FLUTTER_ROOT" ]]; then
  git clone --depth 1 --branch 3.47.9 https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
fi
[[ "$(git -C "$FLUTTER_ROOT" rev-parse HEAD)" == "$habitante_flutter_revision" ]] || {
  echo 'El SDK Flutter existente tiene otra revisión. No se modificó; revisá la ruta.' >&2
  exit 1
}

# Aceptación de licencias para las herramientas necesarias en este entorno.
python3 -c 'print("y\n" * 100)' | sdkmanager --sdk_root="$ANDROID_HOME" \
  'platform-tools' 'platforms;android-36' 'build-tools;36.0.0' 'ndk;28.2.13676358'

flutter --version
flutter config --no-analytics --android-sdk "$ANDROID_HOME" --jdk-dir "$JAVA_HOME"
flutter precache --android
cd "$habitante_repo"
if [[ -f pubspec.lock ]]; then
  flutter pub get --enforce-lockfile
else
  flutter pub get
fi
