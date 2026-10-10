#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Install the YHK cat printer CUPS driver and create a print queue.
# Usage: sudo ./install.sh [BLUETOOTH_ADDRESS] [QUEUE_NAME]
set -e

ADDR=${1:-24:00:04:00:21:B8}
QUEUE=${2:-CatPrinter}
CHANNEL=2
# CUPS does not allow colons in the URI host part
URIADDR=$(echo "$ADDR" | tr -d : | tr a-f A-F)
HERE=$(cd "$(dirname "$0")" && pwd)

if [ "$(id -u)" != 0 ]; then
    echo "Run as root: sudo $0 $*" >&2
    exit 1
fi

install -m 0755 -o root -g root "$HERE/rastertoyhk" /usr/lib/cups/filter/rastertoyhk
install -m 0755 -o root -g root "$HERE/btspp" /usr/lib/cups/backend/btspp
install -d /usr/share/ppd/yhk
install -m 0644 "$HERE/yhk-catprinter.ppd" /usr/share/ppd/yhk/yhk-catprinter.ppd

lpadmin -p "$QUEUE" -E \
    -v "btspp://$URIADDR/$CHANNEL" \
    -P /usr/share/ppd/yhk/yhk-catprinter.ppd \
    -D "YHK cat thermal printer" \
    -o print-scaling-default=fit

echo "Queue '$QUEUE' created for $ADDR (RFCOMM channel $CHANNEL)."
echo "Try:  lp -d $QUEUE some-image.png"
