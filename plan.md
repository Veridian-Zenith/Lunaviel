# Lunaviel Core Kernel: Comprehensive Development Plan

**Project:** Lunaviel Core Kernel  
**Target Hardware:** HP ProBook 450 G9 (12th Gen Intel Core i3-1215U, Alder Lake-U, NVMe SSD, Intel UHD Graphics, Realtek WiFi/Ethernet, SOF Audio, etc.)  
**Language:** Rust 2024, `#![no_std]`, UEFI-first  
**Date:** June 18, 2025

---

## Hardware Platform: HP ProBook 450 G9 (Alder Lake-U)

### CPU
- **Model:** 12th Gen Intel Core i3-1215U (Alder Lake-U)
- **Cores/Threads:** 6 cores, 8 threads (2 P-cores, 4 E-cores)
- **PCI ID:** 8086:4609 (Host bridge)
- **Features:** AVX2, AVX_VNNI, SHA, FSGSBASE, UMIP, PKU, VT-x, x2APIC, etc.
- **L1d/L1i/L2/L3 Cache:** 224 KiB / 320 KiB / 4.5 MiB / 10 MiB

### Chipset
- **Platform:** Intel Alder Lake-U (PCH)
- **PCI Devices:**
    - 00:02.0 VGA: Intel Alder Lake-UP3 GT1 [UHD Graphics] (8086:46b3)
    - 00:0d.0 USB: Intel Alder Lake-P Thunderbolt 4 USB Controller (8086:461e)
    - 00:14.0 USB: Intel Alder Lake PCH USB 3.2 xHCI Host Controller (8086:51ed)
    - 00:1f.3 Audio: Intel Alder Lake PCH-P High Definition Audio Controller (8086:51c8)
    - 00:1e.0 UART: Intel Alder Lake PCH UART #0 (8086:51a8)
    - 00:1f.4 SMBus: Intel Alder Lake PCH-P SMBus Host Controller (8086:51a3)
    - 00:1f.5 SPI: Intel Alder Lake-P PCH SPI Controller (8086:51a4)
    - 00:08.0 GNA: Intel Gaussian & Neural Accelerator (8086:464f)
    - 00:04.0 Signal: Innovation Platform Framework Processor (8086:461d)
    - 00:14.2 RAM: Shared SRAM (8086:51ef)

### Storage
- **NVMe SSD:** KIOXIA KBG50ZNV256G (PCI ID: 1e0f:000c, 238.5GB, /dev/nvme0n1)
- **External USB:** Toshiba America Inc UAS Controller (0480:a006)

### Network
- **WiFi:** Realtek RTL8852BE PCIe 802.11ax (10ec:b852)
- **Ethernet:** Realtek RTL8111/8168/8411 PCIe Gigabit (10ec:8168)

### Audio
- **Codec:** Intel Alder Lake PCH-P High Definition Audio (8086:51c8)
- **Inputs:** Internal Mic, Headset Mic, HDMI/DP
- **Outputs:** Speakers, Headphones, HDMI/DP

### Camera
- **Webcam:** Quanta HP HD Camera (USB 0408:5483)

### Bluetooth
- **Adapter:** Realtek Bluetooth Radio (USB 0bda:b85c)

### Input
- **Touchpad:** Synaptics SYNA30E5 (I2C 06CB:CEAC)
- **Keyboard:** AT Translated Set 2
- **Hotkeys:** HP WMI hotkeys (ACPI/WMI)

### Power & Sensors
- **Battery:** Smart battery, design 4059 mAh, last full 3448 mAh
- **Thermal:** Multiple sensors, trip points, cooling devices
- **ACPI:** S3/S4, power, lid, sleep, etc.

### USB/Thunderbolt
- **Thunderbolt 4:** Intel Alder Lake-P (8086:461e)
- **USB 3.2:** Intel PCH (8086:51ed)

---

## Timeline & Status (as of June 18, 2025)

