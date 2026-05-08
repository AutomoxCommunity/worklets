#!/bin/bash

#================================================================
# HEADER
#================================================================
# SYNOPSIS
#   Removes the interim "Dirty Frag" mitigation previously installed
#   by the "Mitigate Dirty Frag Vulnerability" worklet, restoring
#   normal load behavior for the esp4, esp6, ipcomp4, ipcomp6, and
#   rxrpc kernel modules.
#
# DESCRIPTION
#   Reverts everything that the original mitigation worklet did:
#
#     1. Deletes /etc/modprobe.d/dirtyfrag.conf so modprobe will no
#        longer redirect the affected modules to /bin/false on the
#        next load.
#     2. Strips matching "install <mod> /bin/false|/bin/true" lines
#        from any *other* file under /etc/modprobe.d/ that an admin
#        may have copied the rules into, so the modules are not
#        still blocked through a different filename.
#     3. Best-effort `modprobe` of each previously blocked module so
#        that the running kernel can use IPsec ESP / IPComp / RxRPC
#        again immediately, without requiring a reboot. modprobe
#        failures are tolerated — some modules may not be available
#        on minimal kernels (e.g. cloud images that ship without
#        rxrpc), and that is not a remediation failure.
#
#   The remediation is idempotent: re-running it after the
#   mitigation is already gone is a no-op that exits 0.
#
# WARNING
#   This worklet re-enables the kernel modules associated with the
#   Dirty Frag privilege-escalation chain (CVE-2026-43284 xfrm-ESP
#   and CVE-2026-43500 RxRPC). Only run it on hosts whose running
#   kernel already contains the upstream fixes; otherwise the local
#   privilege-escalation exposure returns.
#
#   Removing the mitigation does NOT by itself reload the modules
#   into a service — IPsec daemons (strongSwan, Libreswan) and AFS
#   clients may still need to be restarted to begin using the now-
#   available modules.
#
# PREREQUISITES
#   * Linux endpoint with /etc/modprobe.d/ writable by root (Automox
#     agent runs as root).
#   * Patched kernel: distribution build that includes the fixes for
#     CVE-2026-43284 and CVE-2026-43500, with the host already
#     rebooted onto that kernel.
#
# USAGE
#   ./remediation.sh
#
# EXIT CODES
#   0 — mitigation removed and verified absent.
#   1 — mitigation could not be fully removed (file still present
#       or stray install-stub remains in /etc/modprobe.d/).
#
#================================================================
# IMPLEMENTATION
#   version    1.0
#   author     Automox
#
#================================================================
# HISTORY
#   2026-05-08 : Worklet created to undo the changes made by the
#                "Mitigate Dirty Frag Vulnerability" worklet.
#
#================================================================
# END_OF_HEADER
#================================================================

# Primary file the original mitigation wrote. Removing it is the
# single most important step; everything else is hygiene.
BLACKLIST_FILE="/etc/modprobe.d/dirtyfrag.conf"

# Module set that the original mitigation blocked. Kept identical
# to the mitigation worklet so the two stay in lockstep.
VULN_MODULES=("esp4" "esp6" "ipcomp4" "ipcomp6" "rxrpc")

# ----------------------------------------------------------------
# Step 1: Remove the primary blacklist file.
# ----------------------------------------------------------------
# `rm -f` swallows the "file not found" case, which is the expected
# state if remediation is being re-run or if a host received the
# evaluation flag for a stray rule in a different file.
if [[ -e "$BLACKLIST_FILE" ]]; then
    echo "Removing $BLACKLIST_FILE..."
    if ! rm -f "$BLACKLIST_FILE"; then
        echo "Failed to remove $BLACKLIST_FILE — check filesystem permissions."
        exit 1
    fi
else
    echo "$BLACKLIST_FILE is already absent."
fi

