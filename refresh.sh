#!/bin/bash

$(dirname $0)/cache-date.sh $(date --date="1 day ago" +%F)
$(dirname $0)/cache-date.sh $(date +%F)

LOCALCACHE="$(dirname $0)/cache"
DESTPATH="${1:-/var/www/html/mozilla}"
DESTHTML="${DESTPATH}/crashes-by-build.html"
DESTCSS="${DESTPATH}/crashes-by-build-style.css"
TMPHTML=~/crashes-by-build-gen

cat >$TMPHTML <<EOM
<!DOCTYPE HTML>
<html>
<head>
<title>Firefox nightly build crashes, by build</title>
<link rel="stylesheet" href="crashes-by-build-style.css">
<script>
var gRegression1, gRegression2;
function regression_choose()
{
  document.body.classList.add("choose");
  document.body.classList.add("choose1");
  document.getElementById("regression-container").className = "choose1";
  document.body.addEventListener("click", choose_clickhandler, true);
}

function branch_table_for_link(link)
{
  var table = link;
  while (table.tagName != "TABLE") {
    table = table.parentNode;
  }
  return table;
}

function choose_clickhandler(event)
{
  let target = event.target;
  if (target.tagName != "A" || target.parentNode.tagName != "TD") {
    return;
  }
  if (event.button != 0) {
    return;
  }

  if (document.body.classList.contains("choose1")) {
    gRegression1 = target;
    document.body.classList.remove("choose1");
    document.body.classList.add("choose2");
    document.getElementById("regression-container").className = "choose2";

    let targetPlatform = target.textContent;
    // Array.from needed for Chromium and Edge but not Gecko
    for (let link of Array.from(branch_table_for_link(target).querySelectorAll("a"))) {
      if (link.textContent == targetPlatform &&
          // don't allow choosing the same build (in either column)
          link.title != target.title) {
        link.classList.add("choose-eligible");
      }
    }
  } else {
    if (!target.classList.contains("choose-eligible")) {
      return;
    }

    gRegression2 = target;
    document.body.classList.remove("choose2");
    document.body.classList.remove("choose");
    document.getElementById("regression-container").className = "found";

    // Array.from needed for Chromium and Edge but not Gecko
    for (let link of Array.from(document.querySelectorAll("a.choose-eligible"))) {
      link.classList.remove("choose-eligible");
    }
  }

  event.preventDefault();
  event.stopPropagation();

  if (gRegression2) {
    document.body.removeEventListener("click", choose_clickhandler, true);

    var table = branch_table_for_link(gRegression1);
    if (branch_table_for_link(gRegression2) != table) {
      console.log("mismatched tables");
      regression_clear();
      return;
    }
    let branch = table.parentNode.id;
    if (branch.substring(0,7) != "branch-") {
      console.log("bad branch id");
      regression_clear();
      return;
    }
    branch = branch.substring(7);
    let url = "https://hg.mozilla.org/";
    if (branch == "mozilla-central") {
      url += "mozilla-central";
    } else if (branch == "mozilla-aurora") {
      url += "releases/mozilla-aurora";
    } else {
      console.log("unknown branch");
      regression_clear();
      return;
    }
    let rev1, rev2, build1, build2;
    try {
      let rev_re = new RegExp("^[0-9]{2}:[0-9]{2}:[0-9]{2}, rev ([0-9a-f]{40})$");
      rev1 = rev_re.exec(gRegression1.title)[1];
      rev2 = rev_re.exec(gRegression2.title)[1];
      let buildid_re = new RegExp("&build_id=([0-9]{14})&");
      build1 = buildid_re.exec(gRegression1.href)[1];
      build2 = buildid_re.exec(gRegression2.href)[1];
    } catch (ex) {
      console.log("bad link data", ex);
      regression_clear();
      return;
    }
    let fromchange, tochange;
    if (build1 > build2) {
      fromchange = rev2;
      tochange = rev1;
    } else {
      fromchange = rev1;
      tochange = rev2;
    }
    url += \`/pushloghtml?fromchange=\${fromchange}&tochange=\${tochange}\`;

    let a = document.getElementById("regression-link");
    a.textContent = url;
    a.href = url;
  }
}

function regression_cancel()
{
  document.body.removeEventListener("click", choose_clickhandler, true);
  document.body.classList.remove("choose1");
  document.body.classList.remove("choose2");
  document.body.classList.remove("choose");
  // Array.from needed for Chromium and Edge but not Gecko
  for (let link of Array.from(document.querySelectorAll("a.choose-eligible"))) {
    link.classList.remove("choose-eligible");
  }
  document.getElementById("regression-container").className = "notstarted";
  gRegression1 = null;
  gRegression2 = null;
}

function regression_clear()
{
  document.getElementById("regression-container").className = "notstarted";
  gRegression1 = null;
  gRegression2 = null;
}
</script>
</head>
<body>
<h1>Firefox nightly build crashes, by build</h1>
<div id="regression-container" class="notstarted">
  <input type="button" id="regression-start" value="Choose regression window" onclick="regression_choose()">
  <input type="button" id="regression-cancel" value="Cancel regression window" onclick="regression_cancel()">
  <input type="button" id="regression-clear" value="Clear regression window" onclick="regression_clear()">
  <div id="regression-data"><a id="regression-link"></a></div>
</div>
EOM

build_table() {
    BRANCH=$1

    if [ "$BRANCH" = "mozilla-central" ]
    then
        CHANNEL=nightly
    elif [ "$BRANCH" = "mozilla-aurora" ]
    then
        CHANNEL=aurora
    else
        echo "Unexpected branch" 1>&2
        return
    fi

    cat >>$TMPHTML <<EOM
<div class="branch" id="branch-$BRANCH">
<h2>$BRANCH</h2>
<table border>
<tr><th>Year</th><th>Mon</th><th>Dy</th><th>Hr</th><th>All Crash Reports</th><th>Browser Crashes Only</th></tr>
EOM

    # ls -r "$LOCALCACHE" | cut -b1-10 | uniq | while read DAY
    for ((i=0; i < 180; i=$i+1))
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
            QUERYDATE=$(TZ=UTC date +"%m/%d/%Y %H:%M:%S" --date="24 hours")
            PREVALLENTRY=""
            PREVBROWSERENTRY=""
            for DIR in $(ls -d "$LOCALCACHE/$DAY-$HOUR-"??-??"-$BRANCH"* 2>>/dev/null)
            do
                for TXTPATH in $(find "$DIR" -name "*.txt" | sort -r | grep "\(\.en-US\.\(android-arm\|linux-i686\|linux-x86_64\|mac\|mac64\|win32\|win64-x86_64\)\|multi\.android-arm\)\.txt$")
                do
                    TXTFILE=$(basename "$TXTPATH")
                    ORIGOS=$(echo "$TXTFILE" | sed 's/.*\.en-US\.//;s/.*\.multi\.//;s/\.txt$//')
                    STATSOS=$(echo "$ORIGOS" | sed 's/win32/Windows/;s/win64-x86_64/Windows/;s/linux-i686/Linux/;s/linux-x86_64/Linux/;s/mac64/Mac OS X/;s/mac/Mac OS X/;s/android-arm/Android/')
                    DISPLAYOS=$(echo "$ORIGOS" | sed 's/win64-x86_64/win/;s/win32/win/;s/linux-i686/linux/;s/linux-x86_64/linux/;s/mac64/mac/;s/android-arm/android/')
                    PRODUCT=Firefox
                    if [ "$DISPLAYOS" = "android" ]
                    then
                        PRODUCT=FennecAndroid
                    fi
                    # The .txt files have different formats on 2011-01-26 and
                    # earlier (one line, space-separated values, changeset value
                    # is only hash) and on 2011-01-27 and later (two lines, and
                    # changeset value is URL).  See
                    # https://bugzilla.mozilla.org/show_bug.cgi?id=549958 .
                    BUILDID=$(head -1 "$TXTPATH" | awk '{ print $1 }')
                    DATE="${BUILDID:0:4}-${BUILDID:4:2}-${BUILDID:6:2}"
                    TIME="${BUILDID:8:2}:${BUILDID:10:2}:${BUILDID:12:2}"
                    CSET=$(cat "$TXTPATH" | awk '{ print $2 }')
                    if [ -z "$CSET" ]
                    then
                        CSET=$(head -2 "$TXTPATH" | tail -1 | sed 's,.*/,,' | tr -d '\r\n')
                    fi
                    ALLENTRY="<a title=\"$TIME, rev $CSET\" href=\"https://crash-stats.mozilla.com/search/?product=$PRODUCT&amp;build_id=$BUILDID&amp;platform=$STATSOS&amp;date=>%3D$DATE&amp;release_channel=$CHANNEL&amp;_facets=signature\">$DISPLAYOS</a>"
                    BROWSERENTRY="<a title=\"$TIME, rev $CSET\" href=\"https://crash-stats.mozilla.com/search/?product=$PRODUCT&amp;build_id=$BUILDID&amp;platform=$STATSOS&amp;date=>%3D$DATE&amp;release_channel=$CHANNEL&amp;process_type=browser&amp;process_type=content&amp;hang_type=crash&amp;_facets=signature\">$DISPLAYOS</a>"
                    # Coalesce 32/64 bit builds with the same build ID.
                    if [ "$ALLENTRY" != "$PREVALLENTRY" -o "$BROWSERENTRY" != "$PREVBROWSERENTRY" ]
                    then
                        PREVALLENTRY="$ALLENTRY"
                        PREVBROWSERENTRY="$BROWSERENTRY"
                        ALL_REPORTS="$ALL_REPORTS $ALLENTRY"
                        BROWSER_CRASHES="$BROWSER_CRASHES $BROWSERENTRY"
                    fi
                done
            done
            if [ -n "$ALL_REPORTS" ]
            then
                cat >>$TMPHTML <<EOM
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

    cat >>$TMPHTML <<EOM
</table>
</div>
EOM

}

build_table mozilla-central
#build_table mozilla-aurora

cat >>$TMPHTML <<EOM
<div class="footer">
<p>
Source code:
<a href="https://github.com/gabrielesvelto/nightly-topcrash-generator.git">on GitHub</a>
</p>
</div>
</body>
</html>
EOM

# Use cat rather than mv (even though it's less atomic) because it means
# we only need permissions for the file, not the directory.
cat "${TMPHTML}" > "${DESTHTML}"
rm "${TMPHTML}"
cat "$(dirname $0)/crashes-by-build-style.css" > "${DESTCSS}"
