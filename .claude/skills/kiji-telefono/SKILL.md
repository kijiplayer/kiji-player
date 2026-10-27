---
name: kiji-telefono
description: Reglas para probar Kiji en un teléfono real conectado por ADB (instalar, tocar, capturar, leer logs). Usar antes de cualquier comando adb o de instalar un APK en el teléfono.
---

# Probar en el teléfono

## Antes de instalar
- Respaldar primero los datos de la app que se va a tocar: desde Kiji (Configuración → Copia de
  seguridad → "Hacer una copia ahora") o, en Kiji Dev (depurable),
  `adb exec-out run-as io.github.kijiplayer.kiji.dev tar c files app_flutter > respaldo.tar`.
  Si no se puede, pedirle al mantenedor que la haga.

## Instalar
- Siempre primero **Kiji Dev** (`io.github.kijiplayer.kiji.dev`):
  `flutter build apk --debug --flavor dev` y `adb install -r build/app/outputs/flutter-apk/app-dev-debug.apk`.
- Kiji normal (`io.github.kijiplayer.kiji`) solo con aprobación explícita.
- Solo `adb install -r`. **Nunca** `adb uninstall`, `pm clear` ni nada que borre datos.
- **Nunca** `flutter test`, `flutter drive` ni pruebas de integración en el teléfono: desinstalan
  la app y se pierden los datos. Esas pruebas van solo en la PC (`-d windows`).

## Mientras se prueba
- Antes de cada toque, captura o lectura: comprobar que Kiji está en primer plano
  (`adb shell dumpsys activity activities | grep topResumedActivity`). Si no, detenerse.
- No abrir, leer ni capturar otras apps. No usar "Atrás" en cadena: relanzar Kiji con `am start`.
- No cambiar ajustes del sistema. Ante un diálogo del sistema (permisos), no tocarlo y avisar.
- Logs: `adb logcat` filtrado por Kiji. Capturas: `adb exec-out screencap -p`, recortando la barra
  de estado y la de navegación; no compartirlas si aparecen datos personales, portadas o letras
  reales (ver `kiji-reglas`).
