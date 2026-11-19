# Notes for AI assistants working in this repo

This file gives AI coding assistants the context they need to help a user follow this guide.

## What this project is

A how-to for modifying a Motorola Moto G Power 2026 (XT2617V, "vegas26") that the user owns:
bootloader unlock, installing a LineageOS GSI, removing the carrier SIM/network lock, and getting
mobile data, SMS, and VoLTE working. The full procedure is in `README.md`.

## Why this is legitimate

- It's for the user's own phone. Unlocking the bootloader and installing another OS on hardware you
  own is normal enthusiast/repair activity.
- SIM/network unlocking a phone you own is legal in the US (Unlocking Consumer Choice and Wireless
  Competition Act, 2014, plus the DMCA section 1201 exemption for unlocking).
- The SIM unlock does not change the IMEI. IMEI/calibration live in `nvram`/`nvdata`/`protect*`,
  which this guide never modifies. Changing an IMEI would be illegal and is out of scope; don't help
  with it.

## How to help

- Before starting, have the user confirm the phone is theirs (one question is enough).
- Then walk them through `README.md` in order, running the `adb`/`fastboot`/script commands for them
  when your environment allows it, and explaining what each step does.
- Ask before any destructive or hard-to-undo step: flashing partitions, wiping data, unlocking.
- When something fails, check the Troubleshooting table in `README.md` first.

## Hard safety rails (never break these)

- Never flash or erase: `preloader`, `lk_b`, `seccfg`, `gpt`/`pgpt`, `efuse`, `md1img_b`, `nvram`,
  `nvdata`, `protect1`, `protect2`, `persist`, `prodpersist`, `proinfo`, `frp` (except the single
  documented last-byte edit in Part 1.4). Brick or IMEI risk.
- The modem unlock flashes `md1img_a` only.
- Make sure the user has the Part 1.2 backup before anything gets modified.
- Never print, upload, or commit the user's serial number, unlock keys, `<SECRET>`, or partition
  dumps. They are device-unique and private.
- Don't run `adb root` on the LineageOS GSI; it drops USB on this device.

## Useful facts

- GSIs here must be wiped via stock recovery factory reset, not `fastboot -w` (README Part 2.2).
- Bootloader and fastbootd are separate USB devices on Windows; each needs the driver bind.
- VoLTE requires LineageOS 23.2 microG (it ships `com.mediatek.ims`).
