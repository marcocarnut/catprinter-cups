#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Install the YHK cat printer CUPS driver and create a print queue.
# Usage: sudo ./install.sh [BLUETOOTH_ADDRESS|auto] [QUEUE_NAME]
#   With no address (or "auto"), nearby YHK-XXXX printers are searched for.
set -e

ADDR=${1:-auto}
QUEUE=${2:-CatPrinter}
CHANNEL=2
HERE=$(cd "$(dirname "$0")" && pwd)

if [ "$(id -u)" != 0 ]; then
    echo "Run as root: sudo $0 $*" >&2
    exit 1
fi

if [ "$ADDR" = auto ]; then
    echo "Searching for YHK printers (make sure yours is switched on)..."
    FOUND=$("$HERE/btspp" 2>/dev/null | grep '^direct btspp://' || true)
    COUNT=$(printf '%s' "$FOUND" | grep -c . || true)
    if [ "$COUNT" -eq 0 ]; then
        echo "No printer found. Switch it on and retry, or give its address:" >&2
        echo "  sudo $0 24:00:04:00:21:B8" >&2
        exit 1
    fi
    if [ "$COUNT" -gt 1 ]; then
        echo "Found several printers; run again with the address of one:" >&2
        printf '%s\n' "$FOUND" | sed 's/^direct \([^ ]*\) .*"\(YHK-[^ ]*\) .*/  \2  \1/' >&2
        exit 1
    fi
    URI=$(printf '%s' "$FOUND" | cut -d' ' -f2)
else
    # CUPS does not allow colons in the URI host part
    URI="btspp://$(echo "$ADDR" | tr -d : | tr a-f A-F)/$CHANNEL"
fi

install -m 0755 -o root -g root "$HERE/rastertoyhk" /usr/lib/cups/filter/rastertoyhk
install -m 0755 -o root -g root "$HERE/btspp" /usr/lib/cups/backend/btspp
install -d /usr/share/ppd/yhk
install -m 0644 "$HERE/yhk-catprinter.ppd" /usr/share/ppd/yhk/yhk-catprinter.ppd

lpadmin -p "$QUEUE" -E \
    -v "$URI" \
    -P /usr/share/ppd/yhk/yhk-catprinter.ppd \
    -D "YHK cat thermal printer" \
    -o print-scaling-default=fit

echo "Queue '$QUEUE' created for $URI."
echo "Try:  lp -d $QUEUE some-image.png"
