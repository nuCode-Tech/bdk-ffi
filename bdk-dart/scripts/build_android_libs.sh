#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build_android_libs.sh [--dest /path/to/jniLibs]

Builds the BDK FFI shared libraries for all Android ABIs and copies them
into the provided JNI libs directory (defaults to the Flutter plugin's
`android/src/main/jniLibs`).

The script relies on the `release-smaller` profile, which sets `strip =
"debuginfo"` so that the exported Uniffi symbols remain available while
debug information is removed.
EOF
  exit 1
}

DEST_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Missing value for --dest"
        usage
      fi
      DEST_DIR="$1"
      shift
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BDK_DART_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_DEST="$(cd "${BDK_DART_DIR}/../bdk-flutter/android/src/main/jniLibs" && pwd)"
DEST_DIR="${DEST_DIR:-$DEFAULT_DEST}"

if [[ -z "$ANDROID_NDK_ROOT" ]]; then
  echo "ANDROID_NDK_ROOT is not set"
  exit 1
fi

OS="$(uname -s)"
case "${OS}" in
  Darwin*) HOST_TAG="darwin-x86_64" ;;
  Linux*) HOST_TAG="linux-x86_64" ;;
  *)
    echo "Unsupported OS: ${OS}"
    exit 1
    ;;
esac

NDK_BIN_DIR="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${HOST_TAG}/bin"
export PATH="${NDK_BIN_DIR}:$PATH"

LIB_NAME="libbdkffi.so"
declare -A TARGET_TO_ABI=(
  [aarch64-linux-android]="arm64-v8a"
  [x86_64-linux-android]="x86_64"
  [armv7-linux-androideabi]="armeabi-v7a"
)
declare -A TARGET_TO_CC=(
  [aarch64-linux-android]="aarch64-linux-android24-clang"
  [x86_64-linux-android]="x86_64-linux-android24-clang"
  [armv7-linux-androideabi]="armv7a-linux-androideabi24-clang"
)
declare -A TARGET_TO_LINKER=(
  [aarch64-linux-android]="CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER"
  [x86_64-linux-android]="CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER"
  [armv7-linux-androideabi]="CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_LINKER"
)

RUST_DIR="$(cd "${BDK_DART_DIR}/../bdk-ffi" && pwd)"
if [[ ! -f "${RUST_DIR}/Cargo.toml" ]]; then
  echo "Could not locate bdk-ffi Cargo.toml. Searched from ${RUST_DIR}"
  exit 1
fi

echo "Building Android shared libraries in ${RUST_DIR}"
cd "${RUST_DIR}"

echo "Ensuring Rust has the Android targets..."
rustup target add aarch64-linux-android x86_64-linux-android armv7-linux-androideabi >/dev/null

for target in "${!TARGET_TO_ABI[@]}"; do
  cc="${TARGET_TO_CC[$target]}"
  linker_env="${TARGET_TO_LINKER[$target]}"
  echo "Building ${target} (${TARGET_TO_ABI[$target]})..."
  env CC="${cc}" "${linker_env}=$cc" cargo build --package bdk-ffi --profile release-smaller --target "${target}"
done

echo "Copying libraries into ${DEST_DIR}"
for target in "${!TARGET_TO_ABI[@]}"; do
  abi="${TARGET_TO_ABI[$target]}"
  dest="${DEST_DIR}/${abi}"
  mkdir -p "${dest}"
  rm -f "${dest}/${LIB_NAME}"
  cp "./target/${target}/release-smaller/${LIB_NAME}" "${dest}/"
done

echo "Android binaries are ready in ${DEST_DIR}"