| Step | Area | Status | Target/ETA | Notes |
|------|------|--------|------------|-------|
| 1 | Project structure, build, UEFI | ✅ Complete | 2025-06-10 | Rust 2024, UEFI, linker, xbuild, QEMU |
| 2 | Core arch (paging, GDT, IDT, APIC, heap) | ✅ Complete | 2025-06-12 | SMP-ready, frame allocator, panic/alloc handlers |
| 3 | Driver framework & registry | ✅ Complete | 2025-06-13 | Trait-based, modular, hotplug-ready |
| 4 | PCI enumeration | ⏳ In Progress | 2025-06-19 | Next up: device detection, config space |
| 5 | NVMe SSD driver (KIOXIA KBG50ZNV256G, 1e0f:000c) | ⏳ In Progress | 2025-06-20 | Async/block, DMA |
| 6 | Ethernet (RTL8111/8168/8411, 10ec:8168) | ⏳ In Progress | 2025-06-21 | PCIe, NAPI, power mgmt |
| 7 | WiFi (RTL8852BE, 10ec:b852) | ⏳ In Progress | 2025-06-22 | PCIe, firmware, WPA3 |
| 8 | Audio (Intel SOF, 8086:51c8) | ⏳ In Progress | 2025-06-23 | PCI, HDA, SOF firmware |
| 9 | Camera (Quanta, 0408:5483) | ⏳ In Progress | 2025-06-23 | USB UVC, 1080p |
| 10 | Bluetooth (Realtek, 0bda:b85c) | ⏳ In Progress | 2025-06-24 | USB, BLE, HCI |
| 11 | Hotkeys (HP WMI, ACPI/WMI) | ⏳ In Progress | 2025-06-24 | Event routing |
| 12 | USB/xHCI/Thunderbolt (8086:461e/51ed) | ⏳ In Progress | 2025-06-25 | PCIe, hotplug, power |
| 13 | ACPI, battery, thermal, power | ⏳ In Progress | 2025-06-25 | S3/S4, battery, cooling |
| 14 | Graphics (Intel UHD, 8086:46b3, Vulkan/DRM) | ⏳ In Progress | 2025-06-26 | Vulkan, KMS, multi-head |
| 15 | Filesystem: LunaFS (custom, NVMe-optimized) | ⏳ In Progress | 2025-06-27 | CoW, checksummed, compressed |
| 16 | FAT for UEFI boot | ⏳ In Progress | 2025-06-27 | Minimal, for boot only |
| 17 | Logging, diagnostics | ⏳ In Progress | 2025-06-28 | Serial, UEFI, file |
| 18 | Scheduler/process mgmt | ⏳ In Progress | 2025-06-29 | SMP, async, priorities |
| 19 | Syscall interface | ⏳ In Progress | 2025-06-30 | x86_64, extensible |
| 20 | Userland loader | Planned | 2025-07-01 | ELF64, dynamic |
| 21 | Automated QEMU build/test | Planned | 2025-07-01 | CI, scripts |
| 22 | Hardware bring-up | Planned | 2025-07-02 | On-device, debug |

---

## Detailed Steps

### 1. Project Structure & Build System
- Modular Rust workspace, UEFI-first, linker, build.rs, `.cargo/config.toml` for cross.
- QEMU and ISO build scripts, OVMF/EFI support.

### 2. Core Architecture
- x86_64: GDT, IDT, paging, APIC, SMP, heap, panic/alloc handlers.
- Memory: Frame allocator, heap, virtual memory, page tables.

### 3. Driver Framework
- Trait-based, registry, hotplug, async/event support.
- Unified error handling, capability flags.

### 4. Device Drivers (with explicit hardware mapping)
- **PCI:** Full bus scan, config space, BARs, IRQ routing. Detect all devices listed above by PCI ID.
- **NVMe SSD:** KIOXIA KBG50ZNV256G (1e0f:000c), async/block, DMA, queue pairs.
- **Ethernet:** Realtek RTL8111/8168/8411 (10ec:8168), PCIe, NAPI, power mgmt.
- **WiFi:** Realtek RTL8852BE (10ec:b852), PCIe, firmware, WPA3, scanning.
- **Audio:** Intel SOF (8086:51c8), PCI, HDA, SOF firmware, multi-stream.
- **Camera:** Quanta HP HD Camera (0408:5483), USB UVC, 1080p, MJPEG/YUY2.
- **Bluetooth:** Realtek (0bda:b85c), USB, BLE, HCI, pairing.
- **Hotkeys:** HP WMI, ACPI/WMI, event routing, lid/power.
- **USB/xHCI/Thunderbolt:** Intel Alder Lake-P (8086:461e/51ed), PCIe, hotplug, power, device tree.
- **ACPI/Battery/Thermal:** S3/S4, battery, cooling, sensors, smart battery.
- **Graphics:** Intel UHD (8086:46b3), Vulkan, DRM/KMS, multi-head, framebuffer, Wayland-ready.
- **Touchpad:** Synaptics SYNA30E5 (I2C 06CB:CEAC), multitouch, gestures.

### 5. Filesystem
- **LunaFS:** Custom, NVMe-optimized, copy-on-write, checksummed, compressed, async IO, snapshots, journaling.
- **FAT:** Minimal, for UEFI boot partition only.

### 6. System Services
- Logging: Serial, UEFI, file, ring buffer.
- Scheduler: SMP, async, priorities, round-robin.
- Syscalls: x86_64, extensible, user/kernel separation.
- Userland loader: ELF64, dynamic linking (future).

### 7. Testing & Integration
- Automated build, QEMU boot, CI.
- Hardware bring-up, debug, diagnostics.

---

## Current Status (as of June 18, 2025)
- **Core architecture, build, and driver framework:** Complete
- **Driver skeletons for all major hardware:** In place, mapped to exact model/PCI IDs
- **PCI enumeration:** Next up
- **LunaFS design:** In progress, see `src/fs/lunafs.rs`
- **All code modular and Rust 2024 edition**

---

## Next Actionable Step
- Implement PCI enumeration and device detection in `src/drivers/pci.rs` (detect all devices by PCI/USB/I2C ID as listed above).
- Begin integrating LunaFS with NVMe driver for block IO.

---

## References
- Hardware: See `lunaviel_hardware.txt`
- Filesystem: See `src/fs/lunafs.rs`
- Drivers: See `src/drivers/`

---

*This plan is updated as of June 18, 2025. Update status and ETAs as you progress. All hardware details are mapped to the actual device model names and PCI/USB/I2C IDs as found in your system.*
