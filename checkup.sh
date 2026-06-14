#!/usr/bin/env bash
# arch-check.sh — System optimization checker for Arch Linux

RED='\033[0;31m'
YEL='\033[1;33m'
GRN='\033[0;32m'
BLU='\033[1;34m'
DIM='\033[2m'
NC='\033[0m'
BOLD='\033[1m'

ok()      { echo -e "  ${GRN}✔${NC}  $1"; }
warn()    { echo -e "  ${YEL}⚠${NC}  $1"; }
fail()    { echo -e "  ${RED}✘${NC}  $1"; }
info()    { echo -e "  ${BLU}→${NC}  $1"; }
explain() { echo -e "     ${DIM}$1${NC}"; }
section() { echo -e "\n${BOLD}━━━ $1 ━━━${NC}"; }

ISSUES=()
add_issue() { ISSUES+=("$1"); }

# ─── SUDO CHECK ───────────────────────────────────────────────────────────────
if [[ "$EUID" -ne 0 ]]; then
    echo -e "\n${YEL}${BOLD}  This script needs sudo for some checks (dmidecode).${NC}"
    echo -e "  Run with: ${BOLD}sudo ./arch-check.sh${NC}\n"
    HAVE_SUDO=false
else
    HAVE_SUDO=true
fi

# ─── CPU ──────────────────────────────────────────────────────────────────────
section "CPU"

CPU_VENDOR=$(grep -m1 "vendor_id" /proc/cpuinfo | awk '{print $3}')
CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')
CPU_THREADS=$(nproc)
info "CPU: $CPU_MODEL ($CPU_THREADS threads)"

# Governor / driver detection
DRIVER=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null)

if [[ "$DRIVER" == "amd-pstate-epp" ]]; then
    EPP=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null)
    if [[ "$EPP" == "balance_performance" || "$EPP" == "performance" ]]; then
        ok "CPU driver: amd-pstate-epp | preference: $EPP"
        explain "Modern AMD driver — communicates directly with CPU firmware for smarter boost decisions."
        explain "balance_performance is the sweet spot: full Precision Boost with reasonable power draw."
    else
        warn "CPU driver: amd-pstate-epp | preference: $EPP (suboptimal)"
        explain "amd-pstate-epp is the right driver, but '$EPP' limits how aggressively the CPU boosts."
        explain "balance_performance lets Precision Boost run freely without pegging power consumption."
        add_issue "EPP preference is '$EPP' — suboptimal for desktop performance
     Why: amd-pstate-epp controls AMD boost via firmware; wrong preference caps performance
     Fix: echo balance_performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
     Permanent: sudo tee /etc/udev/rules.d/99-amd-pstate.rules <<'EOF'
ACTION==\"add\", SUBSYSTEM==\"cpu\", ATTR{cpufreq/energy_performance_preference}=\"balance_performance\"
EOF"
    fi
elif [[ "$DRIVER" == "intel_pstate" ]]; then
    GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    EPP=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null)
    if [[ -n "$EPP" ]]; then
        if [[ "$EPP" == "balance_performance" || "$EPP" == "performance" ]]; then
            ok "CPU driver: intel_pstate | governor: $GOV | preference: $EPP"
            explain "intel_pstate communicates with CPU firmware directly. balance_performance allows"
            explain "full Turbo Boost while keeping reasonable power draw when idle."
        else
            warn "CPU driver: intel_pstate | governor: $GOV | preference: $EPP (suboptimal)"
            explain "balance_performance lets Intel Turbo Boost run freely without locking max power."
            add_issue "intel_pstate EPP preference is '$EPP' — suboptimal for desktop performance
     Why: intel_pstate controls boost via firmware; wrong preference caps Turbo Boost
     Fix: echo balance_performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference"
        fi
    else
        if [[ "$GOV" == "schedutil" || "$GOV" == "powersave" ]]; then
            ok "CPU driver: intel_pstate | governor: $GOV"
            explain "intel_pstate with powersave/schedutil still allows Turbo Boost — the governor name is misleading."
        elif [[ "$GOV" == "performance" ]]; then
            warn "CPU governor: performance (always-on boost — wastes power, schedutil is smarter)"
            explain "performance locks the CPU at max frequency. schedutil achieves the same peak when needed with better power efficiency."
            add_issue "CPU governor set to 'performance'
     Why: schedutil dynamically follows scheduler load, same peak performance with better efficiency
     Fix: echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
        fi
    fi
else
    GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    if [[ "$GOV" == "schedutil" ]]; then
        ok "CPU governor: schedutil (optimal for desktop use)"
        explain "schedutil follows the kernel scheduler's own load signal to set CPU frequency — the most accurate governor for responsive desktops."
    elif [[ "$GOV" == "performance" ]]; then
        warn "CPU governor: performance (always-on boost — wastes power, schedutil is smarter)"
        explain "performance locks the CPU at max frequency permanently. schedutil achieves the same peak speed when needed while saving power when idle."
        add_issue "CPU governor set to 'performance' — schedutil is better
     Why: schedutil dynamically follows scheduler load, achieving same peak performance with better power efficiency
     Fix: echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
     Permanent: install cpupower and set GOVERNOR=schedutil in /etc/default/cpupower"
    else
        fail "CPU governor: $GOV (not optimal)"
        explain "This governor may be holding back CPU frequency even under load."
        add_issue "CPU governor set to '$GOV' — actively limiting performance
     Why: this governor caps CPU frequency, directly reducing responsiveness under any load
     Fix: echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
    fi
