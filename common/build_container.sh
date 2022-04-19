#!/bin/bash
set -Eeuo pipefail
set -o nounset
set -o errexit
shopt -s extglob

declare ISO_DIR
declare VMMEM
declare INSTALL_ISO
declare VIRTIO_OS
declare VIRTIO_ARCH

#######################################
#
#######################################
build_container() {
  local tag="$1"
  local BUILD_DIR="build"
  mkdir -p "${BUILD_DIR}"
  cp -r !(build|build_container.sh) "${BUILD_DIR}/"
  cp -r ../common/!(build_container.sh) "${BUILD_DIR}/"
  (
    cd "${BUILD_DIR}"
    mv build.sh _build.sh
    cat _build.sh build.override.sh >build.sh && rm -f _build.sh

    # NOTE: for w7 last working is virtio-0.1.173-2
    docker build --build-arg "VIRTIO_OS=${VIRTIO_OS}" --build-arg "VIRTIO_ARCH=${VIRTIO_ARCH}" \
      -t "modernie:${tag}" .


    docker container create --name "moderniebuild${tag}" --rm -e "STAGE2=2" -e "VMMEM=${VMMEM}" \
      -e "INSTALL_ISO=${INSTALL_ISO}" \
      --device=/dev/kvm -v "${ISO_DIR}:/vm:ro" "modernie:${tag}"
    docker container start "moderniebuild${tag}"
    while true; do
      set +e
      docker container cp "moderniebuild${tag}:/opt/built" "$PWD" > /dev/null 2>&1
      if [[ $? == 0 ]];then
        break
        set -e
      fi
      sleep 10
    done;
    docker container commit "moderniebuild${tag}" -t "modernie:${tag}"
    docker container stop "moderniebuild${tag}"
    docker container rm "moderniebuild${tag}"
  )
  rm -rf "${BUILD_DIR}"
}
