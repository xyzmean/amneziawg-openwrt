#!/bin/sh
# warp-helper.sh - Helper functions for WARP integration with AmneziaWG
# Part of YAAWG (AmneziaWG for OpenWrt)

set -euo pipefail 2>/dev/null || set -eu

. /lib/functions.sh

WGCF_WRAPPER="/usr/libexec/amneziawg/wgcf-wrapper.sh"
WARP_HELPER_LOG_TAG="warp-helper"

# Logging functions
log_msg() {
	local level="$1"
	shift
	logger -t "$WARP_HELPER_LOG_TAG" "$level: $*"
}

log_error() {
	log_msg "error" "$*"
}

log_info() {
	log_msg "info" "$*"
}

# Check if WARP is configured for interface
is_warp_interface() {
	local interface="$1"

	config_get_bool use_warp "$interface" use_warp 0
	[ "$use_warp" -eq 1 ]
}

# Apply WARP configuration to interface
apply_warp_config() {
	local interface="$1"
	local config_file="$2"

	if ! is_warp_interface "$interface"; then
		log_info "Not a WARP interface: $interface"
		return 0
	fi

	log_info "Applying WARP configuration for $interface..."

	# Extract keys from wgcf profile
	local private_key
	local public_key
	local endpoint
	local ipv4
	local ipv6

	if [ -x "$WGCF_WRAPPER" ]; then
		private_key=$("$WGCF_WRAPPER" extract_private_key)
		public_key=$("$WGCF_WRAPPER" extract_public_key)
		endpoint=$("$WGCF_WRAPPER" extract_endpoint)
		ipv4=$("$WGCF_WRAPPER" extract_ipv4)
		ipv6=$("$WGCF_WRAPPER" extract_ipv6)
	else
		log_error "wgcf-wrapper not found or not executable"
		return 1
	fi

	# Update config file with WARP keys
	if [ -n "$private_key" ]; then
		sed -i "s|^PrivateKey =.*|PrivateKey = $private_key|" "$config_file"
	fi

	# Update peer section with WARP peer info
	if [ -n "$public_key" ] && [ -n "$endpoint" ]; then
		# Check if peer section exists
		if grep -q "^\[Peer\]" "$config_file"; then
			# Update existing peer
			sed -i "/^\[Peer\]/,/^\[Interface\]/ s|^PublicKey =.*|PublicKey = $public_key|" "$config_file"
			sed -i "/^\[Peer\]/,/^\[Interface\]/ s|^Endpoint =.*|Endpoint = $endpoint|" "$config_file"
		else
			# Add new peer section
			cat >> "$config_file" << EOF

[Peer]
PublicKey = $public_key
Endpoint = $endpoint
AllowedIPs = 0.0.0.0/0,::/0
PersistentKeepalive = 25
EOF
		fi
	fi

	log_info "WARP configuration applied successfully"
}

# Get WARP connection status
get_warp_status() {
	local interface="$1"

	if ! is_warp_interface "$interface"; then
		echo "not_warp"
		return 0
	fi

	if [ ! -x "$WGCF_WRAPPER" ]; then
		echo "wgcf_missing"
		return 0
	fi

	local status=$("$WGCF_WRAPPER" check 2>/dev/null || echo "not_ready")
	echo "$status"
}

# Register WARP account
register_warp_account() {
	local license_key="${1:-}"

	if [ ! -x "$WGCF_WRAPPER" ]; then
		log_error "wgcf-wrapper not found or not executable"
		return 1
	fi

	if [ -n "$license_key" ]; then
		log_info "Registering WARP+ account..."
		"$WGCF_WRAPPER" register "$license_key"
	else
		log_info "Registering WARP Free account..."
		"$WGCF_WRAPPER" register
	fi

	return $?
}

# Regenerate WARP config
regenerate_warp_config() {
	if [ ! -x "$WGCF_WRAPPER" ]; then
		log_error "wgcf-wrapper not found or not executable"
		return 1
	fi

	log_info "Regenerating WARP configuration..."
	"$WGCF_WRAPPER" generate

	return $?
}

# Get WARP account info
get_warp_account_info() {
	if [ ! -x "$WGCF_WRAPPER" ]; then
		echo "error:wgcf_wrapper_not_found"
		return 1
	fi

	"$WGCF_WRAPPER" status
}

# Auto-configure AmneziaWG parameters for WARP
# WARP works best with specific obfuscation settings
get_warp_awg_presets() {
	# Return AmneziaWG v2.0 parameters optimized for WARP
	cat << EOF
awg_jc=7
awg_jmin=15
awg_jmax=35
awg_s1=25
awg_s2=35
awg_s3=15
awg_s4=20
awg_h1=162000-162500
awg_h2=262000-262500
awg_h3=362000-362500
awg_h4=462000-462500
awg_i1=150
awg_i2=200
awg_i3=250
awg_i4=300
awg_i5=350
EOF
}

# Apply WARP-optimized AmneziaWG presets to UCI
apply_warp_awg_presets() {
	local interface="$1"

	if ! is_warp_interface "$interface"; then
		return 0
	fi

	log_info "Applying WARP-optimized AmneziaWG presets for $interface..."

	local ucitmp
	oldmask=$(umask)
	umask 077
	ucitmp=$(mktemp -d)

	# Apply presets
	while IFS='=' read -r key value; do
		uci -q -t "$ucitmp" set network."$interface"."$key"="$value"
	done << EOF
$(get_warp_awg_presets)
EOF

	uci -q -t "$ucitmp" commit network
	rm -rf "$ucitmp"
	umask "$oldmask"

	log_info "WARP AmneziaWG presets applied"
}

# Watchdog function to check WARP connectivity
warp_watchdog_check() {
	local interface="$1"
	local timeout=5

	if ! is_warp_interface "$interface"; then
		return 0
	fi

	# Check if interface is up
	if ! ip link show "$interface" >/dev/null 2>&1; then
		log_info "Interface $interface is down, skipping WARP check"
		return 0
	fi

	# Try to ping through WARP (ping Cloudflare DNS)
	# Note: This requires proper routing setup
	local ping_count=3
	local ping_success=0

	# IPv4 check
	if ping -c "$ping_count" -W "$timeout" 1.1.1.1 >/dev/null 2>&1; then
		ping_success=1
	fi

	# IPv6 check
	if [ "$ping_success" -eq 0 ]; then
		if ping6 -c "$ping_count" -W "$timeout" 2606:4700:4700::1111 >/dev/null 2>&1; then
			ping_success=1
		fi
	fi

	if [ "$ping_success" -eq 0 ]; then
		log_error "WARP connectivity check failed for $interface"
		# Trigger interface reconfiguration
		ubus call network.interface "$interface" down
		sleep 2
		ubus call network.interface "$interface" up
		log_info "Restarted interface $interface due to connectivity issues"
	else
		log_info "WARP connectivity check passed for $interface"
	fi
}

# Export functions for use in other scripts
export -f is_warp_interface
export -f apply_warp_config
export -f get_warp_status
export -f register_warp_account
export -f regenerate_warp_config
export -f get_warp_account_info
export -f get_warp_awg_presets
export -f apply_warp_awg_presets
export -f warp_watchdog_check