fi

# x86-64 instruction set level — correct detection via /proc/cpuinfo flags
HAS_V2=false
HAS_V3=false
HAS_V4=false

FLAGS=$(grep -m1 "^flags" /proc/cpuinfo)

# v2 requires: cx16, lahf_lm, popcnt, sse4_1, sse4_2, ssse3
if echo "$FLAGS" | grep -q "cx16" && echo "$FLAGS" | grep -q "popcnt" && echo "$FLAGS" | grep -q "sse4_2"; then
    HAS_V2=true
fi

# v3 requires: avx, avx2, bmi1, bmi2, fma, movbe
if echo "$FLAGS" | grep -q "avx2" && echo "$FLAGS" | grep -q "bmi2" && echo "$FLAGS" | grep -q "fma"; then
    HAS_V3=true
fi

# v4 requires: avx512f, avx512bw, avx512cd, avx512dq, avx512vl
if echo "$FLAGS" | grep -q "avx512f" && echo "$FLAGS" | grep -q "avx512bw"; then
    HAS_V4=true
fi

if $HAS_V4; then
    ok "CPU instruction set: x86-64-v4 (AVX-512) — highest tier"
    explain "Your CPU supports the widest vector operations available. Packages compiled for v4 get maximum SIMD gains."
elif $HAS_V3; then
    ok "CPU instruction set: x86-64-v3 (AVX2) — modern tier"
    explain "Your CPU supports AVX2/FMA. Packages compiled with -march=native or targeting v3 will use these"
    explain "for faster floating point, compression, and multimedia — a real gain over the generic Arch baseline."
elif $HAS_V2; then
    ok "CPU instruction set: x86-64-v2 — basic modern"
    explain "Supports SSE4.2/POPCNT. No AVX2, so gains from -march=native will be modest."
else
    warn "CPU instruction set: x86-64-v1 (generic baseline)"
fi

