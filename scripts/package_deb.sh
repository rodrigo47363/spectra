#!/usr/bin/env bash
# ==============================================================================
# Spectra Debian Package Builder (.deb)
# ==============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${REPO_DIR}/dist"
PKG_DIR="/tmp/spectra-deb-build"
BUNDLE_DIR="${REPO_DIR}/build/linux/x64/release/bundle"

if [ ! -d "${BUNDLE_DIR}" ]; then
    echo "[!] Error: Bundle no encontrado en ${BUNDLE_DIR}. Ejecuta ./build_optimized.sh primero."
    exit 1
fi

echo "[*] Preparando estructura de empaquetado..."
rm -rf "${PKG_DIR}"
mkdir -p "${DIST_DIR}"
mkdir -p "${PKG_DIR}/DEBIAN"
mkdir -p "${PKG_DIR}/usr/bin"
mkdir -p "${PKG_DIR}/usr/share/spectra"
mkdir -p "${PKG_DIR}/usr/share/applications"
mkdir -p "${PKG_DIR}/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${PKG_DIR}/usr/share/metainfo"

echo "[*] Copiando binarios y recursos..."
cp -r "${BUNDLE_DIR}/"* "${PKG_DIR}/usr/share/spectra/"

cat << 'EOF' > "${PKG_DIR}/usr/bin/spectra"
#!/usr/bin/env bash
exec /usr/share/spectra/spectra "$@"
EOF
chmod +x "${PKG_DIR}/usr/bin/spectra"
chmod +x "${PKG_DIR}/usr/share/spectra/spectra"

cp "${REPO_DIR}/linux/spectra.desktop" "${PKG_DIR}/usr/share/applications/spectra.desktop"
cp "${REPO_DIR}/assets/branding/spectra-logo.png" "${PKG_DIR}/usr/share/icons/hicolor/256x256/apps/spectra.png"
cp "${REPO_DIR}/linux/dev.rodrigo.spectra.appdata.xml" "${PKG_DIR}/usr/share/metainfo/dev.rodrigo.spectra.appdata.xml"

VERSION=$(grep "^version:" "${REPO_DIR}/pubspec.yaml" | sed -E 's/version:[[:space:]]*//' | cut -d'+' -f1)

cat << EOF > "${PKG_DIR}/DEBIAN/control"
Package: spectra
Version: ${VERSION}
Section: x11
Priority: optional
Architecture: amd64
Maintainer: Rodrigo <rodrigovil@proton.me>
Homepage: https://github.com/rodrigo47363/spectra
Installed-Size: 52000
Depends: mpv, libappindicator3-1 | libayatana-appindicator3-1, gir1.2-appindicator3-0.1 | gir1.2-ayatanaappindicator3-0.1, libsecret-1-0, libnotify-bin, libjsoncpp1 | libjsoncpp25 | libjsoncpp26, libmpv1 | libmpv2, xdg-user-dirs, avahi-daemon, avahi-discover, avahi-utils, libnss-mdns, mdns-scan, libwebkit2gtk-4.1-0 | libwebkit2gtk-4.0-0, libsoup-3.0-0 | libsoup-2.4-0
Suggests: yt-dlp
Description: Reproductor y gestor de audio libre universal enfocado en privacidad y rendimiento nativo.
EOF

echo "[*] Compilando paquete .deb con dpkg-deb..."
DEB_NAME="Spectra-v${VERSION}-linux-x86_64.deb"
dpkg-deb --build --root-owner-group "${PKG_DIR}" "${DIST_DIR}/${DEB_NAME}"

echo "[+] Paquete .deb generado exitosamente en: ${DIST_DIR}/${DEB_NAME}"
