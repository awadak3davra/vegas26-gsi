# NFC HAL fix (GSI)

On a LineageOS GSI, NFC never comes up on vegas26: `com.android.nfc` ANRs about every 15 s, and `logcat` shows init repeating:

```
init: Could not find 'android.hardware.nfc@1.2::INfc/default' for ctl.interface_start
```

The NXP NFC HAL binary and its init script are in `/vendor` and survive the GSI:

```
/vendor/bin/hw/vendor.nxp.hardware.nfc@1.2-service
/vendor/etc/init/vendor.nxp.hardware.nfc@1.2-service.rc
```

But the service is `disabled` and only started by a property trigger:

```
on property:ro.vendor.hw.nfc=nq && property:persist.vendor.nfc.config_file_name=*
    start vendor.nfc_hal_service
```

`ro.vendor.hw.nfc=nq` is set by the vendor, but `persist.vendor.nfc.config_file_name` is empty on a GSI (on stock a Motorola component sets it). So the trigger never fires, the HAL never registers, and `com.android.nfc` hangs in startup.

## Fix

Set `persist.vendor.nfc.config_file_name` to any valid conf under `/vendor/etc` (e.g. `libnfc-nxp.conf`). The trigger fires, `vendor.nfc_hal_service` starts, the HAL registers, and NFC works:

- `dumpsys nfc` -> `mState=on`
- `lshal` lists `android.hardware.nfc@1.2::INfc/default` and `vendor.nxp.nxpnfc@2.0::INxpNfc/default`
- no more `com.android.nfc` ANR

## This module

A Magisk module that applies it at every boot (`resetprop` in `post-fs-data.sh`, plus `system.prop`). Install it in **Magisk -> Modules -> "+"**, then reboot. It touches nothing else and is reverted by disabling the module.

Zip it and flash from Magisk:

```
cd nfc && zip -r ../vegas-nfc-hal-fix.zip module.prop system.prop post-fs-data.sh
```

Verified on LineageOS 23.2 microG, build `-4-3` vendor (NXP `nq`).