# CPU microcode
if [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
    UCODE_PKG="amd-ucode"
elif [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
    UCODE_PKG="intel-ucode"
else
    UCODE_PKG=""
fi

if [[ -n "$UCODE_PKG" ]]; then
    if pacman -Qq "$UCODE_PKG" &>/dev/null; then
        # Confirm the kernel actually applied microcode early at boot
        if journalctl -k -b 2>/dev/null | grep -qi "microcode"; then
            ok "CPU microcode: $UCODE_PKG installed and loaded by kernel"
            explain "Microcode delivers CPU bug fixes and security mitigations (Spectre/etc.) from the vendor."
            explain "Loaded early from initramfs before the kernel fully boots — exactly as it should be."
        else
            warn "CPU microcode: $UCODE_PKG installed but early-load not confirmed"
            explain "The package is present but the kernel log shows no microcode message — the initramfs"
            explain "image may not be referencing it. Verify your boot entry loads the *-ucode.img initrd."
            add_issue "$UCODE_PKG installed but microcode early-load not confirmed
     Why: without the ucode initrd in your boot entry, firmware fixes/mitigations are not applied
     Fix (systemd-boot): add 'initrd /$UCODE_PKG.img' BEFORE the main initramfs line in your boot entry
     Fix (GRUB/mkinitcpio): regenerate config; grub auto-detects ucode, mkinitcpio needs it in early initrd
     Verify: journalctl -k -b | grep microcode"
        fi
    else
        fail "CPU microcode: $UCODE_PKG not installed"
        explain "You are missing vendor CPU bug fixes and security mitigations applied at every boot."
        explain "This is a stability and security gap — the package is tiny and loads automatically."
        add_issue "$UCODE_PKG not installed — missing CPU firmware fixes and security mitigations
     Why: microcode patches CPU errata and Spectre-class vulnerabilities before the OS boots
     Fix: sudo pacman -S $UCODE_PKG
     Then: ensure your bootloader loads it (systemd-boot needs 'initrd /$UCODE_PKG.img' in the entry)"
    fi
fi

# ─── RAM ──────────────────────────────────────────────────────────────────────
section "Memory"

TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$(( TOTAL_RAM_KB / 1024 / 1024 ))
info "Total RAM: ${TOTAL_RAM_GB} GB"

RAM_SPEED=$(sudo dmidecode -t memory 2>/dev/null | grep "Configured Memory Speed" | head -1 | awk '{print $4}')
RAM_RATED=$(sudo dmidecode -t memory 2>/dev/null | grep -E "^\s+Speed:" | grep -v "Unknown" | head -1 | awk '{print $2}')
if [[ -n "$RAM_SPEED" && "$RAM_SPEED" =~ ^[0-9]+$ ]]; then
    RATED_LABEL=""
    [[ -n "$RAM_RATED" && "$RAM_RATED" =~ ^[0-9]+$ && "$RAM_RATED" -gt "$RAM_SPEED" ]] && RATED_LABEL=" (rated: ${RAM_RATED} MT/s)"
    if [[ -n "$RAM_RATED" && "$RAM_RATED" =~ ^[0-9]+$ && "$RAM_SPEED" -ge "$RAM_RATED" ]]; then
        ok "RAM speed: ${RAM_SPEED} MT/s — running at rated speed"
        if [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
            explain "On AMD, RAM speed ties directly to the Infinity Fabric clock which connects CPU cores,"
            explain "cache, and memory controller. Running at rated speed is optimal."
        else
            explain "Running at rated speed. Fast RAM improves memory bandwidth across all workloads."
        fi
    elif [[ "$RAM_SPEED" -ge 3200 ]]; then
        ok "RAM speed: ${RAM_SPEED} MT/s${RATED_LABEL}"
        explain "Good RAM speed. If your kit is rated higher, check BIOS for DOCP/XMP profile."
    elif [[ "$RAM_SPEED" -ge 2400 ]]; then
        warn "RAM speed: ${RAM_SPEED} MT/s${RATED_LABEL} — DOCP/XMP may not be enabled"
        if [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
            explain "AMD's Infinity Fabric runs at half your RAM speed — slower RAM directly reduces internal bandwidth."
        fi
        explain "Check BIOS for a DOCP or XMP profile matching your kit's rated speed."
        add_issue "RAM may not be running at rated speed (${RAM_SPEED} MT/s${RATED_LABEL})
     Why: RAM speed directly affects memory bandwidth; AMD systems also tie Infinity Fabric to RAM speed
     Fix: Reboot → enter BIOS → find 'DOCP' or 'XMP' profile → enable it → save and exit"
    else
        fail "RAM speed: ${RAM_SPEED} MT/s${RATED_LABEL} — significantly below rated speed"
        explain "This is a meaningful bottleneck. Enable DOCP/XMP in BIOS for an immediate improvement."
        add_issue "RAM running very slow (${RAM_SPEED} MT/s${RATED_LABEL}) — enable DOCP/XMP in BIOS
     Why: RAM speed directly affects memory bandwidth and system responsiveness
     Fix: Reboot → BIOS → enable DOCP/XMP profile → save and exit"
    fi
else
    warn "Could not read RAM speed (run with sudo for dmidecode access)"
fi

# Transparent Huge Pages
THP=$(cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null | grep -oP '\[\w+\]' | tr -d '[]')
if [[ "$THP" == "madvise" ]]; then
    ok "Transparent Huge Pages: madvise (optimal)"
    explain "madvise lets applications that know they benefit from huge pages opt in, while leaving"
    explain "small allocations alone. Better than 'always' which wastes memory on short-lived objects."
elif [[ "$THP" == "always" ]]; then
    warn "Transparent Huge Pages: always (wastes memory on mixed workloads)"
    explain "'always' forces huge pages even for small, short-lived allocations — this can actually hurt"
    explain "performance on a desktop with many small processes (browser tabs, system daemons, k3s pods)."
    add_issue "Transparent Huge Pages set to 'always' — madvise is better for desktop + homelab use
     Why: 'always' wastes memory on small allocations; 'madvise' lets apps opt in when they benefit
     Fix: echo madvise | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
     Permanent: add 'transparent_hugepage=madvise' to your kernel parameters"
else
    warn "Transparent Huge Pages: $THP"
fi

# Swappiness
SWAP=$(cat /proc/sys/vm/swappiness)
if [[ "$TOTAL_RAM_GB" -ge 16 ]]; then
    SWAP_THRESHOLD=10
else
    SWAP_THRESHOLD=30
fi
if [[ "$SWAP" -le "$SWAP_THRESHOLD" ]]; then
    ok "vm.swappiness: $SWAP (appropriate for ${TOTAL_RAM_GB}GB RAM)"
    explain "Low swappiness keeps data in fast RAM longer before touching the slower swap partition."
else
    warn "vm.swappiness: $SWAP — consider lowering for a ${TOTAL_RAM_GB}GB RAM system"
    explain "swappiness=$SWAP means the kernel starts moving memory to disk relatively early."
    explain "With ${TOTAL_RAM_GB}GB RAM you rarely need to swap. Keeping data in RAM is always faster."
    add_issue "vm.swappiness=$SWAP is higher than recommended for ${TOTAL_RAM_GB}GB RAM
     Why: the kernel will start swapping to disk unnecessarily, wasting fast RAM you have available
     Fix: echo 'vm.swappiness=${SWAP_THRESHOLD}' | sudo tee /etc/sysctl.d/99-swappiness.conf
          sudo sysctl -p /etc/sysctl.d/99-swappiness.conf"
fi

# Compressed swap (zram / zswap)
if swapon --show=NAME --noheadings 2>/dev/null | grep -q "zram"; then
    ZRAM_SIZE=$(zramctl --output DISKSIZE --noheadings 2>/dev/null | head -1 | tr -d ' ')
    ok "Compressed swap: zram active${ZRAM_SIZE:+ (${ZRAM_SIZE})}"
    explain "zram creates a compressed swap device in RAM — swapping hits memory speed instead of disk."
    explain "Lets you absorb memory spikes without touching the SSD, extending its life and staying fast."
elif [[ "$(cat /sys/module/zswap/parameters/enabled 2>/dev/null)" == "Y" ]]; then
    ok "Compressed swap: zswap enabled"
    explain "zswap compresses pages in RAM before they reach disk swap — a fast cache in front of swap."
else
    warn "Compressed swap: none (no zram or zswap)"
    explain "zram gives you a compressed in-RAM swap device. Under memory pressure, swapping compresses"
    explain "to RAM instead of crawling to disk — keeps the desktop responsive and spares SSD writes."
    add_issue "No compressed swap (zram/zswap) configured
     Why: under memory pressure, disk swap is orders of magnitude slower; zram swaps to compressed RAM
     Fix: sudo pacman -S zram-generator, then create /etc/systemd/zram-generator.conf:
       [zram0]
       zram-size = min(ram / 2, 8192)
       compression-algorithm = zstd
     Then: sudo systemctl daemon-reload && sudo systemctl start systemd-zram-setup@zram0"
fi

# Userspace OOM protection
if systemctl is-active systemd-oomd &>/dev/null; then
    ok "OOM protection: systemd-oomd active"
    explain "systemd-oomd watches memory pressure (PSI) and kills the worst offender early —"
    explain "before the whole system locks up waiting on the slow kernel OOM killer."
elif systemctl is-active earlyoom &>/dev/null; then
    ok "OOM protection: earlyoom active"
    explain "earlyoom kills runaway processes before memory is fully exhausted, avoiding desktop freezes."
else
    warn "OOM protection: none (no systemd-oomd or earlyoom)"
    explain "When memory runs out, the kernel's built-in OOM killer is slow to react — the desktop can"
    explain "freeze hard for minutes (a browser tab or runaway build). A userspace daemon prevents this."
    add_issue "No userspace OOM daemon (systemd-oomd or earlyoom)
     Why: the kernel OOM killer reacts late; under pressure the whole system can freeze before it acts
     Fix (built-in): sudo systemctl enable --now systemd-oomd
     Fix (alternative): sudo pacman -S earlyoom && sudo systemctl enable --now earlyoom"
fi

# ─── STORAGE ──────────────────────────────────────────────────────────────────
section "Storage"

# NVMe scheduler
for dev in /sys/block/nvme*; do
    [[ -e "$dev" ]] || continue
    name=$(basename "$dev")
    sched=$(cat "$dev/queue/scheduler" 2>/dev/null | grep -oP '\[\w+\]' | tr -d '[]')
    if [[ "$sched" == "none" ]]; then
        ok "NVMe $name I/O scheduler: none (correct)"
        explain "NVMe drives have their own internal queue and parallelism. Adding a kernel-level I/O"
        explain "scheduler on top just adds overhead — 'none' lets the drive manage itself optimally."
    else
        fail "NVMe $name I/O scheduler: $sched (should be 'none')"
        explain "A software scheduler on NVMe is redundant and adds latency. The drive handles queuing internally."
        add_issue "NVMe $name using wrong I/O scheduler ('$sched' instead of 'none')
     Why: NVMe has built-in NCQ — a software scheduler on top adds unnecessary latency overhead
     Fix: echo none | sudo tee /sys/block/$name/queue/scheduler
     Permanent: create /etc/udev/rules.d/60-ioschedulers.rules with:
       ACTION==\"add|change\", KERNEL==\"nvme*\", ATTR{queue/scheduler}=\"none\""
    fi
done

# HDD scheduler
for dev in /sys/block/sd*; do
    [[ -e "$dev" ]] || continue
    name=$(basename "$dev")
    rotational=$(cat "$dev/queue/rotational" 2>/dev/null)
    sched=$(cat "$dev/queue/scheduler" 2>/dev/null | grep -oP '\[\w+\]' | tr -d '[]')
    if [[ "$rotational" == "1" ]]; then
        if [[ "$sched" == "bfq" ]]; then
            ok "HDD $name I/O scheduler: bfq (optimal for spinning disk)"
            explain "BFQ (Budget Fair Queueing) prioritizes latency for interactive requests on slow spinning disks."
            explain "Prevents background tasks from starving foreground I/O — important when the HDD is busy."
        elif [[ "$sched" == "mq-deadline" ]]; then
            ok "HDD $name I/O scheduler: mq-deadline (acceptable for HDD)"
            explain "mq-deadline prevents I/O starvation and works well for HDDs, though bfq is slightly better for desktop use."
        elif [[ -z "$sched" ]]; then
            warn "HDD $name I/O scheduler: could not detect (possibly a virtual/USB device)"
            explain "Verify with: cat /sys/block/$name/queue/scheduler"
        else
            warn "HDD $name I/O scheduler: $sched (bfq recommended for spinning disks)"
            explain "bfq is specifically designed for rotational drives — it reduces seek latency and prevents"
            explain "a heavy background copy from making your whole system feel sluggish."
            add_issue "HDD $name not using optimal I/O scheduler ('$sched' instead of 'bfq')
     Why: bfq reduces seek latency and prevents background transfers from stalling foreground I/O
     Fix: echo bfq | sudo tee /sys/block/$name/queue/scheduler
     Permanent: add to /etc/udev/rules.d/60-ioschedulers.rules:
       ACTION==\"add|change\", KERNEL==\"sd*\", ATTR{queue/rotational}==\"1\", ATTR{queue/scheduler}=\"bfq\""
        fi
    fi
done

# fstrim
if systemctl is-enabled fstrim.timer &>/dev/null; then
    ok "fstrim.timer: enabled (weekly NVMe TRIM runs automatically)"
    explain "TRIM tells the NVMe drive which blocks are free so it can manage wear leveling and"
    explain "maintain write performance over time. Without it, write speed degrades gradually."
else
    fail "fstrim.timer: not enabled"
    explain "Without periodic TRIM, your NVMe's write performance will slowly degrade as the drive"
    explain "accumulates stale blocks it doesn't know are free. One command fixes this permanently."
    add_issue "fstrim.timer is not enabled — NVMe write performance degrades without TRIM
     Why: TRIM tells the drive which blocks are free for wear leveling and garbage collection
     Fix: sudo systemctl enable --now fstrim.timer
     (Runs automatically every week — no further maintenance needed)"
fi

# noatime
if grep -q "noatime" /etc/fstab; then
    ok "noatime: set in fstab (reduces unnecessary write overhead)"
    explain "Without noatime, Linux updates a file's 'last accessed' timestamp on every single read."
    explain "On NVMe this is low-impact, but on HDDs it means extra seeks for pure reads."
else
    warn "noatime: not set in fstab"
    explain "Every file read triggers a metadata write to update the access timestamp."
    explain "Mostly harmless on NVMe, but worth setting on HDDs to reduce unnecessary writes."
    add_issue "noatime not set in fstab — causes unnecessary write-on-read overhead
     Why: default 'atime' writes a timestamp on every file read — pure overhead with no benefit
     Fix: add 'noatime' to the options column in /etc/fstab for your / and /home partitions
     Example: UUID=xxxx  /  ext4  defaults,noatime  0 1"
fi

# ─── GPU ──────────────────────────────────────────────────────────────────────
section "GPU"

GPU_NAME=$(lspci 2>/dev/null | grep -Ei "VGA|3D|Display" | head -1 | sed 's/.*: //')
[[ -n "$GPU_NAME" ]] && info "GPU: $GPU_NAME"
GPU_KIND="unknown"

if lsmod | grep -q "^nvidia "; then
    GPU_KIND="nvidia"
    NVIDIA_VER=$(modinfo nvidia 2>/dev/null | grep "^version" | awk '{print $2}')
    ok "NVIDIA proprietary driver loaded (version $NVIDIA_VER)"
    explain "The proprietary driver is required for full NVIDIA GPU performance, Wayland support,"
    explain "and hardware-accelerated video encode/decode (NVENC/NVDEC)."

    # DRM modesetting
    if grep -q "nvidia-drm.modeset=1" /proc/cmdline; then
        ok "nvidia-drm.modeset=1: active"
        explain "Required for NVIDIA to hand off display control to the kernel's DRM subsystem,"
        explain "which is what enables Wayland compositing with NVIDIA GPUs."
    elif grep -rq "nvidia-drm.modeset=1" /etc/kernel/ /boot/loader/ /etc/default/grub 2>/dev/null; then
        ok "nvidia-drm.modeset=1: configured in bootloader (active after next boot)"
    else
        fail "nvidia-drm.modeset=1: not set"
        explain "Without this, NVIDIA can't properly integrate with the kernel's display stack."
        explain "Wayland will either not work or show tearing/black screens."
        add_issue "nvidia-drm.modeset=1 missing — Wayland will not work correctly with NVIDIA
     Why: enables kernel modesetting so NVIDIA integrates with the DRM display subsystem
     Fix (systemd-boot): add 'nvidia-drm.modeset=1' to /boot/loader/entries/arch.conf options line
     Fix (GRUB): add to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub, then run grub-mkconfig"
    fi

    # nvidia-powerd (Ampere / RTX 30+ only)
    NVIDIA_ARCH=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>/dev/null | head -1)
    if echo "$NVIDIA_ARCH" | grep -qiE "RTX 3|RTX 4|RTX 5|A[0-9]{3,4}"; then
        if systemctl is-active nvidia-powerd &>/dev/null; then
            ok "nvidia-powerd: running (dynamic power management active)"
            explain "nvidia-powerd enables fine-grained power state transitions on Ampere+ GPUs,"
            explain "reducing idle power consumption without affecting gaming/compute performance."
        else
            warn "nvidia-powerd: not running"
            explain "Manages dynamic power states on Ampere+ (RTX 30/40) architecture — worth enabling."
            add_issue "nvidia-powerd not running — minor power management gap
     Why: manages dynamic power states for Ampere+ NVIDIA GPUs
     Fix: sudo systemctl enable --now nvidia-powerd"
        fi
    fi

elif lsmod | grep -q "^nouveau "; then
    GPU_KIND="nouveau"
    fail "Using nouveau (open source) driver — performance is severely limited"
    explain "nouveau cannot reclock modern NVIDIA GPUs, has no NVENC/NVDEC, and poor Wayland integration."
    add_issue "Running nouveau instead of proprietary NVIDIA driver
     Why: nouveau cannot reclock the GPU — you're running at a fraction of its actual performance
     Fix: sudo pacman -S nvidia nvidia-utils libva-nvidia-driver && reboot"

elif echo "$GPU_NAME" | grep -qi "Intel" || lsmod | grep -qE "^i915 |^xe "; then
    GPU_KIND="intel"
    if lsmod | grep -q "^xe "; then
        ok "Intel GPU driver (xe) loaded"
        explain "xe is the modern Intel GPU driver (Arc and Lunar Lake+) — open source and Wayland-native."
    else
        ok "Intel GPU driver (i915) loaded"
        explain "i915 is the mainline Intel GPU driver — open source, zero setup, excellent Wayland support."
    fi

    # Hardware video acceleration (VA-API)
    if pacman -Qq intel-media-driver &>/dev/null || pacman -Qq libva-intel-driver &>/dev/null; then
        ok "Intel VA-API driver installed (hardware video decode available)"
        explain "Lets the GPU decode H.264/HEVC/VP9 video, cutting CPU use and power during playback."
    else
        warn "No Intel VA-API driver — video decoding falls back to the CPU"
        explain "Without it, video playback is decoded on the CPU: higher power draw and more heat,"
        explain "which matters most on a laptop. The driver hands decoding to the GPU instead."
        add_issue "Intel VA-API driver not installed — no hardware video acceleration
     Why: video decode runs on the CPU instead of the GPU, wasting power and battery on a laptop
     Fix: sudo pacman -S intel-media-driver   (Broadwell/Gen8 and newer)
     Older GPUs (pre-2014): sudo pacman -S libva-intel-driver
     Verify: vainfo   (from the libva-utils package)"
    fi

elif echo "$GPU_NAME" | grep -qiE "AMD|ATI|Radeon" || lsmod | grep -q "^amdgpu "; then
    GPU_KIND="amd"
    ok "AMD GPU driver (amdgpu) loaded"
    explain "amdgpu is the mainline kernel driver for modern AMD GPUs — fully open source and well supported."

    # Check for firmware
    if dmesg 2>/dev/null | grep -qi "amdgpu.*firmware"; then
        ok "AMD GPU firmware: loaded"
    fi

    # ROCm (optional but useful for compute)
    if command -v rocminfo &>/dev/null; then
        ok "ROCm: installed (GPU compute available)"
        explain "ROCm enables GPU compute workloads (ML, video transcoding) on AMD hardware."
    fi

    # DRM/Wayland is native with amdgpu — check for issues
    if dmesg 2>/dev/null | grep -qi "amdgpu.*error\|amdgpu.*fail"; then
        warn "amdgpu: kernel messages contain errors — check: dmesg | grep amdgpu"
    fi

else
    warn "Could not detect GPU driver (nvidia, nouveau, amdgpu, or i915/xe)"
fi

# ─── THERMALS ───────────────────────────────────────────────────────────────────
section "Thermals"

# Highest CPU-package temperature from hwmon (no extra packages needed)
CPU_TEMP=0
for hwmon in /sys/class/hwmon/hwmon*; do
    [[ -r "$hwmon/name" ]] || continue
    case "$(cat "$hwmon/name" 2>/dev/null)" in
        k10temp|zenpower|coretemp)
            for t in "$hwmon"/temp*_input; do
                [[ -r "$t" ]] || continue
                val=$(cat "$t" 2>/dev/null)
                [[ "$val" =~ ^[0-9]+$ && "$val" -gt "$CPU_TEMP" ]] && CPU_TEMP=$val
            done
            ;;
    esac
done
CPU_TEMP=$(( CPU_TEMP / 1000 ))

if [[ "$CPU_TEMP" -gt 0 ]]; then
    if [[ "$CPU_TEMP" -lt 80 ]]; then
        ok "CPU temperature: ${CPU_TEMP}°C"
        explain "Healthy. CPUs throttle around 90-95°C, so there is comfortable headroom for boost."
    elif [[ "$CPU_TEMP" -lt 90 ]]; then
        warn "CPU temperature: ${CPU_TEMP}°C (warm)"
        explain "Fine under sustained load, but if this is idle or light use your cooling needs attention"
        explain "(dust, fan curve, or dried thermal paste). High temps make the CPU throttle and lose boost."
    else
        fail "CPU temperature: ${CPU_TEMP}°C (very hot — likely throttling)"
        explain "At this temperature the CPU is reducing its own frequency to protect itself, costing performance."
        add_issue "CPU running very hot (${CPU_TEMP}°C) — thermal throttling likely
     Why: above ~90°C the CPU downclocks itself; you lose the boost everything else here is tuning for
     Fix: check fan operation and airflow, clean dust, reseat cooler / reapply thermal paste
     Monitor: watch -n1 sensors  (install lm_sensors for detailed per-core readings)"
    fi
else
    warn "CPU temperature: could not read from hwmon"
    explain "No k10temp/coretemp sensor exposed. Install lm_sensors and run sensors-detect for readings."
fi

# Thermal throttling counter (Intel exposes this per-core; cumulative since boot)
THROTTLE_TOTAL=0
for f in /sys/devices/system/cpu/cpu*/thermal_throttle/core_throttle_count; do
    [[ -r "$f" ]] || continue
    c=$(cat "$f" 2>/dev/null)
    [[ "$c" =~ ^[0-9]+$ ]] && THROTTLE_TOTAL=$(( THROTTLE_TOTAL + c ))
done
if [[ "$THROTTLE_TOTAL" -gt 0 ]]; then
    warn "Thermal throttle events recorded: $THROTTLE_TOTAL (since boot)"
    explain "The CPU has hit its thermal limit and downclocked at least once. Improve cooling to recover"
    explain "lost performance — sustained workloads are the most affected."
    add_issue "CPU has logged $THROTTLE_TOTAL thermal throttle event(s) since boot
     Why: each event means the CPU downclocked to avoid overheating, reducing performance
     Fix: improve case airflow, clean dust from heatsink/fans, reapply thermal paste if old"
fi

# GPU temperature (informational) — only for the GPU we actually detected.
# Intel/AMD iGPUs share the CPU die and have no separate sensor, so we skip them.
if [[ "$GPU_KIND" == "nvidia" ]] && command -v nvidia-smi &>/dev/null; then
    GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1)
    [[ "$GPU_TEMP" =~ ^[0-9]+$ ]] && info "GPU temperature: ${GPU_TEMP}°C"
elif [[ "$GPU_KIND" == "amd" ]]; then
    for hwmon in /sys/class/hwmon/hwmon*; do
        [[ "$(cat "$hwmon/name" 2>/dev/null)" == "amdgpu" ]] || continue
        raw=$(cat "$hwmon/temp1_input" 2>/dev/null)
        [[ "$raw" =~ ^[0-9]+$ ]] || continue   # skip phantom/busy sensors
        info "GPU temperature: $(( raw / 1000 ))°C"
        break
    done
fi

# ─── KDE ──────────────────────────────────────────────────────────────────────
section "KDE Plasma"

SESSION=${XDG_SESSION_TYPE:-unknown}
if [[ "$SESSION" == "wayland" ]]; then
    ok "Session type: Wayland"
    explain "Wayland gives you proper HiDPI scaling, better input latency, smoother multi-monitor"
    explain "handling, and no screen tearing — all relevant for KDE Plasma 6."
elif [[ "$SESSION" == "x11" ]]; then
    warn "Session type: X11 — Plasma 6 Wayland is now stable and recommended"
    explain "X11 is a 40-year-old display protocol. KDE Plasma 6 on Wayland has better input latency,"
    explain "native HiDPI, no tearing, and better NVIDIA support with the current driver stack."
    add_issue "Running X11 instead of Wayland
     Why: Plasma 6 Wayland is stable and offers better latency, scaling, and NVIDIA integration
     Fix: at the SDDM login screen, select 'Plasma (Wayland)' from the session menu (bottom-left)"
else
    warn "Session type: unknown ($SESSION) — could not detect display server"
fi

# Baloo
if command -v balooctl &>/dev/null; then
    BALOO=$(balooctl status 2>/dev/null | head -1)
    if echo "$BALOO" | grep -qi "disabled\|not running"; then
        ok "Baloo file indexer: disabled"
        explain "Baloo indexes all your files for KDE Search. If you don't use that feature,"
        explain "disabling it eliminates background I/O that can cause occasional disk activity spikes."
    else
        warn "Baloo file indexer: running"
        explain "Baloo continuously indexes your files in the background. Useful if you use KDE's"
        explain "file search (Dolphin search or KRunner), but causes I/O spikes if you don't."
        add_issue "Baloo file indexer is running — consider disabling if you don't use KDE file search
     Why: causes background I/O activity especially after updates or large file operations
     Fix (disable): balooctl disable
     Fix (re-enable if needed): balooctl enable && balooctl start"
    fi
fi

if command -v plasmashell &>/dev/null; then
    PLASMA_VER=$(plasmashell --version 2>/dev/null | awk '{print $2}')
    ok "KDE Plasma version: $PLASMA_VER"
fi

# ─── SYSTEM HEALTH ──────────────────────────────────────────────────────────────
section "System Health"

# Failed systemd units
FAILED=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}')
FAILED_COUNT=$(printf '%s\n' "$FAILED" | grep -c .)
if [[ "$FAILED_COUNT" -eq 0 ]]; then
    ok "systemd: no failed units"
    explain "Every system service started cleanly. A failed unit often points to a real, silent problem."
