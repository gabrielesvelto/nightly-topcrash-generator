#!/bin/bash

$(dirname $0)/cache-date.sh $(date --date="1 day ago" +%F)
$(dirname $0)/cache-date.sh $(date +%F)

LOCALCACHE=$(dirname $0)/cache
DESTHTML=~/public_html/dbaron.org/mozilla/crashes-by-build.html

"rm" $DESTHTML

cat >>$DESTHTML <<EOM
<!DOCTYPE HTML>
<html>
<head>
<title>Firefox mozilla-central nightly build crashes, by build</title>
</head>
<body>
<h1>Firefox mozilla-central nightly build crashes, by build</h1>

<table border>
EOM

# ls -r "$LOCALCACHE" | cut -b1-10 | uniq | while read DAY
for ((i=0; i < 31; i=$i+1))
do
    DAY=$(TZ=UTC date --date="$i days ago" +%F)
    if ! ls -d "$LOCALCACHE/$DAY"* > /dev/null 2>&1
    then
        continue
    fi
    cat >>$DESTHTML <<EOM
<tr>
<th>$(date --date="$DAY" +"%Y %b %d")</th>
<td>
EOM
    ls -d "$LOCALCACHE/$DAY"* | while read DIR
    do
        ls -r "$DIR" | grep "\.en-US\.\(linux-i686\|mac\|win32\)\.txt$" | while read TXTFILE
        do
            TXTPATH="$DIR/$TXTFILE"
            ORIGOS=$(echo "$TXTFILE" | sed 's/.*\.en-US\.//;s/\.txt$//')
            STATSOS=$(echo "$ORIGOS" | sed 's/win32/windows/;s/linux-i686/linux/')
            BUILDID=$(cat "$TXTPATH" | awk '{ print $1 }')
            CSET=$(cat "$TXTPATH" | awk '{ print $2 }')
            cat >>$DESTHTML <<EOM
<a href="http://crash-stats.mozilla.com/query/query?product=Firefox&amp;platform=$STATSOS&amp;branch=1.9.3&amp;date=&amp;range_value=31&amp;range_unit=days&amp;query_search=signature&amp;query_type=exact&amp;query=&amp;build_id=$BUILDID&amp;process_type=all&amp;do_query=1">$ORIGOS</a>
EOM
        done
    done
    cat >>$DESTHTML <<EOM
</td>
</tr>
EOM
done

cat >>$DESTHTML <<EOM
</table>

</body>
</html>
EOM
