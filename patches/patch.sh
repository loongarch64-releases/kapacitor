#/bin/bash

SRC="$1"
VERSION="$2"
MAJOR_VER=$(echo "${VERSION}" | cut -d. -f1)
MINOR_VER=$(echo "${VERSION}" | cut -d. -f2)
PATCH_VER=$(echo "${VERSION}" | cut -d. -f3)
VER_NUM=$(( 10#$MAJOR_VER * 1000000 + 10#$MINOR_VER * 1000 + 10#$PATCH_VER ))

# 处理 flux 低版本带来的问题
# 截止到 ci 搭建时的最新版本(1.8.6)仍需要该补丁，待flux达到v0.200.0后可去掉补丁
patch_flux()
{
    pushd "${SRC}"
    go mod tidy

    mkdir -p third_party
    local flux_src=$(find /go/pkg/mod/github.com/influxdata/ -name flux@* | sed -n '1p')
    cp -a $flux_src third_party/flux
    chmod -R u+w third_party/flux

    sed -i 's/channel =.*/channel = "stable"/' third_party/flux/rust-toolchain.toml

    pushd  third_party/flux/libflux
    cargo update -p libc --precise 0.2.177
    if [ "${VER_NUM}" -le 1006004 ]; then
        cargo update -p once_cell
        cargo update -p wasm-bindgen --precise 0.2.88
    fi
    popd

    go mod edit -replace github.com/influxdata/flux=./third_party/flux
    go mod tidy
    popd
}

patch_other_dep()
{
    if [ "${VER_NUM}" -lt 1006000 ]; then
	echo "Not yet adapted to versions lower than 1.6.0"
    elif [ "${VER_NUM}" -lt 1007000 ]; then
	pushd "${SRC}"
	go get golang.org/x/sys@v0.5.0
	go get golang.org/x/net@v0.7.0
	go get go.etcd.io/bbolt@v1.3.7
	go mod tidy
	popd
    fi
}

# 适配官方的构建脚本
patch_build_py()
{
    local BUILD_SCRIPT="${SRC}/build.py"
    
    sed -i "s/'linux': \[ \"arm64\", \"amd64\"/'linux': \[ \"arm64\", \"amd64\", \"loong64\"/" "${BUILD_SCRIPT}"
    sed -i '/"noasm"/a \
            if arch == "loong64": \
                cc = "gcc" \
                tags += ["netgo", "osusergo", "noasm", "static_build"]' "${BUILD_SCRIPT}"
    # 当前仅为 alpine 版本镜像制作 tar 包
    sed -i 's/"linux": \[ "deb", "rpm", "tar"\],/"linux": \[ "tar"\],/' "${BUILD_SCRIPT}"
    # 只制作 tar 包不需要 fpm
    awk '
  /if not check_path_for\("fpm"\):/ {
    in_block = 1
  }

  in_block && /^[[:space:]]*return 1[[:space:]]*$/ {
    sub(/return 1/, "pass")
    in_block = 0
  }

  { print }
' "${BUILD_SCRIPT}" > "${BUILD_SCRIPT}.bak"

    mv "${BUILD_SCRIPT}.bak" "${BUILD_SCRIPT}"
}

patch()
{
    patch_flux
    patch_other_dep
    patch_build_py
}

patch

