#!/bin/sh
# wgcf-wrapper.sh - Wrapper for wgcf binary to generate WireGuard config from Cloudflare WARP
# Part of YAAWG (AmneziaWG for OpenWrt)

set -euo pipefail 2>/dev/null || set -eu

WGCF_BINARY="/usr/bin/wgcf"
WGCF_DIR="/etc/amneziawg/warp"
WGCF_PROFILE="${WGCF_DIR}/wgcf-profile.conf"
WGCF_LOG_TAG="wgcf-wrapper"

# Logging functions
log_msg() {
	local level="$1"
	shift
	logger -t "$WGCF_LOG_TAG" "$level: $*"
}

log_error() {
	log_msg "error" "$*"
}

log_info() {
	log_msg "info" "$*"
}

# Create WARP directory if not exists
ensure_warp_dir() {
	mkdir -p "$WGCF_DIR"
}

# Check if wgcf binary exists and is executable
check_wgcf_binary() {
	if [ ! -x "$WGCF_BINARY" ]; then
		log_error "wgcf binary not found or not executable: $WGCF_BINARY"
		return 1
	fi
	return 0
}

# Register new WARP account
warp_register() {
	local license_key="${1:-}"

	ensure_warp_dir

	log_info "Registering new WARP account..."

	cd "$WGCF_DIR"

	if [ -n "$license_key" ]; then
		# Register with license key (WARP+)
		"$WGCF_BINARY" register --license "$license_key"
	else
		# Register without license key (WARP Free)
		"$WGCF_BINARY" register
	fi

	if [ $? -eq 0 ]; then
		log_info "WARP registration successful"
		return 0
	else
		log_error "WARP registration failed"
		return 1
	fi
}

# Generate/update WireGuard config from WARP account
warp_generate_config() {
	ensure_warp_dir

	if [ ! -f "$WGCF_PROFILE" ]; then
		log_error "WARP profile not found. Please register first."
		return 1
	fi

	log_info "Generating WireGuard config from WARP profile..."

	cd "$WGCF_DIR"
	"$WGCF_BINARY" generate

	if [ $? -eq 0 ]; then
		log_info "WireGuard config generated successfully"
		return 0
	else
		log_error "Failed to generate WireGuard config"
		return 1
	fi
}

# Extract private key from wgcf-profile.conf
extract_private_key() {
	if [ ! -f "$WGCF_PROFILE" ]; then
		log_error "WARP profile not found"
		return 1
	fi

	grep "^private_key" "$WGCF_PROFILE" | cut -d'=' -f2 | tr -d ' '
}

# Extract public key from wgcf-profile.conf
extract_public_key() {
	if [ ! -f "$WGCF_PROFILE" ]; then
		log_error "WARP profile not found"
		return 1
	fi

	grep "^public_key" "$WGCF_PROFILE" | cut -d'=' -f2 | tr -d ' '
}

# Extract endpoint address from wgcf-profile.conf
extract_endpoint() {
	if [ ! -f "$WGCF_PROFILE" ]; then
		log_error "WARP profile not found"
		return 1
	fi

	grep "^endpoint" "$WGCF_PROFILE" | cut -d'=' -f2 | tr -d ' '
}

# Extract client IPv4 address
extract_ipv4() {
	if [ ! -f "$WGCF_PROFILE" ]; then
		log_error "WARP profile not found"
		return 1
	fi

	grep "^v4" "$WGCF_PROFILE" | cut -d'=' -f2 | tr -d ' '
}

# Extract client IPv6 address
extract_ipv6() {
	if [ ! -f "$WGCF_PROFILE" ]; then
		log_error "WARP profile not found"
		return 1
	fi

	grep "^v6" "$WGCF_PROFILE" | cut -d'=' -f2 | tr -d ' '
}

# Get account type
get_account_type() {
	if [ ! -f "$WGCF_PROFILE" ]; then
		log_error "WARP profile not found"
		return 1
	fi

	if grep -q "^license" "$WGCF_PROFILE"; then
		echo "plus"
	else
		echo "free"
	fi
}

# Check if profile exists
profile_exists() {
	[ -f "$WGCF_PROFILE" ]
}

# Get WARP status information
warp_status() {
	if ! profile_exists; then
		echo "not_registered"
		return 0
	fi

	local account_type=$(get_account_type)
	local private_key=$(extract_private_key)
	local public_key=$(extract_public_key)
	local ipv4=$(extract_ipv4)
	local ipv6=$(extract_ipv6)

	echo "account_type:$account_type"
	echo "private_key:${private_key:0:8}..."
	echo "public_key:${public_key:0:8}..."
	echo "ipv4:$ipv4"
	echo "ipv6:$ipv6"
}

# Main command handler
case "${1:-}" in
	register)
		warp_register "${2:-}"
		;;
	generate)
		warp_generate_config
		;;
	extract_private_key)
		extract_private_key
		;;
	extract_public_key)
		extract_public_key
		;;
	extract_endpoint)
		extract_endpoint
		;;
	extract_ipv4)
		extract_ipv4
		;;
	extract_ipv6)
		extract_ipv6
		;;
	account_type)
		get_account_type
		;;
	status)
		warp_status
		;;
	check)
		if profile_exists && check_wgcf_binary; then
			echo "ready"
			exit 0
		else
			echo "not_ready"
			exit 1
		fi
		;;
	*)
		# Default: show usage
		echo "Usage: $0 {register|generate|extract_private_key|extract_public_key|extract_endpoint|extract_ipv4|extract_ipv6|account_type|status|check}"
		exit 1
		;;
esac
