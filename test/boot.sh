#! /bin/bash
set -eu

make boot >qemu.log 2>&1 &
for delay in 20 20 20 20 20 40 40 40 40 40 100 100 100; do
    sleep "${delay}"
    tail qemu.log | grep -q '^example-host login: ' || continue
    exit 0
done

echo 2>&1 'Timeout, no login prompt'
exit 1
