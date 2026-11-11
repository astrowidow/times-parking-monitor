#!/bin/zsh
# 2026-12-01（日本時間）以降に1回だけ、次を順に行う。schedule_cleanup.sh が launchd から1時間おきに呼ぶ。
#   1. GitHub から記録を取り込む（git pull）。失敗したら消さずに終え、次の回にやり直す
#   2. 最終レポート（report.html）を作る
#   3. GitHub のリポジトリを消す（GitHub の設定画面から90日以内なら戻せる）
#   4. 自分の予約（launchd）を外す
# 手元のフォルダと記録はそのまま残る。
# 試し運転: END_DATE=20200101 DRY_RUN=1 ./cleanup.sh   （取り込みとレポートだけ行い、消す操作は表示だけ）
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
REPO=astrowidow/times-parking-monitor
END_DATE="${END_DATE:-20261201}"
LABEL=local.times-parking-monitor.cleanup
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

[ "$(TZ=Asia/Tokyo date +%Y%m%d)" -lt "$END_DATE" ] && exit 0

run() { if [ -n "${DRY_RUN:-}" ]; then echo "(試し運転) $*"; else "$@"; fi; }
notify() { [ -n "${DRY_RUN:-}" ] && { echo "(通知) $1"; return; }; osascript -e "display notification \"$1\" with title \"駐車場の監視\"" >/dev/null 2>&1 || true; }
unschedule() {
  run rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
  run launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
}

cd "$DIR"
[ -z "${DRY_RUN:-}" ] && exec >> "$DIR/data/cleanup.log" 2>&1
echo "== $(date '+%F %T') 片付けを始める"

if git remote get-url origin >/dev/null 2>&1; then
  if ! git pull -q --ff-only origin main; then
    echo "git pull に失敗。消さずに終える（次の回にやり直す）"
    notify "記録の取り込みに失敗しました。リポジトリはまだ消していません。"
    exit 1
  fi
  python3 report.py > /dev/null || true
  if ! run gh repo delete "$REPO" --yes; then
    echo "gh repo delete に失敗（delete_repo の権限が無い？）。次の回にやり直す"
    notify "GitHub のリポジトリを消せませんでした。data/cleanup.log を見てください。"
    exit 1
  fi
  run git remote remove origin
  echo "リポジトリを消した: $REPO"
  notify "記録を取り込み、GitHub のリポジトリを消しました。report.html に最終の集計があります。"
fi

echo "予約を外す"
unschedule
