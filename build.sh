#!/bin/bash

export MAKEFLAGS="-j$(nproc)"

# WITH_UPX=1

platform="$(uname -s)"
platform_arch="$(uname -m)"

if [ -x "$(which apt 2>/dev/null)" ]
    then
        apt update && apt install -y \
            build-essential clang pkg-config git squashfs-tools fuse \
            libzstd-dev liblz4-dev liblzo2-dev liblzma-dev zlib1g-dev \
            libfuse-dev libsquashfuse-dev libsquashfs-dev autoconf \
            libtool upx libfuse3-dev cmake
fi

if [ -d build ]
    then
        echo "= removing previous build directory"
        rm -rf build
fi

if [[ -d release_fuse2 || -d release_fuse3 ]]
    then
        echo "= removing previous release directory"
        rm -rf release_fuse2 release_fuse3
fi

# create build and release directory
mkdir build
mkdir release_fuse2
mkdir release_fuse3
pushd build

# download unionfs-fuse
git clone https://github.com/rpodgorny/unionfs-fuse
unionfs_fuse_version="$(cd unionfs-fuse && git describe --long --tags|sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g')"
# unionfs_fuse_version="$(cd unionfs-fuse && git tag --list|tac|grep '^[0-9]'|head -1|sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g')"
mv unionfs-fuse "unionfs-fuse-${unionfs_fuse_version}"
echo "= downloading unionfs-fuse v${unionfs_fuse_version}"

if [ "$platform" == "Linux" ]
    then
        NEWLDFLAGS='--static'
    else
        echo "= WARNING: your platform does not support static binaries."
        echo "= (This is mainly due to non-static libc availability.)"
fi

echo "= building unionfs-fuse"
pushd unionfs-fuse-${unionfs_fuse_version}
(mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXE_LINKER_FLAGS="$NEWLDFLAGS" -DWITH_LIBFUSE3=FALSE
make DESTDIR="$(pwd)/../install2" install
make clean
echo "= building unionfs-fuse3"
rm -rf CMake*
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXE_LINKER_FLAGS="$NEWLDFLAGS"
make DESTDIR="$(pwd)/../install3" install)

popd # unionfs-fuse-${unionfs_fuse_version}
popd # build

shopt -s extglob

echo "= extracting unionfs-fuse binary"
mv build/unionfs-fuse-${unionfs_fuse_version}/install2/usr/local/bin/* release_fuse2 2>/dev/null
mv build/unionfs-fuse-${unionfs_fuse_version}/install3/usr/local/bin/* release_fuse3 2>/dev/null

echo "= striptease"
for file in release_fuse2/*
  do
      strip -s -R .comment -R .gnu.version --strip-unneeded "$file" 2>/dev/null
done
for file in release_fuse3/*
  do
      strip -s -R .comment -R .gnu.version --strip-unneeded "$file" 2>/dev/null
done

if [[ "$WITH_UPX" == 1 && -x "$(which upx 2>/dev/null)" ]]
    then
        echo "= upx compressing"
        for file in release_fuse2/*
          do
              upx -9 --best "$file" 2>/dev/null
        done
        for file in release_fuse3/*
          do
              upx -9 --best "$file" 2>/dev/null
        done
fi

echo "= create release tar.xz"
tar --xz -acf unionfs-fuse-static-v${unionfs_fuse_version}-${platform_arch}.tar.xz release_fuse*
# cp unionfs-fuse-static-*.tar.xz /root 2>/dev/null

if [ "$NO_CLEANUP" != 1 ]
    then
        echo "= cleanup"
        rm -rf release_fuse2 release_fuse3 build
fi

echo "= unionfs-fuse v${unionfs_fuse_version} done"
