# 🛡️ Spectra — High-Performance Cross-Platform Music Player

<div align="center">

<img src="assets/branding/spectra-logo.png" alt="Spectra Logo" width="160" />

### *Reproductor y gestor de audio libre, diseñado bajo el principio de privacidad desde el diseño (privacy by design), bajo consumo de recursos y total soberanía sobre los datos del usuario.*

[![Release](https://img.shields.io/badge/Release-v1.0.0-00E5FF?style=for-the-badge&logo=github)](https://github.com/rodrigo47363/spectra/releases)
[![License](https://img.shields.io/badge/License-BSD--4--Clause-blue?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platforms-Android%20%7C%20Windows%20%7C%20Linux-brightgreen?style=for-the-badge)](#descargas-y-binarios)
[![Zero Telemetry](https://img.shields.io/badge/Telemetry-Zero%20%2F%20No%20Tracking-red?style=for-the-badge)](PRIVACY_POLICY.md)

[Descargas](#descargas-y-binarios) • [Características](#características-técnicas) • [Arquitectura](#arquitectura-del-sistema) • [Compilación](#compilación-y-despliegue) • [Optimización](#optimización-operativa-y-ajustes-de-reproducción) • [Versiones](#control-de-versiones) • [Autor](#arquitecto-y-desarrollo)

---

</div>

## 📌 Visión del Proyecto

**Spectra** es una plataforma de reproducción y agregación de medios desarrollada en **Flutter** con integración nativa en **C++ (`libmpv`)**. Nace con un principio operativo no negociable: **la desvinculación total del rastreo y la telemetría invasiva**.

A diferencia de la mayoría de los clientes de streaming contemporáneos, Spectra opera bajo el paradigma **BYOMM (*Bring Your Own Music Metadata*)**: desacopla el motor de reproducción de las fuentes de información musical, permitiendo conectar múltiples fuentes y plugins sin exponer la huella digital del usuario a intermediarios comerciales.

---

## 🌟 Características Técnicas

* 🔒 **Cero Telemetría & Privacidad Radical:** Sin *fingerprinting*, sin analíticas de comportamiento en segundo plano ni transmisión de identificadores únicos de hardware.
* ⚡ **Decodificación Nativa por Hardware:** Integración con `libmpv` / `media_kit` para streaming de ultrabaja latencia y reproducción bit-perfect de alta fidelidad.
* 🧩 **Ecosistema Extensible de Plugins:** Arquitectura modular que permite extender proveedores de metadatos, letras y fuentes de audio.
* 🗄️ **Persistencia Local-First:** Base de datos relacional local en **SQLite (Drift)** y almacenamiento de preferencias cifrado. No depende de servidores centralizados.
* 📥 **Gestor de Descargas Integrado:** Descarga pistas de audio con etiquetado ID3 automatizado y metadatos completos incrustados.
* 🕒 **Sincronización de Letras en Tiempo Real:** Letras sincronizadas con soporte para visualización en ventana o modo compacto.
* 🎨 **Interfaz Adaptativa Shadcn UI:** Interfaz moderna y minimalista con extracción dinámica de paletas cromáticas derivadas de las portadas de los álbumes.

---

## 📦 Descargas y Binarios

| Plataforma | Paquete / Formato | Arquitectura | Enlace de Descarga |
| :--- | :--- | :--- | :--- |
| **Linux** | Paquete Debian (`.deb`) | `x86_64 / amd64` | [Descargar .deb](https://github.com/rodrigo47363/spectra/releases/download/v1.0.0/Spectra-v1.0.0-linux-x86_64.deb) |
| **Linux** | Binario Portable Bundle (`.tar.gz`) | `x86_64 / amd64` | [Descargar .tar.gz](https://github.com/rodrigo47363/spectra/releases/download/v1.0.0/Spectra-v1.0.0-linux-x86_64.tar.gz) |
| **Android** | Paquete Universal (`.apk`) | `arm64-v8a, armeabi-v7a, x86_64` | [Descargar .apk](https://github.com/rodrigo47363/spectra/releases/download/v1.0.0/Spectra-v1.0.0-android-universal.apk) |
| **Windows** | Instalador Setup (`.exe`) | `x86_64` | [Ver Releases](https://github.com/rodrigo47363/spectra/releases/tag/v1.0.0) |

---

## 🏗️ Arquitectura del Sistema

```text
┌─────────────────────────────────────────────────────────────────┐
│                       SPECTRA CLIENT (UI)                       │
│           Flutter Framework • Shadcn Flutter • Riverpod          │
└──────────────┬──────────────────────────────┬───────────────────┘
               │                              │
┌──────────────▼──────────────┐┌──────────────▼───────────────────┐
│       Core Playback         ││         Data & Storage           │
│  MediaKit Engine + libmpv   ││    SQLite (Drift) + Safe KV      │
│     (Native C++ Audio)      ││   (Local-First Persistence)      │
└──────────────┬──────────────┘└──────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────────┐
│              BYOMM Plugin & Audio Source Engine                 │
│      Dynamic Resolution • Safe HTTP Transport • Zero-Telemetry   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Compilación y Despliegue

### 1. Entorno Linux (Debian, Ubuntu y derivadas)

#### Prerrequisitos de compilación:
```bash
sudo apt update
sudo apt install -y build-essential libgtk-3-dev libmpv-dev libsecret-1-dev \
    libnotify-dev libjsoncpp-dev libwebkit2gtk-4.1-dev libsoup-3.0-dev mpv
```

#### Compilar binario nativo optimizado:
```bash
./build_optimized.sh
```
El binario ejecutable se genera en:
`build/linux/x64/release/bundle/spectra`

#### Empaquetar instalador `.deb`:
```bash
./scripts/package_deb.sh
```
El paquete se generará en:
`dist/Spectra-v1.0.0-linux-x86_64.deb`

---

### 2. Entorno Android

#### Prerrequisitos:
* Android SDK (API 34+) y JDK 17 o superior.
* Flutter SDK (3.29.0+).

#### Compilar APK firmado de producción:
```bash
flutter build apk --flavor stable
```
Ubicación del paquete:
`build/app/outputs/flutter-apk/app-stable-release.apk`

---

### 3. Entorno Windows

#### Prerrequisitos:
* Visual Studio 2022 con carga de trabajo *Desktop development with C++*.
* Inno Setup 6 (para empaquetado del instalador).

#### Compilar instalador ejecutable:
```bash
dart run cli/cli.dart build windows
```
El instalador se generará en:
`dist/Spectra-windows-x86_64-setup.exe`

---

## ⚙️ Optimización Operativa y Ajustes de Reproducción

Para garantizar una experiencia de reproducción fluida y continua sin interrupciones:

### En Android:
1. **Motor de Extracción de Audio:** En *Ajustes > Reproducción*, puedes alternar entre **NewPipe** y **YouTubeExplode**. Si experimentas estrangulamiento de velocidad (*rate limiting*) o latencia por parte de los servidores de origen, cambiar al motor alternativo restablece el flujo instantáneamente.
2. **Formato de Códec de Audio:** Selecciona **`m4a` / `mp4`** (AAC nativo) para aprovechar la decodificación por hardware de Android (*MediaCodec*), reduciendo el consumo térmico y el gasto de batería.
3. **Gestión de Batería en Segundo Plano:** En *Ajustes de Android > Aplicaciones > Spectra > Batería*, selecciona **"Sin restricciones"** (o desactiva la optimización). Esto previene que el sistema operativo congele el socket de loopback local (`127.0.0.1`) cuando la pantalla esté apagada.

### En Linux:
* Spectra utiliza el motor nativo `media_kit` enlazado con las librerías dinámicas del sistema `libmpv`. Asegúrate de tener instalados los paquetes `libmpv-dev` o `mpv` para decodificación acelerada por hardware (VA-API / VDPAU).

---

## 🔄 Control de Versiones

Spectra integra un script de control de versiones automatizado para gestionar lanzamientos:

```bash
# Consultar versión actual
./scripts/bump_version.sh show

# Incrementar versión de parche (1.0.0 -> 1.0.1)
./scripts/bump_version.sh patch

# Incrementar versión menor con etiqueta git (1.0.0 -> 1.1.0)
./scripts/bump_version.sh minor --tag

# Fijar una versión específica
./scripts/bump_version.sh set 1.2.0 5 --tag
```

---

## 👨‍💻 Arquitecto y Desarrollo

**Rodrigo**  
*Offensive Security Specialist & Software Architect*  
> *"Impacto real > Teoría. Privacidad y rendimiento de grado operativo."*

* 🌐 **GitHub:** [@rodrigo47363](https://github.com/rodrigo47363)
* 💼 **LinkedIn:** [Rodrigo V.](https://linkedin.com/in/rodrigo-v-695728215)
* 📺 **YouTube:** [@Rodrigo-47363](https://youtube.com/@Rodrigo-47363)
* 📬 **Email Cifrado:** [rodrigovil@proton.me](mailto:rodrigovil@proton.me)

---

## ⚡ Apoyo a la Investigación Operativa

Si este proyecto o las herramientas desarrolladas han optimizado tus flujos de trabajo, puedes respaldar el desarrollo continuo:

| Activo | Red | Dirección de Destino |
| :--- | :---: | :--- |
| **Bitcoin (BTC)** | *BTC Native* | `bc1qkzmpd0hry99qms7ef23vsyx9vt34pzzaslpp8y` |
| **Ethereum (ETH)** | *ERC-20 / EVM* | `0xB75bC57C54FCBFF139EBF981A596B019C537d018` |
| **Solana (SOL)** | *SPL* | `ELekuGHcmZjhXrtHNqHuu8QmdCZr3oCWtTmu3QUQ5hac` |

---

## 📜 Licencia y Descargo de Responsabilidad

Este software se distribuye bajo la licencia **BSD 4-Clause**. Consulta el archivo [LICENSE](LICENSE) para más detalles.

Spectra no aloja, retransmite ni distribuye contenidos protegidos por derechos de autor. Todas las consultas de audio y metadatos se resuelven de forma descentralizada mediante los plugins configurados por el usuario final.
