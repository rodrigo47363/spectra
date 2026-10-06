#!/usr/bin/env bash
# ==============================================================================
# Spectra Version Management & Release Script
# ==============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC="${PROJECT_ROOT}/pubspec.yaml"
APPDATA="${PROJECT_ROOT}/linux/dev.rodrigo.spectra.appdata.xml"
SRCINFO="${PROJECT_ROOT}/aur-struct/.SRCINFO"

# Leer versión actual de pubspec.yaml
CURRENT_FULL=$(grep "^version:" "${PUBSPEC}" | sed -E 's/version:[[:space:]]*//')
CURRENT_VER="${CURRENT_FULL%+*}"
CURRENT_BUILD="${CURRENT_FULL##*+}"

if [[ "${CURRENT_VER}" == "${CURRENT_BUILD}" ]]; then
    CURRENT_BUILD=1
fi

function show_help() {
    cat <<EOF
Uso: $0 [OPCIÓN] [VALOR]

Opciones:
  patch                  Incrementa la versión PATCH (ej: 1.0.0 -> 1.0.1) y el build (+1)
  minor                  Incrementa la versión MINOR (ej: 1.0.0 -> 1.1.0) y el build (+1)
  major                  Incrementa la versión MAJOR (ej: 1.0.0 -> 2.0.0) y el build (+1)
  set <version> [build]  Establece una versión manual (ej: 1.2.0 5 -> 1.2.0+5)
  show                   Muestra la versión actual del proyecto
  --tag                  (Opcional con patch/minor/major/set) Crea un commit y git tag v<version>

Ejemplos:
  $0 patch
  $0 minor --tag
  $0 set 1.0.0 1 --tag
EOF
    exit 0
}

if [[ $# -eq 0 ]]; then
    show_help
fi

ACTION="$1"
CREATE_TAG=false
NEW_VER=""
NEW_BUILD=$((CURRENT_BUILD + 1))

IFS='.' read -r MAJOR MINOR PATCH <<< "${CURRENT_VER}"

case "${ACTION}" in
    show)
        echo "=========================================="
        echo "  Spectra - Versión Actual"
        echo "=========================================="
        echo "  Versión:       ${CURRENT_VER}"
        echo "  Build Number:  ${CURRENT_BUILD}"
        echo "  Full SemVer:   ${CURRENT_FULL}"
        echo "=========================================="
        exit 0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        NEW_VER="${MAJOR}.${MINOR}.${PATCH}"
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        NEW_VER="${MAJOR}.${MINOR}.${PATCH}"
        ;;
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        NEW_VER="${MAJOR}.${MINOR}.${PATCH}"
        ;;
    set)
        if [[ $# -lt 2 ]]; then
            echo "Error: Debes especificar el número de versión (ej: 1.0.0)"
            exit 1
        fi
        NEW_VER="$2"
        if [[ $# -ge 3 && "$3" =~ ^[0-9]+$ ]]; then
            NEW_BUILD="$3"
        fi
        ;;
    -h|--help)
        show_help
        ;;
    *)
        echo "Error: Opción desconocida '${ACTION}'"
        show_help
        ;;
esac

# Comprobar si se solicitó crear tag git
for arg in "$@"; do
    if [[ "$arg" == "--tag" || "$arg" == "-t" ]]; then
        CREATE_TAG=true
    fi
done

NEW_FULL="${NEW_VER}+${NEW_BUILD}"
TODAY=$(date +%Y-%m-%d)

echo "=========================================="
echo "  Actualizando Control de Versiones"
echo "=========================================="
echo "  Anterior: ${CURRENT_FULL}"
echo "  Nueva:    ${NEW_FULL}"
echo "=========================================="

# 1. Actualizar pubspec.yaml
sed -i -E "s/^version: .*/version: ${NEW_FULL}/" "${PUBSPEC}"
echo "[+] Actualizado: pubspec.yaml -> ${NEW_FULL}"

# 2. Actualizar appdata.xml
if [[ -f "${APPDATA}" ]]; then
    if grep -q "version=\"${NEW_VER}\"" "${APPDATA}"; then
        echo "[!] appdata.xml ya contiene la entrada para v${NEW_VER}"
    else
        sed -i "/<releases>/a \ \ \ \ <release version=\"${NEW_VER}\" date=\"${TODAY}\">\n      <description>\n        <p>Spectra release ${NEW_VER}</p>\n      </description>\n    </release>" "${APPDATA}"
        echo "[+] Actualizado: linux/dev.rodrigo.spectra.appdata.xml -> v${NEW_VER}"
    fi
fi

# 3. Actualizar AUR .SRCINFO
if [[ -f "${SRCINFO}" ]]; then
    sed -i -E "s/^pkgver = .*/pkgver = ${NEW_VER}/" "${SRCINFO}"
    sed -i -E "s/\/v[0-9\.]+\/spectra-linux-[0-9\.]+-/\/v${NEW_VER}\/spectra-linux-${NEW_VER}-/" "${SRCINFO}"
    echo "[+] Actualizado: aur-struct/.SRCINFO -> v${NEW_VER}"
fi

# 4. Crear commit y tag si se especificó
if [[ "${CREATE_TAG}" == true ]]; then
    cd "${PROJECT_ROOT}"
    git add "${PUBSPEC}" "${APPDATA}" "${SRCINFO}" 2>/dev/null || true
    git commit -m "chore(release): v${NEW_FULL}"
    git tag -a "v${NEW_VER}" -m "Release v${NEW_VER}"
    echo "[+] Git: Commit y Tag creados: v${NEW_VER}"
fi

echo "=========================================="
echo "  Versión actualizada exitosamente a ${NEW_FULL}"
echo "=========================================="
