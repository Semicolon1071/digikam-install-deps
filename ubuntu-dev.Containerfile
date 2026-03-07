# =============================================================================
# Multi-stage Containerfile for building digiKam from source.
#
# Compiles Qt6, KDE Frameworks 6, OpenCV, libheif, and exiv2 from source,
# then produces a final image ready for building digiKam itself.
#
# Build with:  podman build --tag digikam-dev --file ubuntu-dev.Containerfile .
# =============================================================================

# ---------------------------------------------------------------------------
# Build arguments — override these to rebuild with different versions
# without editing this file. Values must match tags in the upstream repos
# referenced by 3rdparty/ext_kf6/CMakeLists.txt.
# ---------------------------------------------------------------------------
ARG UBUNTU_VERSION=25.10
ARG DK_KDE_VERSION=v6.22.0
ARG DK_KP_VERSION=v6.5.5
ARG DK_KA_VERSION=v25.12.1


# ===========================================================================
# Stage 1: base — Ubuntu with all system development packages
# ===========================================================================
FROM ubuntu:${UBUNTU_VERSION} AS base

# Prevent apt from prompting for user input (timezone, keyboard layout, etc.)
# Set a UTF-8 locale to silence warnings from CMake, Perl, and other tools
# that do not support the default C/ANSI_X3.4-1968 encoding.
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    # --- Core build tools ---------------------------------------------------
    git \
    perl \
    cmake \
    ninja-build \
    build-essential \
    ccache \
    bison \
    flex \
    wget \
    tar \
    bzip2 \
    gettext \
    libtool \
    automake \
    yasm \
    patch \
    curl \
    gperf \
    doxygen \
    ca-certificates \
    pkg-config \
    # --- Clang/LLVM (used by some Qt6 tooling) ------------------------------
    clang-19 \
    llvm-19 \
    libclang-19-dev \
    # --- Python (needed by Qt6 and KF6 build systems) -----------------------
    python3 \
    python3-lxml \
    # --- Core C/C++ development libraries -----------------------------------
    libpthread-stubs0-dev \
    libc6-dev \
    libc++-dev \
    zlib1g-dev \
    liblzma-dev \
    liblz-dev \
    libssl-dev \
    libsqlite3-dev \
    libcppunit-dev \
    libprotoc-dev \
    protobuf-compiler \
    protobuf-compiler-grpc \
    libgrpc++-dev \
    libboost-dev \
    # --- Image format libraries ---------------------------------------------
    libtiff-dev \
    libpng-dev \
    libjpeg-dev \
    libjxl-dev \
    # --- X11 / Wayland / display -------------------------------------------
    libdrm-dev \
    libx11-dev \
    libx11-keyboard-perl \
    libx11-xcb-dev \
    libxinerama-dev \
    libxi-dev \
    libxtst-dev \
    libxrandr-dev \
    libxcursor-dev \
    libxcomposite-dev \
    libxrender-dev \
    libxext-dev \
    libxfixes-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libxkbfile-dev \
    libxcb*-dev \
    libxshmfence-dev \
    libwayland-dev \
    libinput-dev \
    libsm-dev \
    libegl1-mesa-dev \
    libgl1-mesa-dev \
    libgles2-mesa-dev \
    libglu1-mesa-dev \
    libgbm-dev \
    freeglut3-dev \
    # --- System integration -------------------------------------------------
    libdbus-1-dev \
    libudev-dev \
    libmount-dev \
    libcups2-dev \
    libcap-dev \
    libfuse-dev \
    # --- Fonts and text -----------------------------------------------------
    libfontconfig1-dev \
    libfreetype6-dev \
    libicu-dev \
    icu-devtools \
    libslang2-dev \
    hunspell \
    libhunspell-dev \
    # --- Audio --------------------------------------------------------------
    libopenal-dev \
    libpulse-dev \
    libcanberra-dev \
    flite1-dev \
    # --- Multimedia / codecs ------------------------------------------------
    libass-dev \
    libavcodec-dev \
    libavutil-dev \
    libswresample-dev \
    libavformat-dev \
    libavfilter-dev \
    libavdevice-dev \
    libpostproc-dev \
    libswscale-dev \
    libx265-dev \
    # --- Other libraries used by digiKam ------------------------------------
    libglib2.0-dev \
    libusb-1.0-0-dev \
    libltdl-dev \
    libinotifytools0-dev \
    libgcrypt-dev \
    libical-dev \
    libxslt-dev \
    libgphoto2-dev \
    libeigen3-dev \
    libmagick++-dev \
    libsane-dev \
    liblensfun-dev \
    libnss3-dev \
    # --- Database client libraries (for Qt SQL plugins) ---------------------
    default-libmysqlclient-dev \
    libpq-dev \
    unixodbc-dev \
    # --- Node.js (used by some Qt6 build steps) -----------------------------
    nodejs \
    && rm -rf /var/lib/apt/lists/*


# ===========================================================================
# Stage 2: qt6-prereqs — Build CMake, Jasper, and OpenSSL from source
#
# These are fast builds (~15-30 min) that rarely change. Caching this stage
# avoids rebuilding them when only Qt6 or KF6 versions change.
# ===========================================================================
FROM base AS qt6-prereqs

# Re-declare ARGs after FROM (they don't carry across stages)
ARG DK_KDE_VERSION
ARG DK_KP_VERSION
ARG DK_KA_VERSION

# Paths used throughout the build. ORIG_WD must match WORKDIR because
# the CMakeLists.txt files reference $ORIG_WD/3rdparty.
ENV INSTALL_DIR=/opt/qt6 \
    ORIG_WD=/digikam-install-deps \
    BUILDING_DIR=/digikam-install-deps/build.qt6 \
    DOWNLOAD_DIR=/digikam-install-deps/download.qt6

WORKDIR /digikam-install-deps

# Copy only the CMake build system and patches — not the shell scripts
COPY 3rdparty/ 3rdparty/
COPY cmake/ cmake/

# Build a recent CMake from source (the system cmake may be too old for Qt6),
# then use it to build Jasper (JPEG-2000 support) and a static OpenSSL
# (linked into Qt6 to avoid system OpenSSL version conflicts).
RUN --mount=type=cache,target=/digikam-install-deps/download.qt6 \
    set -e && \
    CPU_CORES=$(( $(nproc) - 1 )) && [ "$CPU_CORES" -lt 1 ] && CPU_CORES=1; \
    mkdir -p "$BUILDING_DIR" "$INSTALL_DIR/logs" && \
    # --- Phase 1: build CMake using the system cmake ------------------------
    cd "$BUILDING_DIR" && \
    cmake "$ORIG_WD/3rdparty" \
    -DCMAKE_INSTALL_PREFIX:PATH="$INSTALL_DIR" \
    -DEXTERNALS_DOWNLOAD_DIR="$DOWNLOAD_DIR" \
    -DINSTALL_ROOT="$INSTALL_DIR" \
    -DKA_VERSION="$DK_KA_VERSION" \
    -DKP_VERSION="$DK_KP_VERSION" \
    -DKDE_VERSION="$DK_KDE_VERSION" \
    -Wno-dev && \
    cmake --build . --config RelWithDebInfo --target ext_cmake -- -j"$CPU_CORES" && \
    # --- Phase 2: reconfigure with the newly-built cmake, then build --------
    #     Jasper and OpenSSL
    rm -rf "$BUILDING_DIR"/* && \
    "$INSTALL_DIR/bin/cmake" "$ORIG_WD/3rdparty" \
    -DCMAKE_INSTALL_PREFIX:PATH="$INSTALL_DIR" \
    -DEXTERNALS_DOWNLOAD_DIR="$DOWNLOAD_DIR" \
    -DINSTALL_ROOT="$INSTALL_DIR" \
    -DKA_VERSION="$DK_KA_VERSION" \
    -DKP_VERSION="$DK_KP_VERSION" \
    -DKDE_VERSION="$DK_KDE_VERSION" \
    -Wno-dev && \
    "$INSTALL_DIR/bin/cmake" --build . --config RelWithDebInfo --target ext_jasper  -- -j"$CPU_CORES" && \
    "$INSTALL_DIR/bin/cmake" --build . --config RelWithDebInfo --target ext_openssl -- -j"$CPU_CORES"


# ===========================================================================
# Stage 3: qt6-built — Compile Qt6 (the most expensive step: 2-6 hours)
#
# Isolated in its own stage so that changes to OpenCV, libheif, exiv2, or
# KDE Frameworks versions do NOT trigger a multi-hour Qt6 rebuild.
# ===========================================================================
FROM qt6-prereqs AS qt6-built

# Qt6 requires ~4 GB of RAM per parallel compilation job. We calculate the
# safe number of parallel jobs from available memory, halved for safety.
# taskset pins the build to those cores so the OOM killer is less likely
# to intervene.
RUN --mount=type=cache,target=/digikam-install-deps/download.qt6 \
    set -e && \
    PHY_MEM=$(awk '/^MemTotal/{print int($2/1024/1024)}' /proc/meminfo) && \
    QT_CORES=$(( PHY_MEM / 4 / 2 )) && [ "$QT_CORES" -lt 1 ] && QT_CORES=1; \
    echo "Building Qt6 with $QT_CORES parallel jobs ($PHY_MEM GB RAM detected)" && \
    cd "$BUILDING_DIR" && \
    taskset -c "0-$((QT_CORES - 1))" \
    "$INSTALL_DIR/bin/cmake" --build . --parallel "$QT_CORES" \
    --config RelWithDebInfo --target ext_qt6


# ===========================================================================
# Stage 4: qt6-extras — OpenCV, libheif, exiv2 (~1-2 hours)
#
# These libraries depend on Qt6 being present. Separated from Qt6 so that
# version bumps here (e.g., new OpenCV) don't force a Qt6 rebuild.
# ===========================================================================
FROM qt6-built AS qt6-extras

# Clean stale static OpenSSL files that could conflict with the Qt6 build's
# linked copy (mirrors what the original script does).
RUN --mount=type=cache,target=/digikam-install-deps/download.qt6 \
    set -e && \
    CPU_CORES=$(( $(nproc) - 1 )) && [ "$CPU_CORES" -lt 1 ] && CPU_CORES=1; \
    rm -f /usr/local/lib/libssl.a /usr/local/lib/libcrypto.a && \
    rm -rf /usr/local/include/openssl && \
    cd "$BUILDING_DIR" && \
    "$INSTALL_DIR/bin/cmake" --build . --config RelWithDebInfo --target ext_opencv -- -j"$CPU_CORES" && \
    "$INSTALL_DIR/bin/cmake" --build . --config RelWithDebInfo --target ext_heif   -- -j"$CPU_CORES" && \
    "$INSTALL_DIR/bin/cmake" --build . --config RelWithDebInfo --target ext_exiv2  -- -j"$CPU_CORES" && \
    # Discard build artifacts to save space in this layer
    rm -rf "$BUILDING_DIR"/*


# ===========================================================================
# Stage 5: kf6-built — KDE Frameworks 6 (~3-6 hours)
#
# Builds ~37 KDE framework components in strict dependency order.
# Each component is a separate git clone + cmake build managed by the
# CMake ExternalProject system in 3rdparty/ext_kf6/CMakeLists.txt.
# ===========================================================================
FROM qt6-extras AS kf6-built

# Re-declare ARGs needed for KF6 configuration
ARG DK_KDE_VERSION
ARG DK_KP_VERSION
ARG DK_KA_VERSION

# The KF6 build needs a fresh cmake configuration (it adds EXTERNALS_BUILD_DIR).
# Then we loop through each framework component in dependency order — the order
# matters because later components link against earlier ones.
RUN --mount=type=cache,target=/digikam-install-deps/download.qt6 \
    set -e && \
    CPU_CORES=$(( $(nproc) - 1 )) && [ "$CPU_CORES" -lt 1 ] && CPU_CORES=1; \
    mkdir -p "$BUILDING_DIR" && \
    cd "$BUILDING_DIR" && \
    rm -rf "$BUILDING_DIR"/* && \
    cmake "$ORIG_WD/3rdparty" \
    -DCMAKE_INSTALL_PREFIX:PATH="$INSTALL_DIR" \
    -DINSTALL_ROOT="$INSTALL_DIR" \
    -DEXTERNALS_DOWNLOAD_DIR="$DOWNLOAD_DIR" \
    -DEXTERNALS_BUILD_DIR="$BUILDING_DIR" \
    -DKA_VERSION="$DK_KA_VERSION" \
    -DKP_VERSION="$DK_KP_VERSION" \
    -DKDE_VERSION="$DK_KDE_VERSION" \
    -Wno-dev && \
    # --- KDE Framework components in dependency order -----------------------
    # The order mirrors FRAMEWORK_COMPONENTS in config.sh. Each component
    # may depend on one or more of the components listed above it.
    for component in \
    ext_extra-cmake-modules \
    ext_kconfig \
    ext_breeze-icons \
    ext_kcoreaddons \
    ext_kwindowsystem \
    ext_solid \
    ext_threadweaver \
    ext_karchive \
    ext_kdbusaddons \
    ext_ki18n \
    ext_kcrash \
    ext_kcodecs \
    ext_kauth \
    ext_kguiaddons \
    ext_kwidgetsaddons \
    ext_kitemviews \
    ext_kcompletion \
    ext_kcolorscheme \
    ext_kconfigwidgets \
    ext_kiconthemes \
    ext_kservice \
    ext_kglobalaccel \
    ext_kxmlgui \
    ext_kbookmarks \
    ext_kimageformats \
    ext_plasma-wayland-protocols \
    ext_knotifications \
    ext_kjobwidgets \
    ext_kio \
    ext_knotifyconfig \
    ext_sonnet \
    ext_ktextwidgets \
    ext_qca \
    ext_kwallet \
    ext_ksanecore \
    ext_libksane \
    ext_kcalendarcore \
    ; do \
    echo "========== Building $component ==========" && \
    cmake --build . --config RelWithDebInfo --target "$component" -- -j"$CPU_CORES" ; \
    done && \
    # Discard build artifacts to save space
    rm -rf "$BUILDING_DIR"/*


# ===========================================================================
# Stage 6: builder — Final clean image for building digiKam
#
# Starts fresh from the base stage (system packages only), then copies in
# just the installed Qt6/KF6 libraries from /opt/qt6. This discards all
# intermediate build artifacts, keeping the image as small as possible.
# ===========================================================================
FROM base AS builder

# Copy only the installed libraries and tools — no build dirs, no downloads
COPY --from=kf6-built /opt/qt6 /opt/qt6

# Make the custom-built tools and libraries visible to CMake and the linker
ENV PATH="/opt/qt6/bin:${PATH}" \
    CMAKE_PREFIX_PATH="/opt/qt6" \
    LD_LIBRARY_PATH="/opt/qt6/lib:/opt/qt6/lib64"

WORKDIR /digikam

# To build digiKam, uncomment the following:
RUN git clone --branch v9.0.0 --depth 1 https://invent.kde.org/graphics/digikam.git .
RUN mkdir build && cd build && \
    /opt/qt6/bin/cmake .. -DCMAKE_INSTALL_PREFIX=/opt/qt6 && \
    make -j$(nproc)