else
    fail "systemd: $FAILED_COUNT failed unit(s)"
    while read -r unit; do
        [[ -n "$unit" ]] && explain "$unit"
    done <<< "$FAILED"
    add_issue "$FAILED_COUNT systemd unit(s) in failed state
     Why: a failed service may mean broken hardware, a misconfigured daemon, or an incomplete update
     Fix: systemctl --failed   (list them)
          journalctl -xeu <unit-name>   (see why it failed)
          systemctl restart <unit-name>   (after fixing the cause)"
fi

# Pending .pacnew config files
PACNEW=$(find /etc -name '*.pacnew' 2>/dev/null)
PACNEW_COUNT=$(printf '%s\n' "$PACNEW" | grep -c .)
if [[ "$PACNEW_COUNT" -eq 0 ]]; then
    ok "No .pacnew files — config files are merged"
    explain "When a package ships an updated default config, pacman leaves a .pacnew beside yours to merge."
else
    warn "$PACNEW_COUNT .pacnew file(s) pending review"
    while read -r f; do
        [[ -n "$f" ]] && explain "$f"
    done <<< "$PACNEW"
    explain "These are updated default configs pacman could not merge automatically — review them so you"
    explain "don't miss new defaults or keep stale settings (e.g. pacman.conf, sshd_config, fstab)."
    add_issue "$PACNEW_COUNT .pacnew file(s) need manual merging
     Why: package updates shipped new default configs; ignoring them means missing changes or breakage
     Fix: sudo pacdiff   (interactive merge tool from the pacman-contrib package)
     Manual: compare each with: diff /etc/<file> /etc/<file>.pacnew"
