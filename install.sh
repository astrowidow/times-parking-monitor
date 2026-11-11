#!/bin/zsh
# launchd に3つ登録する（何度実行してもよい。フォルダを移したら再実行）。
#   collect … 5分おきに collect.py を動かし、data/log.csv に追記する
#   awake   … 終了日まで Mac をスリープさせない（ディスプレイは消えてよい）
#   cleanup … 1時間おきに確かめ、終了日を過ぎたら cleanup.sh で片付ける
#
#   ./install.sh        登録する
#   ./install.sh stop   すべて外す（記録は残る）
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
AGENTS="$HOME/Library/LaunchAgents"
PREFIX=local.times-parking-monitor
UID_=$(id -u)

unload() {
  for name in collect awake cleanup; do
    launchctl bootout "gui/$UID_/$PREFIX.$name" 2>/dev/null || true
    rm -f "$AGENTS/$PREFIX.$name.plist"
  done
}

# $1=名前 $2=起動するもの $3=いつ動かすか（plist の断片）
write_plist() {
  cat > "$AGENTS/$PREFIX.$1.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$PREFIX.$1</string>
  <key>ProgramArguments</key>
  <array>
$2
  </array>
  <key>RunAtLoad</key><true/>
$3
  <key>StandardOutPath</key><string>/dev/null</string>
  <key>StandardErrorPath</key><string>$DIR/data/$1.err.log</string>
</dict>
</plist>
EOF
  plutil -lint "$AGENTS/$PREFIX.$1.plist" >/dev/null
  launchctl bootstrap "gui/$UID_" "$AGENTS/$PREFIX.$1.plist"
}

unload
if [ "${1:-}" = stop ]; then
  echo "すべて外しました（記録は $DIR/data に残っています）"
  exit 0
fi

mkdir -p "$AGENTS" "$DIR/data"
write_plist collect \
  "    <string>/usr/bin/python3</string><string>$DIR/collect.py</string>" \
  "  <key>StartInterval</key><integer>300</integer>"
write_plist awake \
  "    <string>/bin/zsh</string><string>$DIR/keep_awake.sh</string>" \
  "  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>"
write_plist cleanup \
  "    <string>/bin/zsh</string><string>$DIR/cleanup.sh</string>" \
  "  <key>StartInterval</key><integer>3600</integer>"

echo "登録しました: 5分おきの取得 / スリープ防止 / 終了日の片付け"
echo "記録先: $DIR/data/log.csv"
