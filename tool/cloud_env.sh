#!/usr/bin/env bash
# Activación para esta máquina Linux; en una computadora personal usá tu Flutter.
export HABITANTE_TOOLCHAINS="${HABITANTE_TOOLCHAINS:-/workspace/.toolchains}"
export FLUTTER_ROOT="$HABITANTE_TOOLCHAINS/flutter"
export JAVA_HOME="$HABITANTE_TOOLCHAINS/java/jdk-21.0.13+9"
export ANDROID_HOME="$HABITANTE_TOOLCHAINS/android"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="$HABITANTE_TOOLCHAINS/android-user"
export PUB_CACHE="$HABITANTE_TOOLCHAINS/pub-cache"
export GRADLE_USER_HOME="$HABITANTE_TOOLCHAINS/gradle"
export FLUTTER_SUPPRESS_ANALYTICS=true
export PATH="$FLUTTER_ROOT/bin:$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

# Gradle (Java) no interpreta HTTPS_PROXY por sí mismo. Conservá el proxy de sesión.
if [[ -n "${HTTPS_PROXY:-}" ]]; then
  habitante_proxy_args="$(python3 - <<'PY'
import os, urllib.parse
p = urllib.parse.urlsplit(os.environ['HTTPS_PROXY'])
if not p.hostname or not p.port:
    raise SystemExit('El proxy necesita un host y puerto explícitos')
print(f'-Dhttps.proxyHost={p.hostname} -Dhttps.proxyPort={p.port} '
      f'-Dhttp.proxyHost={p.hostname} -Dhttp.proxyPort={p.port} '
      '-Dhttp.nonProxyHosts=localhost|127.*')
PY
)"
  export GRADLE_OPTS="${GRADLE_OPTS:-} $habitante_proxy_args"
  unset habitante_proxy_args
fi

# El JDK descargado debe conservar la confianza TLS de la máquina administrada.
if [[ -f /etc/ssl/certs/java/cacerts ]]; then
  export GRADLE_OPTS="${GRADLE_OPTS:-} -Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts"
fi
