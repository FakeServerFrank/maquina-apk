#!/usr/bin/env bash
# Construye el APK de Máquina con Capacitor. Lo ejecuta GitHub Actions.
set -euo pipefail
export CI=true

rm -rf www app Maquina.apk
mkdir www
unzip -q maquina-app.zip -d www
[ -f www/index.html ] || { echo "ERROR: maquina-app.zip debe tener index.html en la raiz"; exit 1; }

mkdir app && cd app
npm init -y >/dev/null
npm install --no-audit --no-fund @capacitor/core@6 @capacitor/cli@6 @capacitor/android@6
cp -r ../www ./www
npx cap telemetry off || true
npx cap init "Máquina" com.maquina.app --web-dir www
npx cap add android

# Permisos: micrófono, cámara y ubicación
python3 - android/app/src/main/AndroidManifest.xml <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
extra = '''    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.microphone" android:required="false" />
'''
assert '</manifest>' in s
open(p, 'w', encoding='utf-8').write(s.replace('</manifest>', extra + '</manifest>'))
PY

# Icono de la app (si ImageMagick está disponible)
if command -v convert >/dev/null 2>&1; then
  R=android/app/src/main/res
  for d in "mdpi 48 108" "hdpi 72 162" "xhdpi 96 216" "xxhdpi 144 324" "xxxhdpi 192 432"; do
    read -r n a b <<< "$d"
    [ -d "$R/mipmap-$n" ] || continue
    convert www/icons/icon-512.png -resize "${a}x${a}" "$R/mipmap-$n/ic_launcher.png"
    convert www/icons/icon-512.png -resize "${a}x${a}" "$R/mipmap-$n/ic_launcher_round.png"
    convert www/icons/maskable-512.png -resize "${b}x${b}" "$R/mipmap-$n/ic_launcher_foreground.png"
  done
  sed -i 's/#FFFFFF/#0E1828/I' "$R/values/ic_launcher_background.xml" || true
fi

cd android
chmod +x gradlew
./gradlew assembleDebug --no-daemon
cd ../..
cp app/android/app/build/outputs/apk/debug/app-debug.apk Maquina.apk
echo "APK listo: $(du -h Maquina.apk | cut -f1)"
