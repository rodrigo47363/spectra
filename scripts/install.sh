#!/usr/bin/env bash

# Variables
fname="$(basename $0)"
installDir='/usr/share/spectra'
desktopFile='/usr/share/applications/spectra.desktop'
appdata='/usr/share/appdata/dev.rodrigo.spectra.appdata.xml'
icon='/usr/share/icons/spectra/spectra-logo.png'
symlink='/usr/bin/spectra'
temp='/tmp/spectra-installer'
latestVer="$(wget -qO- "https://api.github.com/repos/rodrigo47363/spectra/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')"

# Root check
function rootCheck() {
     if [ "${EUID}" -ne 0 ]; then
          echo "Error: Root permissions are required for ${fname} to work."
          echo "Please run './${fname}' for more information."
          exit 1
     fi
}

# Flags
function help(){
  echo "Usage: sudo ./${fname} [flags]"
  echo 'Flags:'
  echo '  -i, --install <version>    Install any Spectra version (if not specified, the latest is installed).'
  echo '  -h, --help                 This help menu'
  echo '  -r, --remove               Removes Spectra from your system'
  exit 0
}

# Checks whether a given command exists or not and returns bool
function command_exists() {
    command -v "$@" >/dev/null 2>&1
}

function install_deps(){
    local debianDeps='mpv libappindicator3-1 gir1.2-appindicator3-0.1 libsecret-1-0 libnotify-bin libjsoncpp25'
    local rpmDeps='mpv libappindicator jsoncpp libsecret libnotify'
    local archDeps='mpv libappindicator-gtk3 libsecret jsoncpp libnotify'

    if command_exists apt; then
        apt install -y ${debianDeps}
    elif command_exists dnf; then
        dnf install -y ${debianDeps}
    elif command_exists yum; then
        yum install -y ${rpmDeps}
    elif command_exists zypper; then
        zypper install -y ${rpmDeps}
    elif command_exists pacman; then
        pacman -Sy ${archDeps}
    else   
        echo 'You have to install some dependancies manually in order for Spectra to work.'
        echo "The deps are the following: ${rpmDeps}"
    fi
}

function download_extract_spectra(){
  local tarPath="/tmp/spectra-${ver}.tar.xz"
  local downloadURL="https://github.com/rodrigo47363/spectra/releases/download/v${ver}/spectra-linux-${ver}-x86_64.tar.xz"

  if [ "${ver}" = "nightly" ]; then
      downloadURL="https://github.com/rodrigo47363/spectra/releases/download/nightly/spectra-linux-nightly-x86_64.tar.xz"
  fi

  rm -rf ${temp}
  mkdir -p ${temp}

  # Check if already exists downloaded file
  if [ -f ${tarPath} ]; then
    echo "Installation file detected. Skipping download..."
  else
    echo "Downloading spectra-${ver}.tar.xz..."
    wget -q ${downloadURL} -O ${tarPath}
  fi

  tar -xf ${tarPath} -C ${temp}

  if [ ! "$(ls -A ${temp})" ]; then
    echo 'Failed to extract the tarball. Redownloading...'
    rm -f ${tarPath}
    wget -q ${downloadURL} -O ${tarPath}
    tar -xf ${tarPath} -C ${temp}
  fi
  
  if [ ! "$(ls -A ${temp})" ]; then
    echo 'Failed to extract the tarball. Installation aborted.'
    exit 1
  fi
}

function install_spectra(){
    if [ -d ${installDir} ]; then
        echo -n "Spectra is already installed. Do you want to reinstall it? [y/N] "
        read reinstall

        case "${reinstall}" in
        [yY]*)
            uninstall_spectra ;;
        *)
            echo 'Aborting installation...'
            exit 1 ;;
        esac
    fi

    # Install Spectra from temp dir
    mkdir -p ${installDir}
    mv ${temp}/data ${installDir}/ 2>/dev/null || true
    mv ${temp}/lib ${installDir}/ 2>/dev/null || true
    mv ${temp}/spectra ${installDir}/ 2>/dev/null || mv ${temp}/bundle/* ${installDir}/ 2>/dev/null || true
    mv ${temp}/spectra.desktop /usr/share/applications/ 2>/dev/null || true
    mv ${temp}/dev.rodrigo.spectra.appdata.xml ${appdata} 2>/dev/null || true
    mkdir -p /usr/share/icons/spectra
    mv ${temp}/*logo*.png ${icon} 2>/dev/null || true
    ln -sf /usr/share/spectra/spectra ${symlink}

    rm -rf ${temp}
    echo "Spectra ${ver} has been installed successfully!"
}

function uninstall_spectra(){
    echo -n "Are you sure you want to uninstall Spectra? [y/N] "
    read confirm

    case "${confirm}" in
    [yY]*)
            echo 'Uninstalling Spectra...'
            rm -rf ${installDir} ${desktopFile} ${appdata} ${icon} ${symlink} ;;
    *)
            echo 'Aborting...'
            exit 0 ;;
    esac
}

case "$1" in
-i | --install)
    if [ "$2" != "" ]; then
        ver="$2"
    else
        ver="${latestVer}"
    fi
    
    rootCheck
    install_deps
    download_extract_spectra
    install_spectra
    exit 0 ;;
-r | --remove)
    rootCheck
    uninstall_spectra
    exit 0 ;;
-h | --help | "")
    help
    exit 0 ;;
*)
    echo "Invalid flag '$1'"
    echo "Please run ./${fname} for more information."
    exit 1 ;;
esac
