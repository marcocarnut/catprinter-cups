# catprinter-cups

A CUPS driver for a cheap cat-shaped Bluetooth thermal label printer, sold
with the **iPrint** / **WalkPrint** Android apps, that advertises itself as
`YHK-XXXX` and takes 54 mm (adhesive) thermal paper rolls.

Once installed, the printer is a normal Linux printer: print PNGs, PDFs or
QR codes from any application or with `lp`.

> [!WARNING]
> **This driver has been tested on exactly one model, a `YHK-21B8`.**
> "Cat printers" are sold under many brands and app names. Units that look
> identical on the outside often have completely different insides:
> different Bluetooth chips, services and command protocols. Don't assume
> yours will work because it looks the same. Use the checks below first.
> Reports of other models that do or don't work are very welcome.

## Is this my printer?

The model this was written for:

- appears in a Bluetooth scan as **`YHK-` + the last 4 hex digits of its
  address**, and
- offers a classic Bluetooth serial port called **`JL_SPP`** (a JieLi chip).

Check with (replace the address with yours):

    bluetoothctl scan on                          # look for YHK-XXXX
    sdptool search --bdaddr 24:00:04:00:21:B8 SP  # look for JL_SPP, note the Channel

**Signs that this driver won't work for your printer:**

- It exposes the BLE service `0000ae30-…`.
- It speaks the `51 78 …` protocol described in
  [werwolv's write-up](https://werwolv.net/blog/cat_printer/).

Those are a different family; see the projects under [Credits](#credits).

If your printer passes the checks, it may still behave differently in the
details, such as head width, RFCOMM channel or supported commands. See
[How the printer works](#how-the-printer-works) for what this driver relies on.

## Install

Needs CUPS and Python 3; there are no other dependencies.

    git clone https://github.com/marcocarnut/catprinter-cups
    cd catprinter-cups
    sudo ./install.sh 24:00:04:00:21:B8 CatPrinter

This installs the filter, backend and PPD and creates a queue called
`CatPrinter`. No Bluetooth pairing is needed. Just switch the printer on.

The script assumes RFCOMM channel 2. If `sdptool` reported a different
channel, edit `CHANNEL=` in `install.sh` first.

To remove everything: `sudo ./uninstall.sh CatPrinter`.

## Printing

    lp -d CatPrinter photo.jpg
    lp -d CatPrinter -o Dither=Threshold qr.png
    lp -d CatPrinter -o media=Label48x30mm label.pdf
    lp -d CatPrinter -o media=Custom.48x70mm poster.png
    qrencode -s 10 -o - 'https://example.com' | lp -d CatPrinter -o Dither=Threshold

Images are scaled to fit the label by default.

### Options

List them with `lpoptions -p CatPrinter -l`; make one permanent with
e.g. `lpoptions -p CatPrinter -o FeedAfter=12mm`.

| Option | Values | Default |
|---|---|---|
| `PageSize` / `media` | `Label48x20mm`, `…30mm`, `…40mm`, `…48mm`, `…50mm`, `…60mm`, `…80mm`, `…100mm`, or `Custom.48xNNmm` | `Label48x48mm` (square, handy for QR codes) |
| `Dither` | `FloydSteinberg` (photos), `Threshold` (text, QR codes) | `FloydSteinberg` |
| `FeedAfter` | blank paper after the job so it clears the tear bar: `0mm`–`40mm` | `10mm` |
| `PageGap` | blank paper between labels of one job: `0mm`–`16mm` | `4mm` |

Page sizes are the **printable area**, 48 mm wide on the 54 mm roll, so what
you design is what prints.

## How the printer works

These findings come from probing the `YHK-21B8`. Other units may differ.

- **Dual-mode Bluetooth.** Classic SPP (`JL_SPP`) on **RFCOMM channel 2**, plus
  a BLE "transparent UART" service (`49535343-fe7d-…`, Microchip/ISSC style).
  Neither needs pairing.
  - Desktop Bluetooth managers (Blueman, GNOME) fail to "connect" because
    there's no pairing and no audio or input profile.
  - BLE libraries such as bleak fail with `br-connection-profile-unavailable`,
    because BlueZ prefers the classic link for dual-mode devices.

  This driver uses the classic serial link.
- **ESC/POS, but only a small subset of it.**
  - It answers `DLE EOT n` status queries.
  - It prints `GS v 0` raster images at **384 dots per row** (48 mm at
    8 dots/mm, 203 dpi).
  - It has **no built-in font**: text is ignored, so everything is sent as an
    image.
  - It **ignores paper-feed commands** (`ESC J`, `ESC d`, LF). The only way to
    move the paper is to print blank rows, so that's what the driver does.
  - It **ignores heat and density commands** (`ESC 7`, `DC2 #`).
- **Darkness depends on how many dots a row heats at once.**
  - Text, line art and QR codes print solid black.
  - Wide solid areas come out patchy grey, likely because the head's current
    is limited.
  - A full battery (or USB power) and fresh paper help noticeably.
- **The tear bar is about 8 mm past the print head**, hence the 10 mm
  default `FeedAfter`.
- The printer buffers incoming data and finishes printing even after the
  Bluetooth link drops. Its status reply arrives as soon as the data is
  received, not when printing ends.

## Files

| File | Installed to | Purpose |
|---|---|---|
| `rastertoyhk` | `/usr/lib/cups/filter/` | CUPS raster → ESC/POS raster, with dithering (Python 3, standard library only) |
| `btspp` | `/usr/lib/cups/backend/` | Bluetooth SPP backend, URI `btspp://2400040021B8/2` (address without colons / RFCOMM channel) |
| `yhk-catprinter.ppd` | `/usr/share/ppd/yhk/` | page sizes and options |

`btspp` is generic. It sends a job to any Bluetooth serial printer, so it
may be useful on its own.

## Testing without installing

    cupsfilter -p yhk-catprinter.ppd -m application/vnd.cups-raster \
        -o print-scaling=fit image.png > page.ras
    PPD=$PWD/yhk-catprinter.ppd ./rastertoyhk 1 me t 1 "" page.ras > page.bin
    DEVICE_URI=btspp://2400040021B8/2 ./btspp 1 me t 1 "" page.bin

## Troubleshooting

- **Job stays in "connecting to device".** Check that the printer is on and
  in range. It may also be connected to a phone: close the app, or turn off
  the phone's Bluetooth.
- **Wrong RFCOMM channel.** Run `sdptool search --bdaddr <addr> SP` to find
  it, then `sudo lpadmin -p CatPrinter -v btspp://<ADDR-NO-COLONS>/<channel>`.
- **"Printer drivers are deprecated"** from `lpadmin` is only a warning.
  CUPS 2.x fully supports PPD drivers.
- Logs: `journalctl -u cups` or `/var/log/cups/error_log`. To see more,
  enable debug logging with `sudo cupsctl --debug-logging`.

## Credits

- [werwolv's cat printer write-up](https://werwolv.net/blog/cat_printer/)
  reverse-engineers a BLE cousin of this printer and was the starting point.
- [catteprinter](https://github.com/the6P4C/catteprinter) and its Python
  port [PyCatte](https://github.com/JJJollyjim/PyCatte) implement that BLE
  protocol.

## License

GPL-3.0-or-later, see [LICENSE](LICENSE).
