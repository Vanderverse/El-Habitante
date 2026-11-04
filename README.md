# El Habitante · prototipo 0.1

## Versión 0.2 (vista previa Android)

La rama `feat/el-habitante-v0.2` incluye expresiones y reacciones animadas,
una primera conversación de texto **sin IA ni Internet**, intereses aprendidos
mediante conteos por tema y la segunda señal del misterio.

El usuario puede hablar sobre juegos, música, espacio, naturaleza, saludos y
el misterio de la habitación. Las respuestas son reglas locales: todavía no se
comprende lenguaje libre. Se descarta el mensaje introducido, y solamente se
guardan una categoría, un recuerdo genérico y la respuesta generada.

**Seguridad de los datos:** este APK de prueba tiene el identificador
`com.vanderverse.elhabitante.preview`, diferente del prototipo 0.1.
Se instala en paralelo y no puede acceder a los recuerdos de la versión 0.1.
Nunca desinstales la app original esperando que sus datos pasen automáticamente
al prototipo. Los builds debug se firman con claves efímeras en CI y no se
garantizan actualizaciones entre APK de pruebas. No es una distribución final.

El guardado interno continúa con `schemaVersion = 1`, con campos nuevos
opcionales, de manera que la lógica es compatible con los guardados 0.1
cuando en el futuro se utilice la misma identidad y firma estable.

---


Una criatura digital vive en una pequeña habitación. Sus rasgos, recuerdos y
decisiones evolucionan localmente. Primera plataforma: **Android 7.0 / API 24 o
superior**. La interfaz y el motor están escritos en Flutter/Dart y pueden
reutilizarse en iOS más adelante; todavía no se agregó el proyecto nativo iOS.

## Qué incluye

- Habitación 2D con criatura provisional dibujada y animada, sin recursos remotos.
- Tocar para saludar, dejar una piedra y darle espacio. Cada gesto cambia rasgos
  diferentes y deja un recuerdo; hay una pausa de tres segundos entre gestos.
- Curiosidad, confianza, independencia y sensibilidad independientes, sin barra de
  felicidad ni puntuación de amistad. Emociones, actividades y diálogos por reglas.
- Recuerdos estructurados: tipo, fecha UTC, texto e interacción asociada.
- Actividad autónoma en franjas de cinco minutos. Al volver a abrir se procesa el
  tiempo transcurrido, con un límite de ocho horas de evolución por ausencia. No se
  ejecuta un servicio en segundo plano ni se castiga al usuario por ausentarse.
- Un acontecimiento misterioso tras cuatro interacciones o treinta minutos desde
  el descubrimiento. Se puede examinar y no se repite al reiniciar.
- JSON versionado en el directorio privado de la app, con sustitución atómica,
  errores visibles y un máximo de cien recuerdos recientes.

No usa cuentas, IA externa, reconocimiento de voz, permisos de micrófono ni
servicios de red de la aplicación. Android tiene desactivados los backups
automáticos y las reglas de transferencia de datos. Los permisos `INTERNET` de
las variantes debug/profile son para las herramientas de desarrollo de Flutter;
el manifiesto principal no solicita permisos. Desinstalar o borrar los datos
elimina los recuerdos; no hay sincronización ni recuperación remota.

## Viabilidad y estructura

Flutter es suficiente para esta habitación sencilla: `CustomPainter` y animaciones
evitan agregar un motor de videojuegos. Dart puro permite probar la simulación
sin un teléfono. Para este volumen de datos, JSON local es más sencillo que una
base de datos; `path_provider` es la única dependencia funcional adicional y
resuelve el directorio privado del dispositivo. No hace falta otra tecnología
para el alcance 0.1.

```text
lib/
  main.dart                       # Punto de entrada
  app.dart                        # Tema e inyección del almacenamiento
  domain/
    habitant.dart                 # Estado inmutable, personalidad, recuerdos, JSON
    behavior_engine.dart          # Reglas puras, diálogos y tiempo transcurrido
  data/
    habitat_repository.dart       # Contrato de persistencia
    file_habitat_repository.dart   # Archivo local y sustitución atómica
  application/
    habitat_controller.dart       # Orquestación y cola de guardados
  presentation/
    habitat_screen.dart           # Interacciones, recuerdos y ciclo de vida
    room_view.dart                # Habitación y criatura animada
android/                          # Contenedor Android mínimo, en Java
test/                             # Motor, disco, controlador e interfaz
tool/                             # Instalación cloud y verificación
```

El motor recibe la hora y las interacciones como argumentos, devuelve un nuevo
estado y no importa Flutter ni accede a archivos. En una etapa posterior, voz o
IA local pueden convertir entradas en esas interacciones o sustituir la selección
de diálogos sin acoplar el motor a la interfaz. No se agregaron integraciones ni
abstracciones de voz que todavía no se utilizan.

