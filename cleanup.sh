#!/bin/zsh
# 終了日（2026-12-01、日本時間）以降に1回だけ、次を順に行う。install.sh が launchd から1時間おきに呼ぶ。
#   1. 取得（collect）とスリープ防止（awake）を止める
#   2. 最終レポート（report.html）を作る
#   3. GitHub のリポジトリを消す（GitHub の設定画面から90日以内なら戻せる）。失敗したら次の回にやり直す
#   4. 自分の予約（cleanup）を外す
# 手元のフォルダと記録（data/log.csv）はそのまま残る。
# 試し運転: END_DATE=20200101 DRY_RUN=1 ./cleanup.sh   （レポートだけ作り、ほかの操作は表示だけ）
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
REPO=astrowidow/times-parking-monitor
END_DATE="${END_DATE:-20261201}"
PREFIX=local.times-parking-monitor
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

[ "$(TZ=Asia/Tokyo date +%Y%m%d)" -lt "$END_DATE" ] && exit 0

run() { if [ -n "${DRY_RUN:-}" ]; then echo "(試し運転) $*"; else "$@"; fi; }
notify() { [ -n "${DRY_RUN:-}" ] && { echo "(通知) $1"; return; }; osascript -e "display notification \"$1\" with title \"駐車場の監視\"" >/dev/null 2>&1 || true; }
remove_agent() {
  run rm -f "$HOME/Library/LaunchAgents/$PREFIX.$1.plist"
  run launchctl bootout "gui/$(id -u)/$PREFIX.$1" 2>/dev/null || true
}

cd "$DIR"
[ -z "${DRY_RUN:-}" ] && exec >> "$DIR/data/cleanup.log" 2>&1
echo "== $(date '+%F %T') 片付けを始める"

remove_agent collect
remove_agent awake
/usr/bin/python3 report.py > /dev/null && echo "最終レポートを作った: report.html"

if git remote get-url origin >/dev/null 2>&1; then
  if ! run gh repo delete "$REPO" --yes; then
    echo "gh repo delete に失敗（ネットワークか delete_repo の権限？）。次の回にやり直す"
    notify "GitHub のリポジトリを消せませんでした。data/cleanup.log を見てください。"
    exit 1
  fi
  run git remote remove origin
  echo "リポジトリを消した: $REPO"
fi

notify "11月の記録を締めて、GitHub のリポジトリを消しました。report.html に最終の集計があります。"
echo "予約を外して終わる"
remove_agent cleanup   # 自分自身を外すので最後に行う
