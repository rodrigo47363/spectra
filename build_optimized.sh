#!/usr/bin/env bash
# Script de compilación optimizada de Spotube Custom para Linux
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_BIN="$HOME/flutter/bin/flutter"

echo "[*] Entrando en directorio del proyecto: $REPO_DIR"
cd "$REPO_DIR"

if [ ! -x "$FLUTTER_BIN" ]; then
    echo "[!] Error: Flutter SDK no encontrado en $FLUTTER_BIN"
    exit 1
fi

echo "[*] Verificando dependencias nativas de desarrollo..."
if ! pkg-config --exists webkit2gtk-4.1 || ! pkg-config --exists libnotify; then
    echo ""
    echo "======================================================================"
    echo "[!] FALTAN CABECERAS DE WEBKIT2GTK Y NOTIFICACIONES"
    echo "======================================================================"
    echo "Ejecuta este comando en tu terminal para completar las librerías:"
    echo ""
    echo "sudo apt install -y libwebkit2gtk-4.1-dev libnotify-dev"
    echo ""
    echo "Una vez completado, vuelve a ejecutar este script:"
    echo "$0"
    echo "======================================================================"
    exit 1
fi

echo "[*] Verificando dependencias con flutter pub get..."
"$FLUTTER_BIN" pub get

echo "[*] Compilando binario nativo de Linux en modo Release con optimizaciones..."
"$FLUTTER_BIN" build linux --release --obfuscate --split-debug-info=build/symbols

echo "[+] Compilación exitosa."
echo "[+] Binario generado en: $REPO_DIR/build/linux/x64/release/bundle/spectra"
echo "[+] Puedes ejecutarlo directamente con: spectra"
