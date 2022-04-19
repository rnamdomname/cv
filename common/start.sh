#!/bin/bash
export USER=root
set -Eeuo pipefail
set -o nounset
set -o errexit


if [ $STAGE2 ]; then
    source /build.sh
    main
    exit
fi


d() {
  date "+%m/%d %T"
}
if [ ! -e /dev/kvm ]; then
    printf "%s [\e[38;5;220m WARN \e[0m] Container needs KVM to run faster\n" "$(d)"
fi

printf "%s [\e[94mINFO\e[0m] Run Windows VM \n" "$(d)"
qemu-system-x86_64 -smbios type=1,serial="$(hostname -I)_$P" \
    -enable-kvm -smp $(nproc) -cpu host -pidfile /tmp/guest.pid \
    -drive file="$VMDISK",if=virtio \
    -net nic,model=virtio-net-pci \
    -net user,hostfwd=tcp::2222-:22,hostfwd=tcp::3389-:3389,hostfwd=tcp::$PORT-:$PORT \
    -m $VMMEM -usb -device usb-ehci,id=ehci -device usb-tablet \
    -snapshot