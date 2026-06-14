#!/usr/bin/env bash
# arch-check.sh — System optimization checker for Arch Linux
# Tailored for: Ryzen 3700X, RTX 3060, NVMe + HDD, KDE

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

# Governor / amd-pstate-epp detection
DRIVER=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null)

if [[ "$DRIVER" == "amd-pstate-epp" ]]; then
    EPP=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null)
    if [[ "$EPP" == "balance_performance" || "$EPP" == "performance" ]]; then
        ok "CPU driver: amd-pstate-epp | preference: $EPP"
        explain "Modern Ryzen driver — communicates directly with CPU firmware for smarter boost decisions."
        explain "balance_performance is the sweet spot: full Precision Boost with reasonable power draw."
    else
        warn "CPU driver: amd-pstate-epp | preference: $EPP (suboptimal)"
        explain "amd-pstate-epp is the right driver, but '$EPP' limits how aggressively the CPU boosts."
        explain "balance_performance lets Precision Boost run freely without pegging power consumption."
        add_issue "EPP preference is '$EPP' — suboptimal for desktop performance
     Why: amd-pstate-epp controls Ryzen boost via firmware; wrong preference caps performance
     Fix: echo balance_performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
     Permanent: sudo tee /etc/udev/rules.d/99-amd-pstate.rules <<'EOF'
ACTION==\"add\", SUBSYSTEM==\"cpu\", ATTR{cpufreq/energy_performance_preference}=\"balance_performance\"
EOF"
    fi
else
    GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    if [[ "$GOV" == "schedutil" ]]; then
        ok "CPU governor: schedutil (optimal for Ryzen Precision Boost)"
        explain "schedutil follows the kernel scheduler's own load signal to set CPU frequency — the most accurate governor for responsive desktops."
    elif [[ "$GOV" == "performance" ]]; then
        warn "CPU governor: performance (always-on boost — wastes power, schedutil is smarter)"
        explain "performance locks the CPU at max frequency permanently. schedutil achieves the same peak speed when needed while saving power when idle."
        add_issue "CPU governor set to 'performance' — schedutil is better for Ryzen
     Why: schedutil dynamically follows scheduler load, achieving same peak performance with better power efficiency
     Fix: echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
     Permanent: install cpupower and set GOVERNOR=schedutil in /etc/default/cpupower"
    else
        fail "CPU governor: $GOV (not optimal)"
        explain "powersave deliberately holds back your CPU frequency even under load."
        add_issue "CPU governor set to '$GOV' — actively limiting performance
     Why: powersave caps CPU frequency, directly reducing responsiveness under any load
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

# ─── RAM ──────────────────────────────────────────────────────────────────────
section "Memory"

RAM_SPEED=$(sudo dmidecode -t memory 2>/dev/null | grep "Configured Memory Speed" | head -1 | awk '{print $4}')
if [[ -n "$RAM_SPEED" && "$RAM_SPEED" =~ ^[0-9]+$ ]]; then
    if [[ "$RAM_SPEED" -ge 3600 ]]; then
        ok "RAM speed: ${RAM_SPEED} MT/s — DOCP/XMP active"
        explain "Running at rated speed. On Ryzen, RAM speed ties directly to the Infinity Fabric clock"
        explain "which connects CPU cores, cache, and memory controller. Fast RAM = faster everything."
    elif [[ "$RAM_SPEED" -ge 2666 ]]; then
        warn "RAM speed: ${RAM_SPEED} MT/s — your kit is rated 3600, DOCP/XMP not enabled"
        explain "Ryzen's Infinity Fabric runs at half your RAM speed. At 2133 MT/s your fabric clock is ~1066 MHz."
        explain "At 3600 MT/s it would be ~1800 MHz — a massive internal bandwidth difference felt across all workloads."
        add_issue "RAM not running at rated speed (${RAM_SPEED} MT/s vs 3600 MT/s rated)
     Why: Ryzen Infinity Fabric speed = RAM speed / 2. Slower RAM directly bottlenecks CPU-to-memory bandwidth
     Fix: Reboot → enter BIOS → find 'DOCP' or 'XMP' profile → enable it → save and exit
     Result: immediate system-wide performance improvement, biggest single gain available to you"
    else
        fail "RAM speed: ${RAM_SPEED} MT/s — significantly below rated speed"
        explain "This is a major bottleneck on Ryzen. Enable DOCP in BIOS immediately."
        add_issue "RAM running very slow (${RAM_SPEED} MT/s) — enable DOCP in BIOS immediately
     Why: Ryzen is uniquely sensitive to RAM speed due to the Infinity Fabric architecture
     Fix: Reboot → BIOS → enable DOCP/XMP profile → your kit will run at its rated 3600 MT/s"
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
if [[ "$SWAP" -le 10 ]]; then
    ok "vm.swappiness: $SWAP (good for 32GB RAM systems)"
    explain "Low swappiness keeps data in fast RAM longer before touching the slower swap partition."
else
    warn "vm.swappiness: $SWAP — too eager to swap for a 32GB system"
    explain "swappiness=$SWAP means the kernel starts moving memory to disk relatively early."
    explain "With 32GB RAM you almost never need to swap. Keeping data in RAM is always faster."
    add_issue "vm.swappiness=$SWAP is too high for 32GB RAM
     Why: the kernel will start swapping to disk unnecessarily, wasting fast RAM you have available
     Fix: echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf
          sudo sysctl -p /etc/sysctl.d/99-swappiness.conf"
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
            explain "If this is your 4TB data drive, verify with: cat /sys/block/$name/queue/scheduler"
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
    explain "On an NVMe this is low-impact, but on your 4TB HDD it means extra seeks for pure reads."
