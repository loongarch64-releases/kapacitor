#!/bin/bash
set -euo pipefail

UPSTREAM_OWNER=influxdata
UPSTREAM_REPO=kapacitor
VERSION="${1}"
echo "   🏢 Org:   ${UPSTREAM_OWNER}"
echo "   📦 Proj:  ${UPSTREAM_REPO}"
echo "   🏷️  Ver:   ${VERSION}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
DISTS="${ROOT_DIR}/dists"
SRCS="${ROOT_DIR}/srcs"
PATCHES="${ROOT_DIR}/patches"

mkdir -p "${DISTS}/${VERSION}" "${SRCS}"

echo "🔧 Compiling ${UPSTREAM_OWNER}/${UPSTREAM_REPO} ${VERSION}..."

# 1. 准备阶段：安装依赖、下载代码、应用补丁等
prepare()
{
    echo "📦 [Prepare] Setting up build environment..."
    
    git clone -b "v${VERSION}" --depth 1 "https://github.com/${UPSTREAM_OWNER}/${UPSTREAM_REPO}.git" "${SRCS}/${VERSION}"
    "${PATCHES}/patch.sh" "${SRCS}/${VERSION}" "${VERSION}"
    
    echo "✅ [Prepare] Environment ready."
}

# 2. 编译阶段：核心构建命令
build()
{
    echo "🔨 [Build] Compiling source code..."
    
    pushd "${SRCS}/${VERSION}"
    export PKG_CONFIG="${SRCS}/${VERSION}/pkg-config.sh"
    export RUSTFLAGS="--cap-lints warn"

    python3 build.py \
      --platform linux \
      --arch loong64 \
      --version ${VERSION} \
      --iteration 1 \
      --package \
      --release \
      --clean \
      --outdir ./build
    popd

    echo "✅ [Build] Compilation finished."
}

# 3. 后处理阶段：整理产物、清理临时文件、验证版本
post_build()
{
    echo "📦 [Post-Build] Organizing artifacts..."
    
    local PRODUCT="${DISTS}/${VERSION}/kapacitor-${VERSION}_linux_loong64.tar.gz"
    local BUILD_OUTPUT="${SRCS}/${VERSION}/build/kapacitor-${VERSION}_linux_loong64.tar.gz"
    cp "${BUILD_OUTPUT}" "${PRODUCT}"
    chown -R "${HOST_UID}:${HOST_GID}" "${DISTS}" "${SRCS}"
    
    echo "✅ [Post-Build] Artifacts ready in ./dists/${VERSION}."
}

# 主入口
main()
{
    prepare
    build
    post_build
}

main


cat > "${DISTS}/${VERSION}/release.txt" <<EOF
Project: ${UPSTREAM_REPO}
Organization: ${UPSTREAM_OWNER}
Version: ${VERSION}
Build Time: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

echo "✅ Compilation finished."
ls -lh "${DISTS}/${VERSION}"
