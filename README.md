# タイムズ麻布十番 空き統計

[タイムズ港区立麻布十番公共駐車場](https://times-info.net/P13-tokyo/C103/park-detail-BUK0047890/) の満空表示（空車・混雑・満車）を
Mac で5分おきに記録して、曜日 × 時間帯ごとの空きやすさを集計する。標準ライブラリだけで動く。
2026年11月末まで記録して、12月に入ったら自動で締める。

| ファイル | 役目 |
|---|---|
| `collect.py` | 1回取得して `data/log.csv` に1行足す |
| `install.sh` | launchd に「5分おきの取得」「スリープ防止」「終了日の片付け」を登録する |
| `keep_awake.sh` | 終了日まで `caffeinate -i` で本体のスリープを止める（ディスプレイは設定どおり消える） |
| `cleanup.sh` | 終了日以降に1回だけ、取得とスリープ防止を止め、最終レポートを作り、GitHub のリポジトリを消す |
| `report.py` / `report_template.html` | 集計。端末に表を出し、`report.html`（ヒートマップ）を作る |

## 使い方

```bash
./install.sh                 # 始める（フォルダを移したら再実行）
open report.html             # まとめを見る（5分おきに自動で作り直される）
python3 report.py            # 端末で見る（1時間ごと）
python3 report.py --bin 30   # 30分ごと
./install.sh stop            # すべて止める（記録は残る）
```

## メモ

- サイトの満空は5分ごとに更新され、表示は約10分遅れ。集計にはページの「◯◯現在」の時刻を使い、同じ時刻の重複は1回に数える。
- 「とめられる率」= 空車＋混雑。混雑は残りわずかでも入れる状態。
- 記録（`data/`）は git に入れず、手元にだけ置く。
- 取得に失敗した回も `error` 列つきで記録する。失敗が続くときはサイトの作りが変わった可能性がある。
- GitHub Actions からの取得は、サイト側（Akamai）に 403 で断られるので使わない。
- 終了日は `keep_awake.sh` と `cleanup.sh` の `END_DATE`。延ばすときは両方を直して `./install.sh` を再実行する。
- 片付けの経過は `data/cleanup.log`、終わると Mac に通知が出る。消した GitHub のリポジトリは
  Settings → Repositories → Deleted repositories から90日以内なら戻せる。
- 片付けの試し運転（消さない）: `END_DATE=20200101 DRY_RUN=1 ./cleanup.sh`
- 祝日は `report.py` の `HOLIDAYS` に2026・2027年分を手で入れてある。
