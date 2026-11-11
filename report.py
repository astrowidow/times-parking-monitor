#!/usr/bin/env python3
"""data/log.csv を集計して、どの時間帯に空きが出やすいかを出す。

  python3 report.py              # 1時間ごと。端末に表を出し、report.html を作る
  python3 report.py --bin 30     # 30分ごと
  python3 report.py --log 別のcsv --out 別のhtml

時刻はページの「YYYY/MM/DD HH:MM現在」（サイトが満空を判定した時刻）を使い、
同じ時刻の重複は1回に数える。「とめられる」= 空車 + 混雑（混雑は残りわずかでも入れる状態）。
"""
import argparse
import collections
import csv
import datetime as dt
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DOW = "月火水木金土日"
ROWS = list(DOW) + ["祝"]
WEEKEND_ROWS = {"土", "日", "祝"}

# 祝日（振替休日・国民の休日を含む）。2028年以降は足すこと。
HOLIDAYS = {
    "2026-01-01", "2026-01-12", "2026-02-11", "2026-02-23", "2026-03-20",
    "2026-04-29", "2026-05-03", "2026-05-04", "2026-05-05", "2026-05-06",
    "2026-07-20", "2026-08-11", "2026-09-21", "2026-09-22", "2026-09-23",
    "2026-10-12", "2026-11-03", "2026-11-23",
    "2027-01-01", "2027-01-11", "2027-02-11", "2027-02-23", "2027-03-21",
    "2027-03-22", "2027-04-29", "2027-05-03", "2027-05-04", "2027-05-05",
    "2027-07-19", "2027-08-11", "2027-09-20", "2027-09-23", "2027-10-11",
    "2027-11-03", "2027-11-23",
}


def row_of(t):
    return "祝" if t.strftime("%Y-%m-%d") in HOLIDAYS else DOW[t.weekday()]


def load(path):
    seen, obs = set(), []
    fetched = errors = unknown = 0
    last_fetch = ""
    with open(path, encoding="utf-8") as f:
        for r in csv.DictReader(f):
            fetched += 1
            last_fetch = r["fetched_at"]
            if r["error"]:
                errors += 1
                continue
            key = r["site_time"] or r["fetched_at"][:16]
            if key in seen:
                continue
            seen.add(key)
            if r["status"] not in ("vaca", "crow", "full"):
                unknown += 1
                continue
            obs.append((dt.datetime.strptime(key, "%Y-%m-%d %H:%M"), r["status"]))
    obs.sort()
    return obs, dict(fetched=fetched, errors=errors, unknown=unknown, last_fetch=last_fetch)


def new_cell():
    return {"vaca": 0, "crow": 0, "full": 0, "days": set()}


def aggregate(obs, binmin):
    cells = collections.defaultdict(new_cell)    # (行, 区間) -> 件数
    groups = collections.defaultdict(new_cell)   # (平日/土日祝, 区間) -> 件数
    for t, s in obs:
        b = (t.hour * 60 + t.minute) // binmin
        r = row_of(t)
        g = "土日祝" if r in WEEKEND_ROWS else "平日"
        for c in (cells[(r, b)], groups[(g, b)]):
            c[s] += 1
            c["days"].add(t.date())
    return cells, groups


def pack(c):
    return {"vaca": c["vaca"], "crow": c["crow"], "full": c["full"], "days": len(c["days"])}


def bin_label(b, binmin):
    m = b * binmin
    return "{:02d}:{:02d}".format(m // 60, m % 60)


def print_table(groups, nbins, binmin):
    for g in ("平日", "土日祝"):
        print("\n■ {}（とめられる率 = 空車＋混雑）".format(g))
        for b in range(nbins):
            c = groups.get((g, b))
            n = c["vaca"] + c["crow"] + c["full"] if c else 0
            if not n:
                print("  {}  {:<10}   -".format(bin_label(b, binmin), ""))
                continue
            p = (c["vaca"] + c["crow"]) / n
            bar = "█" * round(p * 10) + "·" * (10 - round(p * 10))
            print("  {}  {} {:3.0f}%  空{:3.0f} 混{:3.0f} 満{:3.0f}  ({}回/{}日)".format(
                bin_label(b, binmin), bar, p * 100, c["vaca"] / n * 100,
                c["crow"] / n * 100, c["full"] / n * 100, n, len(c["days"])))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", default=os.path.join(HERE, "data", "log.csv"))
    ap.add_argument("--out", default=os.path.join(HERE, "report.html"))
    ap.add_argument("--bin", type=int, default=60, choices=[15, 30, 60], help="区間の分")
    a = ap.parse_args()

    obs, meta = load(a.log)
    if not obs:
        print("まだ集計できる記録がありません（{}）".format(a.log))
        return
    nbins = 24 * 60 // a.bin
    cells, groups = aggregate(obs, a.bin)
    tot = collections.Counter(s for _, s in obs)
    data = {
        "binmin": a.bin, "nbins": nbins, "rows": ROWS,
        "bins": [bin_label(b, a.bin) for b in range(nbins)],
        "cells": {"{}|{}".format(r, b): pack(c) for (r, b), c in cells.items()},
        "groups": {"{}|{}".format(g, b): pack(c) for (g, b), c in groups.items()},
        "total": {"vaca": tot["vaca"], "crow": tot["crow"], "full": tot["full"]},
        "first": obs[0][0].strftime("%Y-%m-%d %H:%M"), "last": obs[-1][0].strftime("%Y-%m-%d %H:%M"),
        "days": len({t.date() for t, _ in obs}), "obs": len(obs), **meta,
        "generated": dt.datetime.now().strftime("%Y-%m-%d %H:%M"),
    }
    with open(os.path.join(HERE, "report_template.html"), encoding="utf-8") as f:
        page = f.read().replace("/*__DATA__*/null", json.dumps(data, ensure_ascii=False))
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(page)

    n = len(obs)
    print("期間 {} 〜 {}（{}日・{}回分。取得失敗 {}回）".format(
        data["first"], data["last"], data["days"], n, meta["errors"]))
    print("全体: 空車 {:.0f}% / 混雑 {:.0f}% / 満車 {:.0f}%".format(
        tot["vaca"] / n * 100, tot["crow"] / n * 100, tot["full"] / n * 100))
    print_table(groups, nbins, a.bin)
    print("\nヒートマップ: {}".format(a.out))


if __name__ == "__main__":
    main()
