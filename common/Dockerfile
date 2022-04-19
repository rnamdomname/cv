FROM fedora:35 as Build

RUN dnf install -y --setopt=install_weak_deps=False --best \
    qemu-system-x86-core hostname
RUN pkg="$(dnf install -y --setopt=install_weak_deps=False --best unzip \
      p7zip-plugins gcab cpio findutils aria2 jq genisoimage qemu-img xmlstarlet )" && \
    echo "$(echo $pkg | sed 's/Installed:/\n/g' | sed -z 's/Complete!//g' | sed -n '2 p')" > /opt/pkg



ARG VIRTIO_OS
ARG VIRTIO_ARCH

ENV P=5555                    \
CONFIG_DIR="/config_iso"       \
VMDISK="/opt/vm.qcow2"          \
CONFIG_ISO="/opt/config.iso"     \
DRIVERS_DIR="/config_iso/drivers" \
DOWNLOAD_DIR="/config_iso/toinstall" \
INSTALL_LIST="/config_iso/install.json"
COPY . /
RUN touch /tmp/stage1 && bash -c "source /build.sh; main" && rm -rf /tmp/stage1

ENTRYPOINT ["/bin/bash", "/start.sh"]


