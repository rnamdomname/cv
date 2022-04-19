#!/bin/sh
set -Eeuo pipefail
set -o nounset
set -o errexit


source ../common/build_container.sh

ISO_DIR="/test/"
VMMEM=2048
INSTALL_ISO="/vm/GRMCENEVAL_EN_DVD.iso"
VIRTIO_OS="w7"
VIRTIO_ARCH="x86"

build_container "w7"