fi

# ─── MAKEPKG ──────────────────────────────────────────────────────────────────
section "Build Optimizations (makepkg)"

MAKEPKG_CONF="/etc/makepkg.conf"

if grep -q "\-march=native" "$MAKEPKG_CONF" 2>/dev/null; then
    ok "makepkg CFLAGS: -march=native set"
    explain "Every AUR package you compile will use your CPU's full instruction set."
    explain "Official Arch packages target the generic x86-64-v2 baseline — yours will be faster."
else
    warn "makepkg CFLAGS: -march=native not set"
    explain "Right now AUR packages compile for generic x86-64, ignoring CPU-specific instructions"
    explain "your processor supports. Adding -march=native fixes this for every future AUR build."
    add_issue "-march=native not set in /etc/makepkg.conf
     Why: without it, every AUR package you compile targets the lowest common denominator (x86-64-v2)
          and ignores AVX2/FMA/BMI2 and other instructions your CPU supports
     Fix: edit /etc/makepkg.conf, find the CFLAGS line and add -march=native (remove -mtune=generic if present)
     Example: CFLAGS=\"-march=native -O2 -pipe -fno-plt ...\""
fi

if grep -q "MAKEFLAGS.*-j" "$MAKEPKG_CONF" 2>/dev/null; then
    JFLAGS=$(grep "^MAKEFLAGS" "$MAKEPKG_CONF" 2>/dev/null)
    ok "makepkg MAKEFLAGS: $JFLAGS"
    explain "AUR builds will use all available CPU threads in parallel — much faster compilation."
