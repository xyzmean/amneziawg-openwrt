include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=kmod-amneziawg
PKG_VERSION:=1.0.20240711
PKG_RELEASE:=1
WIREGUARD_VERSION:=1.0.0

PKG_SOURCE:=v$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/amnezia-vpn/amneziawg-linux-kernel-module/archive/refs/tags/
PKG_HASH:=b8925c5d1057d05059a9a80ddfdbe8a0c4c5507f84d8cd3b1f0c567e50064abf

PKG_BUILD_DIR=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define KernelPackage/amneziawg
	SECTION:=kernel
	CATEGORY:=Kernel modules
	SUBMENU:=Network Support
	TITLE:=AmneziaWG VPN Kernel Module
	FILES:=$(PKG_BUILD_DIR)/generated/amneziawg.ko
	DEPENDS:= \
		+kmod-udptunnel4 \
		+kmod-udptunnel6 \
		+kmod-crypto-lib-chacha20poly1305 \
		+kmod-crypto-lib-curve25519
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	$(CP) $(BUILD_DIR)/amneziawg-linux-kernel-module-$(PKG_VERSION)/src/* $(PKG_BUILD_DIR)/
	mkdir -p $(PKG_BUILD_DIR)/kernel
	$(CP) $(LINUX_DIR)/* $(PKG_BUILD_DIR)/kernel/
	#ln -s $(LINUX_DIR) $(PKG_BUILD_DIR)/$(MAKE_PATH)/kernel
endef

define Build/Compile
	$(MAKE_VARS) $(MAKE) $(PKG_JOBS) -C $(PKG_BUILD_DIR) $(MAKE_FLAGS) apply-patches
	$(MAKE_VARS) $(MAKE) -C "$(LINUX_DIR)" $(KERNEL_MAKE_FLAGS) M="$(PKG_BUILD_DIR)/generated" EXTRA_CFLAGS="$(BUILDFLAGS)" WIREGUARD_VERSION="$(WIREGUARD_VERSION)" modules
endef

$(eval $(call KernelPackage,amneziawg))
