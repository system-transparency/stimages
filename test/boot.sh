#! /bin/bash
set -eu

$@ >qemu.log 2>&1 &

function cleanup() {
    [[ ! -f qemu.pid ]] || kill "$(cat qemu.pid)"
    rm -f qemu.pid
}
trap cleanup EXIT

for delay in 20 2 2 2 2 2 30; do # 1 minute in total
    sleep "${delay}"
    tail qemu.log | grep -q '^amnesiac-debian login: ' || continue
    exit 0
done

echo 2>&1 'Timeout, no login prompt'
exit 1