else
    warn "noatime: not set in fstab"
    explain "Every file read triggers a metadata write to update the access timestamp."
    explain "Mostly harmless on NVMe, but worth setting on the HDD to reduce unnecessary writes."
    add_issue "noatime not set in fstab — causes unnecessary write-on-read overhead
     Why: default 'atime' writes a timestamp on every file read — pure overhead with no benefit
     Fix: add 'noatime' to the options column in /etc/fstab for your / and /home partitions
     Example: UUID=xxxx  /  ext4  defaults,noatime  0 1"
fi

# ─── GPU ──────────────────────────────────────────────────────────────────────
section "GPU (RTX 3060)"

if lsmod | grep -q "^nvidia "; then
    NVIDIA_VER=$(modinfo nvidia 2>/dev/null | grep "^version" | awk '{print $2}')
    ok "NVIDIA proprietary driver loaded (version $NVIDIA_VER)"
    explain "The proprietary driver is required for full RTX 3060 performance, Wayland support,"
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
        explain "KDE Wayland will either not work or show tearing/black screens."
        add_issue "nvidia-drm.modeset=1 missing — Wayland will not work correctly with NVIDIA
     Why: enables kernel modesetting so NVIDIA integrates with the DRM display subsystem
     Fix (systemd-boot): add 'nvidia-drm.modeset=1' to /boot/loader/entries/arch.conf options line
     Fix (GRUB): add to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub, then run grub-mkconfig"
    fi

    # nvidia-powerd
    if systemctl is-active nvidia-powerd &>/dev/null; then
        ok "nvidia-powerd: running (Ampere dynamic power management active)"
        explain "nvidia-powerd enables fine-grained power state transitions on RTX 30 series,"
        explain "reducing idle power consumption without affecting gaming/compute performance."
    else
        warn "nvidia-powerd: not running"
        explain "On desktop RTX cards the impact is minor, but it enables proper power state management"
        explain "for the RTX 30 series (Ampere architecture) — worth enabling."
        add_issue "nvidia-powerd not running — minor power management gap on RTX 3060
     Why: manages dynamic power states specific to Ampere (RTX 30) architecture
     Fix: sudo systemctl enable --now nvidia-powerd"
    fi

elif lsmod | grep -q "^nouveau "; then
    fail "Using nouveau (open source) driver — not suitable for RTX 3060"
    explain "nouveau has no support for RTX 3060 reclocking, no NVENC/NVDEC, and poor Wayland integration."
    add_issue "Running nouveau instead of proprietary NVIDIA driver
     Why: nouveau cannot reclock RTX 3060 — you're running at a fraction of its actual performance
     Fix: sudo pacman -S nvidia nvidia-utils libva-nvidia-driver && reboot"
else
    warn "Could not detect GPU driver module"
fi

# ─── KDE ──────────────────────────────────────────────────────────────────────
section "KDE Plasma"

SESSION=${XDG_SESSION_TYPE:-unknown}
if [[ "$SESSION" == "wayland" ]]; then
    ok "Session type: Wayland"
    explain "Wayland gives you proper HiDPI scaling, better input latency, smoother multi-monitor"
    explain "handling, and no screen tearing — all relevant for KDE Plasma 6 on NVIDIA."
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

# ─── MAKEPKG ──────────────────────────────────────────────────────────────────
section "Build Optimizations (makepkg)"

MAKEPKG_CONF="/etc/makepkg.conf"

if grep -q "\-march=native" "$MAKEPKG_CONF" 2>/dev/null; then
    ok "makepkg CFLAGS: -march=native set"
    explain "Every AUR package you compile will use your CPU's full instruction set (AVX2, FMA, BMI2)."
    explain "Official Arch packages target the generic x86-64-v2 baseline — yours will be faster."
else
    warn "makepkg CFLAGS: -march=native not set"
    explain "Right now AUR packages compile for generic x86-64, ignoring AVX2 and other instructions"
    explain "your Ryzen 3700X supports. Adding -march=native fixes this for every future AUR build."
    add_issue "-march=native not set in /etc/makepkg.conf
     Why: without it, every AUR package you compile targets the lowest common denominator (x86-64-v2)
          and ignores AVX2/FMA/BMI2 your CPU supports — leaving performance on the table
     Fix: edit /etc/makepkg.conf, find the CFLAGS line and add -march=native (remove -mtune=generic if present)
     Example: CFLAGS=\"-march=native -O2 -pipe -fno-plt ...\"
     Result: every AUR package you compile from now on will use your CPU's full capabilities"
fi

if grep -q "MAKEFLAGS.*-j" "$MAKEPKG_CONF" 2>/dev/null; then
    JFLAGS=$(grep "^MAKEFLAGS" "$MAKEPKG_CONF" 2>/dev/null)
    ok "makepkg MAKEFLAGS: $JFLAGS"
    explain "AUR builds will use all available CPU threads in parallel — much faster compilation."
else
    warn "makepkg MAKEFLAGS: -j not set (AUR builds use only 1 thread)"
    explain "Your Ryzen 3700X has 16 threads. Without -j, makepkg uses just 1 of them."
    explain "A build that takes 10 minutes single-threaded might take under 1 minute with all cores."
    add_issue "MAKEFLAGS not configured in /etc/makepkg.conf — AUR builds are single-threaded
     Why: makepkg defaults to 1 thread; your 3700X has 16 threads sitting idle during builds
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
