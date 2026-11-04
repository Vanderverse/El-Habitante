#!/usr/bin/env bash
# Ejecutar desde cualquier directorio, con Flutter ya disponible en PATH.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
if [[ -f pubspec.lock ]]; then
  flutter pub get --enforce-lockfile
else
  flutter pub get
fi
flutter analyze
flutter test
flutter build apk --debug
