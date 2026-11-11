#!/bin/zsh
# cleanup.sh を launchd に予約する（1時間おきと、ログイン時に確かめる。12/1 より前は何もしない）。
#   ./schedule_cleanup.sh          予約する
#   ./schedule_cleanup.sh cancel   予約を取り消す
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL=local.times-parking-monitor.cleanup
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
if [ "${1:-}" = cancel ]; then
  rm -f "$PLIST"
  echo "片付けの予約を取り消しました"
  exit 0
fi

mkdir -p "$HOME/Library/LaunchAgents" "$DIR/data"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>$DIR/cleanup.sh</string>
  </array>
  <key>StartInterval</key><integer>3600</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>/dev/null</string>
  <key>StandardErrorPath</key><string>/dev/null</string>
</dict>
</plist>
EOF
plutil -lint "$PLIST" >/dev/null
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "片付けを予約しました（2026-12-01 以降に Mac が起きている最初の機会に動く）"
