#!/bin/bash

#================================================================
# HEADER
#================================================================
# SYNOPSIS
#   Detects whether the "Dirty Frag" interim mitigation is still
#   present on a Linux endpoint, and (if so) flags the device for
#   removal of that mitigation.
#
# DESCRIPTION
#   The companion "Mitigate Dirty Frag Vulnerability" worklet writes
#   /etc/modprobe.d/dirtyfrag.conf with "install <mod> /bin/false"
#   stubs for esp4, esp6, ipcomp4, ipcomp6, and rxrpc — refusing to
#   load those modules — and then rmmod's any that were resident.
#   That mitigation was an interim measure for CVE-2026-43284
#   (xfrm-ESP) and CVE-2026-43500 (RxRPC) while distribution kernels
#   caught up with the upstream fixes.
#
#   Once a host has been rebooted onto a patched kernel, the
#   mitigation can (and usually should) be reverted so that IPsec
#   ESP, IPsec IP-Compression, and RxRPC functionality is restored.
#   This worklet performs that revert.
#
#   The evaluation reports a device as non-compliant (exit 1) — i.e.
#   in need of remediation to *remove* the mitigation — if either of
#   the following is true:
#
#     1. /etc/modprobe.d/dirtyfrag.conf still exists, OR
#     2. There is still a stray "install <mod> /bin/false|/bin/true"
#        line for any of esp4/esp6/ipcomp4/ipcomp6/rxrpc inside any
#        other file under /etc/modprobe.d/ (e.g. an admin copied the
#        rules into a different conf file).
#
#   Otherwise the device is reported compliant (exit 0): the
#   mitigation has already been removed, nothing to do.
#
# WARNING
#   Removing the Dirty Frag mitigation re-enables the affected
#   kernel modules on the next module load (and after a reboot).
#   Only deploy this worklet to hosts whose running kernel already
#   contains the fixes for CVE-2026-43284 (xfrm-ESP) and
#   CVE-2026-43500 (RxRPC). Reverting on an unpatched kernel
#   re-introduces the local privilege-escalation exposure.
#
# USAGE
#   ./evaluation.sh
#
# EXIT CODES
#   0 — compliant: mitigation is already absent, no action needed.
#   1 — non-compliant: mitigation is still present; schedule
#       remediation to remove it.
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

# Primary file written by the original mitigation worklet. Its mere
# presence is enough to keep the modules blocked on the next boot,
# so it is the first thing we check for.
BLACKLIST_FILE="/etc/modprobe.d/dirtyfrag.conf"

# Modules covered by the mitigation. We re-scan every other file in
# /etc/modprobe.d/ for stray install-stubs targeting these names, in
# case the rules were copied or renamed by a local admin.
VULN_MODULES=("esp4" "esp6" "ipcomp4" "ipcomp6" "rxrpc")

NONCOMPLIANT=0

# ----------------------------------------------------------------
# Check 1: the primary blacklist file is gone.
# ----------------------------------------------------------------
if [[ -e "$BLACKLIST_FILE" ]]; then
    echo "Non-compliant: '$BLACKLIST_FILE' still exists; mitigation has not been removed."
    NONCOMPLIANT=1
fi

# ----------------------------------------------------------------
# Check 2: no other modprobe.d file still blocks these modules.
# ----------------------------------------------------------------
# We deliberately limit the scan to /etc/modprobe.d/ rather than
# /lib/modprobe.d/ or /run/modprobe.d/ — the latter are owned by
# distro packaging or volatile, and stripping rules from them is
# out of scope for this worklet.
if [[ -d /etc/modprobe.d ]]; then
    while IFS= read -r -d '' conf; do
        # Skip the primary file; check 1 already handled it.
        [[ "$conf" == "$BLACKLIST_FILE" ]] && continue
        for mod in "${VULN_MODULES[@]}"; do
            if grep -Eq "^[[:space:]]*install[[:space:]]+${mod}[[:space:]]+(/bin/false|/bin/true)([[:space:]]|$)" "$conf" 2>/dev/null; then
                echo "Non-compliant: '$conf' still contains a Dirty Frag install-stub for '${mod}'."
                NONCOMPLIANT=1
            fi
        done
    done < <(find /etc/modprobe.d -maxdepth 1 -type f -print0 2>/dev/null)
fi

# ----------------------------------------------------------------
# Final verdict
# ----------------------------------------------------------------
if [[ "$NONCOMPLIANT" -eq 0 ]]; then
    echo "Compliant: Dirty Frag mitigation is not present; nothing to remove."
    exit 0
else
    echo "Scheduling remediation to remove the Dirty Frag mitigation."
    exit 1
fi
