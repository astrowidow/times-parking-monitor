# タイムズ麻布十番 空き統計

[タイムズ港区立麻布十番公共駐車場](https://times-info.net/P13-tokyo/C103/park-detail-BUK0047890/) の満空表示（空車・混雑・満車）を
GitHub Actions で5分おきに記録して、曜日 × 時間帯ごとの空きやすさを集計する。標準ライブラリだけで動く。

| ファイル | 役目 |
|---|---|
| `.github/workflows/collect.yml` | 5分おきに `collect.py` を動かし、`data/log.csv` をコミットする |
| `collect.py` | 1回取得して `data/log.csv` に1行足す |
| `report.py` | 集計。端末に表を出し、`report.html`（ヒートマップ）を作る |
| `report_template.html` | ヒートマップのひな形 |
| `cleanup.sh` / `schedule_cleanup.sh` | 12月に入ったら記録を手元に取り込み、GitHub のリポジトリを消す（下記） |

## 11月末で終わる

- **Actions**：2026-12-01（日本時間）以降に最初に動いたとき、記録せずにワークフローを無効にする（`collect.yml` の `END_DATE`）。
- **Mac**：`./schedule_cleanup.sh` で予約しておくと、12/1 以降に Mac が起きている最初の機会に
  `git pull` で記録を取り込み → `report.html` を作り → `gh repo delete` で GitHub のリポジトリを消し → 予約を外す。
  取り込みに失敗したら消さずに、1時間後にやり直す。経過は `data/cleanup.log`、終わると通知が出る。
- 消した GitHub のリポジトリは、GitHub の Settings → Repositories → Deleted repositories から90日以内なら戻せる。
- 必要な権限: `gh auth refresh -h github.com -s workflow,delete_repo`
- 予約の取り消し: `./schedule_cleanup.sh cancel`
- 試し運転（消さない）: `END_DATE=20200101 DRY_RUN=1 ./cleanup.sh`

## 集計を見る

```bash
git pull
python3 report.py            # 1時間ごと
python3 report.py --bin 30   # 30分ごと
open report.html
```

## 監視を止める・再開する

```bash
gh workflow disable collect
gh workflow enable collect
gh workflow run collect      # 今すぐ1回動かす
```

## メモ

- サイトの満空は5分ごとに更新され、表示は約10分遅れ。集計にはページの「◯◯現在」の時刻を使い、同じ時刻の重複は1回に数える。
- 「とめられる率」= 空車＋混雑。混雑は残りわずかでも入れる状態。
- GitHub の定期実行は数分〜十数分遅れたり、まれに飛ばされたりする。抜けた時間は集計に入らないだけで、率は残りの記録から出る。
- 取得に失敗した回も `error` 列つきで記録する。失敗が続くときはサイトの作りが変わった可能性がある。
- 祝日は `report.py` の `HOLIDAYS` に2026・2027年分を手で入れてある。
- 手元で1回だけ取るなら `python3 collect.py`（Actions と同時に動かすと `git pull` で衝突しうるので、普段は Actions に任せる）。
