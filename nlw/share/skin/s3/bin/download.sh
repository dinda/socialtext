#!/bin/sh

files="
    dashboard.html
    contentPage.html
    listPage.html
    settings.html
    settings2.html
    revisionHistory.html
    weblog.html
    listPage2.html
    listPage3.html
    listPage4.html
"

for i in $files; do
    wget http://clients.araucariadesign.com/Socialtext/wiki/$i --user social --password guest -O html/$i
    sed -i 's/\t/    /g' html/$i
done
