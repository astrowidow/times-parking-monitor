#!/bin/zsh
# 終了日（日本時間 0:00）の2時間後まで Mac をスリープさせない。ディスプレイは消えてよい（caffeinate -i）。
# 2時間の余裕は、1時間おきの cleanup.sh が眠る前に動けるようにするため（cleanup.sh がこれも止める）。
# launchd から起動する。期限を過ぎていれば何もせずに終わる。
END_DATE="${END_DATE:-20261201}"
end=$(( $(TZ=Asia/Tokyo date -j -f "%Y%m%d%H%M%S" "${END_DATE}000000" +%s) + 7200 ))
left=$(( end - $(date +%s) ))
[ "$left" -le 0 ] && exit 0
exec /usr/bin/caffeinate -i -t "$left"
