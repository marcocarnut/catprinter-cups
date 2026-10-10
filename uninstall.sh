#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Remove the print queue and the driver files installed by install.sh.
# Usage: sudo ./uninstall.sh [QUEUE_NAME]
QUEUE=${1:-CatPrinter}
lpadmin -x "$QUEUE" 2>/dev/null
rm -f /usr/lib/cups/filter/rastertoyhk /usr/lib/cups/backend/btspp
rm -rf /usr/share/ppd/yhk
