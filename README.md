# YAAWG: Yet another AmneziaWG variation for OpenWrt

This project aims to update the sources of the initial AmneziaWG repository and align them as closely as possible with four upstream projects ([luci-proto-wireguard](https://github.com/openwrt/luci/tree/master/protocols/luci-proto-wireguard), [amneziawg-tools](https://github.com/amnezia-vpn/amneziawg-tools/), [amneziawg-linux-kernel-module](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module), [amneziawg-go](https://github.com/amnezia-vpn/amneziawg-go)).

Why? Because it seems the original repository has been abandoned: over half a year has passed since the last commit, no bugs were fixed, and no new protocol versions were added, while the four upstream projects continue receiving regular updates (at least from the community).

The main differences and objectives are:
1. `luci-proto-amneziawg` has been aligned with [luci-proto-wireguard](https://github.com/openwrt/luci/tree/master/protocols/luci-proto-wireguard):
   - Based on the `luci-proto-wireguard` codebase.
   - The AmneziaWG settings tab now includes placeholders where available (default values, if chosen, mimic the Wireguard protocol).
   - Fixed a bug with QR code generation. The generated QR code now contains AmneziaWG-specific information.
   - Added checkboxes to enable/disable peers.
   - Added an icon for the interface.
   - Added support for ranged H1-H4 parameters (delimiter: `-`, e.g., `123456-123500`).
   - Added support for v2.0 protocol parameters: S3-S4, I1-I5.

2. `amneziawg-tools` has been aligned with the upstream repository [amneziawg-tools](https://github.com/amnezia-vpn/amneziawg-tools/):
   - The package is now compiled based on the upstream repository.
   - Fixed a bug with the non-existent `proto_amneziawg_check_installed` method.
   - Changed temporary folders and files to match the protocol name.
   - Refactored scripts to make them look more "amneziish."
   - Fixed a bug with an incorrect path when using `amneziawg-go`.
   - Added support for ranged H1-H4 parameters (with `-` delimiter, e.g., `123456-123500`).
   - Added support for v2.0 protocol parameters: S3-S4, I1-I5.

3. `kmod-amneziawg` is now compiled entirely based on the upstream [amneziawg-linux-kernel-module](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module) repository.
   - Added support for v2.0 protocol parameters: S3-S4, I1-I5.

4. `amneziawg-go` acts as an alternative to `kmod-amneziawg`. Please refer to [this section](#kmod-amneziawg-vs-amneziawg-go) for more information. The Go implementation is fully based on the upstream project [amneziawg-go](https://github.com/amnezia-vpn/amneziawg-go).

# `kmod-amneziawg` vs `amneziawg-go`

When the AmneziaWG authors introduced the v1.5 protocol, it was supported only in the Go implementation. Thus the user namespace (Go) implementation was added to the repo in order to support the newer protocol version. Later, v2.0 protocol support was added to both the user namespace (Go) and kernel module implementations. To maintain backward compatibility, this repository will continue to support both packages.

Differences:
1. `kmod-amneziawg`: requires a less powerful device to run and consumes less space but is still in beta. Use at your own risk.
2. `amneziawg-go`: requires a more powerful device and uses more space but provides a user namespace implementation of the protocol.

If both implementations are installed, `kmod-amneziawg` will be used by default.

# Results

Everything seems to work fine. No major problems have been detected or reported so far.

# How to build and use

## Build OpenWRT firmware with AmneziaWG packages included

This repository is intended primarily for compiling packages during the firmware build process. Follow these steps:

1. Clone the OpenWrt repo by running `git clone https://github.com/openwrt/openwrt.git`. You may choose any tag/commit hash by adding `-b {tag/commit hash}`.

2. Add the line `src-git awgopenwrt https://github.com/this-username-has-been-taken/amneziawg-openwrt.git` to the `feeds.conf.default` file.

3. Update package feeds by running: `{path to openwrt dir}/scripts/feeds update -a`

4. Shall you build the firmware with the `amneziawg-go` package, please make sure the included Go package version is higher than `1.24.4`. Most OpenWRT versions except `SNAPSHOT` have older Go versions. To upgrade:
   - Clone the latest OpenWRT Packages repository: `git clone https://github.com/openwrt/packages.git`.
   - Replace `{path to openwrt dir}/feeds/packages/lang/golang` with the one from the cloned repository at `{path to the cloned repository}/packages/lang/golang`.

5. Install packages by running: `{path to openwrt dir}/scripts/feeds install -a`

6. Configure firmware (choose target, settings, AmneziaWG packages: `amneziawg-go` or `kmod-amneziawg` + `amneziawg-tools` + `luci-proto-amneziawg` and others) using: `make -C {path to openwrt dir} menuconfig` and save.

7. Make the defconfig: `make -C {path to openwrt dir} defconfig`

8. Build the firmware: `make -C openwrt -j$(nproc) V=sc`

9. After building, firmware will be located at: `{path to openwrt dir}/bin/targets/{your target}/{your subtarget}` and compiled packages at: `{path to openwrt dir}/bin/targets/{your target}/{your subtarget}/packages` (kernel module) and `{path to openwrt dir}/bin/packages/{your architecture}/awgopenwrt` (other packages).

## Compile AmneziaWG packages without building the firmware

You can also compile packages independently without building firmware. The process consists of two workflows: building the OpenWRT toolchain (takes about 2.5 hours) and compiling AmneziaWG packages (takes under 20 minutes). The second requires the first to be completed once and can be restarted as needed.

Steps:
1. Get your router parameters:
   - OpenWRT version: `SNAPSHOT` or release (e.g., `24.10.2`), found on the `Status -> Overview` page under `Firmware Version`.
   - CPU/package architecture: run `apk info kernel` or `opkg info kernel` to check `Architecture` value (e.g., `aarch64_cortex-a53`) or consult [OpenWRT router database](https://openwrt.org/toh/start).
   - Target and subtarget: found on the `Status -> Overview` page under `Target Platform` (before and after the slash).

2. Fork this repository.

3. Enable GitHub Actions if not already.

4. Choose `Build OpenWrt toolchain cache`, enter router parameters in `Run workflow`, and start.
   - Optionally set a different YAWWG version using the release tag/commit hash field.
   - Do not disable `Update Go` unless you know what you are doing; `amneziawg-go` requires Go > 1.24.4.

5. Wait ~2-2.5 hours for cache to build.

6. Choose `Build AmneziaWG from cache`, enter parameters, and run.
   - Select whether to compile kernel module, Go implementation, or both.

7. Wait ~10-20 minutes for the binaries.

8. Download the artifacts, unpack, and install:
   - Via Web Interface (LuCi):
      - Go to `System -> Software`.
      - Click `Upload Package...`.
      - Upload `kmod-amneziawg` or `amneziawg-go` `.ipk`/`.apk`.
      - Confirm installation.
      - Repeat for `amneziawg-tools` and `luci-proto-amneziawg`.
   - Via console:
      - Transfer files to router.
      - Run `apk install {path to kmod-amneziawg or amneziawg-go .apk}` or `opkg install {path to kmod-amneziawg or amneziawg-go .ipk}`.
      - Run similar commands for `amneziawg-tools` and `luci-proto-amneziawg`.

9. Reboot router or run: `/etc/init.d/network restart`

10. Congratulations! AmneziaWG is now installed. Go to `Network -> Interfaces`, click `Add new interface...`, select `AmneziaWG` protocol.

*Note: Browser cache cleaning may be required to see the new protocol in OpenWRT.*

### Vermagic control for `SNAPSHOT` versions

Vermagic is a hash calculated for the OpenWRT kernel. When installing kernel-related packages, OpenWRT checks if the package's `vermagic` matches the kernel's. If not, installation won't succeed. Since `SNAPSHOT` versions update daily, `vermagic` values may differ. Check your firmware's `vermagic` by running `apk info kernel` or `opkg info kernel` and noting the hash after the kernel version in `Version`. For example, `6.6.52~f58afd3748410d3b1baa06a466d6682-r1` means `vermagic` is `f58afd3748410d3b1baa06a466d6682`. The compiled package's `vermagic` value is located in the `vermagic` file within the workflow artifacts. If these do not match, the kernel module cannot be installed.