#!/bin/sh
# plasmashell froze (panels and Meta shortcuts dead, windows fine)? Run this: it aborts
# the stuck plasmashell so systemd-coredump keeps its state, saves every thread's stack
# from that core, then makes sure plasmashell is back. No sudo needed (ptrace_scope 1
# blocks attaching to the live process, but reading our own core dump is fine).
#   dev/shell-hang.sh            -> ~/.local/state/plasma-hud/hang-<time>.txt
set -u
pid=$(pgrep -x plasmashell | head -1)
[ -n "$pid" ] || { echo "plasmashell is not running"; exit 1; }
dir="${XDG_STATE_HOME:-$HOME/.local/state}/plasma-hud"
mkdir -p "$dir"
out="$dir/hang-$(date +%Y%m%d-%H%M%S).txt"
{
    echo "plasmashell $pid  $(date)"
    ps -o pid,stat,pcpu,etime,wchan:32 -L -p "$pid" | head -40
    echo
    journalctl --user -b --since "-15min" -o short-precise _PID="$pid" 2>/dev/null | tail -60
} > "$out"
kill -ABRT "$pid"
# Wait for systemd-coredump to finish writing the core.
for _ in $(seq 1 30); do
    coredumpctl -q info "$pid" 2>/dev/null | grep -q "Storage:.*present" && break
    sleep 1
done
coredumpctl -q gdb "$pid" -A "-batch -ex 'thread apply all bt 25'" >> "$out" 2>&1 < /dev/null
echo "stack saved: $out"
sleep 2
systemctl --user is-active -q plasma-plasmashell || systemctl --user restart plasma-plasmashell
echo "plasmashell running again"
