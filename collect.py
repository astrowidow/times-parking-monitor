#!/usr/bin/env python3
"""タイムズ駐車場の満空情報を1回取得して data/log.csv に1行追記する。

launchd などから定期的に呼び出す想定。標準ライブラリだけで動く（Python 3.9 以上）。

ページには満空表示が XOR で難読化された形で埋め込まれている:
  <input type="hidden" id="json" value='{"#mankuuText":{"textContent":"<hex>"}, "#mankuuStyle":{"class":"<hex>"}}'>
16進文字列の前半と後半を1バイトずつ XOR すると UTF-8 の文字列（「満車」「full」など）になる。
"""
import csv
import datetime as dt
import html
import json
import os
import re
import sys
import urllib.request

URL = "https://times-info.net/P13-tokyo/C103/park-detail-BUK0047890/"
HERE = os.path.dirname(os.path.abspath(__file__))
LOG = os.path.join(HERE, "data", "log.csv")
FIELDS = ["fetched_at", "site_time", "status", "label", "error"]
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/130.0 Safari/537.36")
JST = dt.timezone(dt.timedelta(hours=9))


def inner_decode(e):
    """サイトの Decoder.innerDecode と同じ処理。"""
    t = len(e) // 2
    return bytes(int(e[i:i + 2], 16) ^ int(e[t + i:t + i + 2], 16)
                 for i in range(0, t, 2)).decode("utf-8")


def parse(page):
    m = re.search(r'<input[^>]*value="([^"]*)"[^>]*id="json"', page)
    if not m:
        raise ValueError("満空情報（id=json）が見つからない")
    enc = json.loads(html.unescape(m.group(1)))
    label = inner_decode(enc["#mankuuText"]["textContent"])  # 空車 / 混雑 / 満車
    status = inner_decode(enc["#mankuuStyle"]["class"])      # vaca / crow / full / none
    t = re.search(r"(\d{4}/\d{2}/\d{2} \d{2}:\d{2})現在", page)
    site_time = (dt.datetime.strptime(t.group(1), "%Y/%m/%d %H:%M")
                 .strftime("%Y-%m-%d %H:%M")) if t else ""
    return site_time, status, label


def main():
    now = dt.datetime.now(JST).strftime("%Y-%m-%d %H:%M:%S")
    row = {"fetched_at": now, "site_time": "", "status": "", "label": "", "error": ""}
    try:
        req = urllib.request.Request(URL, headers={"User-Agent": UA, "Accept-Language": "ja"})
        with urllib.request.urlopen(req, timeout=30) as r:
            page = r.read().decode("utf-8", "replace")
        row["site_time"], row["status"], row["label"] = parse(page)
    except Exception as ex:  # 失敗も記録して、穴の時間帯が分かるようにする
        row["error"] = "{}: {}".format(type(ex).__name__, ex)[:300]

    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    new = not os.path.exists(LOG)
    with open(LOG, "a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        if new:
            w.writeheader()
        w.writerow(row)
    print(",".join(row[k] for k in FIELDS))
    return 1 if row["error"] else 0


if __name__ == "__main__":
    sys.exit(main())
