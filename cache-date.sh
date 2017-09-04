#!/bin/bash

LOCALCACHE=$(dirname $0)/cache

if [ $# -ne 1 ]
then
    echo "Expected one parameter." 1>&2
    exit 1
fi

DATE=$1

if ! date --date="$DATE" > /dev/null
then
    echo "Expected parameter to be a date" 1>&2
    exit 1
fi

do_branch()
{
    PRODUCT=$1
    BRANCH=$2

    SERVERPATH=https://archive.mozilla.org/pub/$PRODUCT/nightly

    YEAR=$(date +%Y --date="$DATE")
    MONTH=$(date +%m --date="$DATE")
    YMD=$(date +%F --date="$DATE")

    # Starting 2016-05-19 (on nightly), the mobile builds are in an
    # en-US subdirectory.
    MOBILESED=''
    if [ "$PRODUCT" == "mobile" ]
    then
        MOBILESED='p;s,$,/en-US,'
    fi

    MONTHLIST="$SERVERPATH/$YEAR/$MONTH"
    wget -q -O - "$MONTHLIST/"  | grep "<a href=" | sed 's/.*<a href="\([^"]*\)".*/\1/' | grep "$BRANCH/$" | sed 's,/$,,;s,.*/,,' | grep "^$YMD" | sed "$MOBILESED" | while read BUILDDIR
    do
        HOURLIST="$MONTHLIST/$BUILDDIR"
        wget -q -O - "$HOURLIST/" | grep "<a href=" | sed 's/.*<a href="\([^"]*\)".*/\1/;s,.*/,,' | grep "\.txt$" | while read TXTFILE
        do
            TXTPATH="$HOURLIST/$TXTFILE"
            DEST="$LOCALCACHE/$BUILDDIR/$TXTFILE"
            mkdir -p $(dirname "$DEST")
            wget -q -O - "$TXTPATH" >| "$DEST"
        done
    done
}

do_branch firefox mozilla-central
# Assume that all Android builds match android-api-15 ones
do_branch mobile mozilla-central-android-api-16
do_branch firefox mozilla-aurora
# Assume that all Android builds match android-api-15 ones
do_branch mobile mozilla-aurora-android-api-16