# ----------------------------------------------------------------
# Step 2: Strip stray install-stubs from any other modprobe.d file.
# ----------------------------------------------------------------
# We only edit files under /etc/modprobe.d/ — distro-managed rules
# under /lib/modprobe.d/ are intentionally left alone. For each
# file we delete only the lines that match the mitigation pattern
# (install <mod> /bin/false|/bin/true), leaving any unrelated
# content intact. If a file ends up empty after stripping, we
# leave it in place — the operator may have created it for other
# reasons, and an empty conf file is harmless.
if [[ -d /etc/modprobe.d ]]; then
    while IFS= read -r -d '' conf; do
        # Skip the primary file (already deleted above).
        [[ "$conf" == "$BLACKLIST_FILE" ]] && continue
        # Build a single sed expression that drops a matching line
        # for each module in one pass. We write to a tempfile first,
        # then move into place, so a partial write cannot leave the
        # original file truncated.
        tmp="$(mktemp "${conf}.dirtyfragundo.XXXXXX")" || {
            echo "Could not create tempfile alongside $conf; skipping."
            continue
        }
        sed_expr=""
        for mod in "${VULN_MODULES[@]}"; do
            sed_expr+=" -e /^[[:space:]]*install[[:space:]]\\+${mod}[[:space:]]\\+\\(\\/bin\\/false\\|\\/bin\\/true\\)\\([[:space:]]\\|\$\\)/d"
        done
        # shellcheck disable=SC2086
        if sed $sed_expr "$conf" > "$tmp"; then
            # Only replace the original if we actually changed
            # something — avoids touching mtimes unnecessarily and
            # makes the script quieter on no-op runs.
            if ! cmp -s "$conf" "$tmp"; then
                echo "Stripping Dirty Frag install-stubs from $conf..."
                # Preserve original ownership/permissions.
                chmod --reference="$conf" "$tmp" 2>/dev/null || true
                chown --reference="$conf" "$tmp" 2>/dev/null || true
                mv "$tmp" "$conf"
            else
                rm -f "$tmp"
            fi
        else
            echo "sed failed on $conf; leaving file untouched."
            rm -f "$tmp"
        fi
    done < <(find /etc/modprobe.d -maxdepth 1 -type f -print0 2>/dev/null)
fi

# ----------------------------------------------------------------
# Step 3: Best-effort reload of previously blocked modules.
# ----------------------------------------------------------------
# Loading them now means services that depend on IPsec ESP /
# IPComp / RxRPC don't need to wait for a reboot. We do not treat
# modprobe failures as remediation failures: a kernel may legitimately
# not ship one of these modules (esp. rxrpc on minimal/cloud images),
# and the on-disk mitigation has already been removed.
if command -v modprobe >/dev/null 2>&1; then
    for mod in "${VULN_MODULES[@]}"; do
        if grep -q "^${mod} " /proc/modules 2>/dev/null; then
            echo "Kernel module '${mod}' is already loaded."
            continue
        fi
        echo "Attempting to load kernel module '${mod}'..."
        if modprobe "$mod" 2>/dev/null; then
            echo "  Loaded '${mod}'."
        else
            echo "  Could not load '${mod}' (module may not be present in this kernel; non-fatal)."
        fi
    done
else
    echo "modprobe not found in PATH; skipping module reload step."
fi

# ----------------------------------------------------------------
# Step 4: Verify the mitigation matches the evaluation contract.
# ----------------------------------------------------------------
# Re-check the conditions the evaluation script tests, so we do not
# exit 0 unless the device would be reported compliant on the next
# scan.
VERIFY_FAILED=0

if [[ -e "$BLACKLIST_FILE" ]]; then
    echo "Verification failed: $BLACKLIST_FILE still exists after removal attempt."
    VERIFY_FAILED=1
fi

if [[ -d /etc/modprobe.d ]]; then
    while IFS= read -r -d '' conf; do
        [[ "$conf" == "$BLACKLIST_FILE" ]] && continue
        for mod in "${VULN_MODULES[@]}"; do
            if grep -Eq "^[[:space:]]*install[[:space:]]+${mod}[[:space:]]+(/bin/false|/bin/true)([[:space:]]|$)" "$conf" 2>/dev/null; then
                echo "Verification failed: '$conf' still contains an install-stub for '${mod}'."
                VERIFY_FAILED=1
            fi
        done
    done < <(find /etc/modprobe.d -maxdepth 1 -type f -print0 2>/dev/null)
fi

if [[ "$VERIFY_FAILED" -ne 0 ]]; then
    echo "Removal of Dirty Frag mitigation failed verification."
    exit 1
fi

echo "Dirty Frag mitigation removed successfully."
exit 0
