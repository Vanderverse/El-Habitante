# Validación del prototipo inicial · 4 de noviembre de 2026

## Comprobaciones realizadas

| Comprobación | Resultado |
| --- | --- |
| Lectura de `Vanderverse/El-Habitante`, rama `main` | Correcta, commit inicial `df37b8dadbb04f5a5915198d4d40a9ef334fcae1` con README |
| SDK Flutter, fuente oficial | Rama estable descargada; revisión `c197ca5199e9ee5661e865596c9c07294dfab51c`, etiqueta `3.47.9` |
| OpenJDK 21.0.13+9 | SHA-256 oficial verificado; `java` y `javac` ejecutados |
| Android Command-line Tools | Checksum oficial verificado |
| Android SDK 36, Build-Tools 36.0.0, Platform-Tools y NDK 28.2.13676358 | Instalación terminada; `adb version` ejecutado y archivos del SDK presentes |
| Scripts Bash | Sintaxis comprobada con `bash -n` |
| Recursos y manifiestos Android | XML parseado; manifiesto principal sin permisos; sin micrófono; backup desactivado |

## Bloqueo que impide validar la aplicación

`flutter --version` intenta descargar Dart desde el servidor oficial
`storage.googleapis.com` y falla con `CONNECT tunnel failed, response 403`.
La instancia aún informa revisión de red `1`, sin ese dominio permitido.

Se guardó la adición de `storage.googleapis.com` en el borrador de configuración,
conservando el preset existente. Hace falta revisar y guardar la configuración
del entorno y publicarla para aplicar el cambio. No se usaron rutas alternativas
para eludir la política ni se desactivó TLS.

Todavía no se pudieron ejecutar `flutter pub get`, `flutter analyze`,
`flutter test`, el formateador Dart ni la compilación del APK. Las pruebas están
implementadas, pero **ninguna se declara aprobada**. Tampoco se probó la app en un
emulador o teléfono. La integridad de las herramientas instaladas y las
comprobaciones XML no demuestran que la aplicación compile o funcione.

## Reanudar

Después de aplicar el permiso de red, desde `/workspace/El-Habitante`:

```sh
bash tool/setup_cloud.sh
source tool/cloud_env.sh
dart format lib test
bash tool/verify.sh
flutter doctor -v
flutter devices
```

Conservar el `pubspec.lock` generado y registrar aquí los resultados reales.
Si hay un dispositivo Android conectado, ejecutar además `flutter run -d ID` y
la prueba manual del README. Publicar el entorno guarda una instantánea; no
equivale a haber ejecutado estas comprobaciones en una tarea nueva.
