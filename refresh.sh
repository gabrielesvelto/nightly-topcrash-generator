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
<tr><th>Year</th><th>Mon</th><th>Dy</th><th>Hr</th><th>All Crash Reports</th><th>Browser Crashes Only</th></tr>
EOM

# ls -r "$LOCALCACHE" | cut -b1-10 | uniq | while read DAY
for ((i=0; i < 31; i=$i+1))
do
    DAY=$(TZ=UTC date --date="$i days ago" +%F)
    for ((h=23; h >= 0; h=$h-1))
    do
        ALL_REPORTS=""
        BROWSER_CRASHES=""
        if [ "$h" -lt "10" ]
        then
            HOUR="0$h"
        else
            HOUR="$h"
        fi
        for DIR in $(ls -d "$LOCALCACHE/$DAY-$HOUR-"* 2>>/dev/null)
        do
            for TXTFILE in $(ls -r "$DIR" | grep "\.en-US\.\(linux-i686\|linux-x86_64\|mac\|mac64\|win32\|win64-x86_64\)\.txt$")
            do
                TXTPATH="$DIR/$TXTFILE"
                ORIGOS=$(echo "$TXTFILE" | sed 's/.*\.en-US\.//;s/\.txt$//')
                STATSOS=$(echo "$ORIGOS" | sed 's/win32/windows/;s/win64-x86_64/windows/;s/linux-i686/linux/;s/linux-x86_64/linux/;s/mac64/mac/')
                # FIXME: If win64/win32 or linux64/linux32 have the same
                # build ID, I really need to unify them into a single linux
                # or win link since the queries don't distinguish.
                DISPLAYOS=$(echo "$ORIGOS" | sed 's/win64-x86_64/win64/;s/linux-i686/linux32/;s/linux-x86_64/linux64/;s/mac64/mac/')
                # The .txt files have different formats on 2011-01-26 and
                # earlier (one line, space-separated values, changeset value
                # is only hash) and on 2011-01-27 and later (two lines, and
                # changeset value is URL).  See
                # https://bugzilla.mozilla.org/show_bug.cgi?id=549958 .
                BUILDID=$(head -1 "$TXTPATH" | awk '{ print $1 }')
                FXVER=$(echo "$TXTFILE" | sed 's/^firefox-//;s/\.en-US\..*//')
                case "$FXVER" in 
                  3.5*) BRANCH=1.9.1 ;;
                  3.6*) BRANCH=1.9.2 ;;
                  3.7*) BRANCH=1.9.3 ;;
                  4.0*) BRANCH=2.0 ;;
                  4.2*) BRANCH=2.2 ;;
                  5.0*) BRANCH=2.2 ;;
                  6.0*) BRANCH=2.2 ;;
                  *)    BRANCH=unknown ;;
                esac
                TIME="${BUILDID:8:2}:${BUILDID:10:2}:${BUILDID:12:2}"
                CSET=$(cat "$TXTPATH" | awk '{ print $2 }')
                if [ -z "$CSET" ]
                then
                    CSET=$(head -2 "$TXTPATH" | tail -1 | sed 's,.*/,,')
                fi
                if [ "$BRANCH" = "unknown" ]
                then
                    ALL_REPORTS="$ALL_REPORTS $DISPLAYOS"
                    BROWSER_CRASHES="$BROWSER_CRASHES $DISPLAYOS"
                else
                    ALL_REPORTS="$ALL_REPORTS <a title=\"$TIME, rev $CSET\" href=\"http://crash-stats.mozilla.com/query/query?product=Firefox&amp;platform=$STATSOS&amp;branch=$BRANCH&amp;version=ALL%3AALL&amp;date=&amp;range_value=30&amp;range_unit=days&amp;query_search=signature&amp;query_type=exact&amp;query=&amp;build_id=$BUILDID&amp;process_type=any&amp;hang_type=any&amp;do_query=1\">$DISPLAYOS</a>"
                    BROWSER_CRASHES="$BROWSER_CRASHES <a title=\"$TIME, rev $CSET\" href=\"http://crash-stats.mozilla.com/query/query?product=Firefox&amp;platform=$STATSOS&amp;branch=$BRANCH&amp;version=ALL%3AALL&amp;date=&amp;range_value=30&amp;range_unit=days&amp;query_search=signature&amp;query_type=exact&amp;query=&amp;build_id=$BUILDID&amp;process_type=browser&amp;hang_type=crash&amp;do_query=1\">$DISPLAYOS</a>"
                fi
            done
        done
        if [ -n "$ALL_REPORTS" ]
        then
            cat >>$DESTHTML <<EOM
<tr>
$(date --date="$DAY" +"<th>%Y</th><th>%b</th><th>%d</th>")
<th>$HOUR</th>
<td>$ALL_REPORTS</td>
<td>$BROWSER_CRASHES</td>
</tr>
EOM
        fi
    done
done

cat >>$DESTHTML <<EOM
</table>

</body>
</html>
EOM