else
    warn "makepkg MAKEFLAGS: -j not set (AUR builds use only 1 thread)"
    explain "Your CPU has $CPU_THREADS threads. Without -j, makepkg uses just 1 of them."
    explain "A build that takes 10 minutes single-threaded might take under 1 minute with all cores."
    add_issue "MAKEFLAGS not configured in /etc/makepkg.conf — AUR builds are single-threaded
     Why: makepkg defaults to 1 thread; your $CPU_THREADS threads sit idle during builds
     Fix: add this line to /etc/makepkg.conf:
          MAKEFLAGS=\"-j\$(nproc)\""
fi

# Check for -mtune=generic conflicting with -march=native
if grep -q "\-march=native" "$MAKEPKG_CONF" 2>/dev/null && grep -q "\-mtune=generic" "$MAKEPKG_CONF" 2>/dev/null; then
    warn "makepkg CFLAGS: -mtune=generic conflicts with -march=native"
    explain "-march=native already implies tuning for your exact CPU. -mtune=generic overrides that"
    explain "tuning back to generic — they're fighting each other. Remove -mtune=generic."
    add_issue "-mtune=generic conflicts with -march=native in /etc/makepkg.conf
     Why: -march=native implies optimal tuning for your CPU; -mtune=generic overrides it back to generic
     Fix: remove -mtune=generic from your CFLAGS line in /etc/makepkg.conf"
fi

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
section "Summary"

if [[ ${#ISSUES[@]} -eq 0 ]]; then
    echo -e "\n${GRN}${BOLD}  Everything looks good! Your system is well optimized.${NC}\n"
else
    echo -e "\n${YEL}${BOLD}  ${#ISSUES[@]} issue(s) to address:${NC}\n"
    for i in "${!ISSUES[@]}"; do
        echo -e "  ${BOLD}$((i+1)).${NC} ${ISSUES[$i]}\n"
    done
fi