## Qué instalar en tu computadora

1. **Git** y **Flutter estable 3.47.9**, la versión indicada en `.flutter-version`.
   Flutter incluye Dart: no lo instales por separado. Agregá `flutter/bin` al PATH.
   Guía oficial: <https://docs.flutter.dev/install>.
2. **Android Studio**, con Android SDK Platform **36**, Build-Tools **36.0.0**,
   Platform-Tools y Command-line Tools. Si Flutter solicita el NDK, instalá
   **28.2.13676358** desde SDK Manager → SDK Tools → Show Package Details.
3. **JDK 21**. Podés usar el JDK incluido con Android Studio si es compatible;
   `flutter doctor -v` indica cuál usa. Si necesitás seleccionarlo:
   `flutter config --jdk-dir="RUTA_A_TU_JDK_21"`.
4. Un teléfono Android compatible y cable USB de datos, o un emulador Android
   creado desde Device Manager. En Windows, algunos teléfonos necesitan además
   el controlador USB de su fabricante.

Gradle **9.3.1** y Android Gradle Plugin **9.1.0** están fijados en el proyecto y
se descargan durante la primera compilación. No necesitás instalarlos globalmente.
La primera preparación requiere Internet para descargar SDK y paquetes; la app
instalada funciona sin conexión.

## Ejecutar en un teléfono Android

Trabajá en la carpeta que contiene `pubspec.yaml` (esta carpeta del proyecto).
Si descargaste un ZIP, descomprimilo primero. Los cambios nuevos del prototipo
están en el espacio de trabajo de esta tarea; el repositorio remoto solo los
tendrá después de guardarlos en Git y subirlos.

```sh
flutter --version
flutter doctor --android-licenses
flutter doctor -v
flutter pub get
```

El primer `pub get` crea `pubspec.lock` mediante el resolvedor oficial. Ese archivo
debe conservarse en Git para fijar las dependencias de la aplicación; no se
inventó un lockfile manual durante el bloqueo de red del entorno cloud.

En el teléfono, activá Opciones de desarrollador → Depuración USB. Conectalo y
aceptá la autorización de la computadora en la pantalla del teléfono.

```sh
flutter devices
flutter run -d ID_DEL_TELEFONO
```

Reemplazá `ID_DEL_TELEFONO` por el identificador mostrado por `flutter devices`.
No hace falta crear cuentas ni introducir claves de servicios. El identificador
Android provisional es `com.vanderverse.elhabitante`.

Para generar e instalar un APK de pruebas:

```sh
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Este APK es para pruebas. La firma de publicación y la distribución en Play
Store no están configuradas; la variante release de la plantilla usa firma debug.

## Pruebas

```sh
flutter analyze
flutter test
flutter build apk --debug
```

En Bash, `bash tool/verify.sh` ejecuta esas comprobaciones y detiene la secuencia
ante un fallo. Para formatear el código: `dart format lib test`.

Las pruebas existentes cubren evolución de rasgos, límites, pausas entre toques,
relojes atrasados, ausencias largas, misterio único, diálogos, serialización,
reapertura del archivo, archivos corruptos, cola de guardados, reintentos de
errores y una interacción completa de interfaz. Los widget tests no sustituyen
una prueba del plugin nativo en un dispositivo.

Prueba manual breve:

1. Abrí la app, saludá y dejá una piedra, esperando tres segundos entre gestos.
2. Abrí el libro de recuerdos y comprobá que aparecen los encuentros.
3. Después de cuatro gestos, examiná la marca de la pared.
4. Cerrá y reabrí: los recuerdos y el misterio deben conservarse.
5. Dejala cerrada al menos cinco minutos y volvé: debe aparecer una actividad
   autónoma. También podés probar con modo avión.

## Entorno cloud

```sh
bash tool/setup_cloud.sh
source tool/cloud_env.sh
bash tool/verify.sh
```

El instalador Linux x86_64 guarda SDK y cachés en `/workspace/.toolchains`, fija
el commit de Flutter y verifica los checksums de JDK y Android. Conserva el proxy
y la verificación TLS del entorno. No se necesita un servidor para esta app y
no se crean worktrees: se utiliza el checkout aislado existente.

La política de red debe permitir `storage.googleapis.com` además del preset de
gestores de paquetes. El dominio se guardó en el borrador de configuración, pero
guardar un borrador no aplica ni publica sus cambios. La configuración y las
instrucciones de activación quedan disponibles para futuras tareas.

El estado de las comprobaciones realizadas en esta tarea está en
[docs/VALIDACION.md](docs/VALIDACION.md). Hasta completar las comprobaciones Flutter
indicadas allí, no se considera validada la ejecución ni la compilación del APK.
