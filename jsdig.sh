#!/bin/bash
#
# This script will find secrets in client side javascript files
# pulled from a given list of URLs
#
# note: input file must be a list of full URLs, one per line:
#    https://foo.com/bar
#    http://example.com/
# 

YELLOW='\033[1;33m'
NOCOLOR='\033[1;0m'

if [[ $# -eq 0 ]]; then
	printf "[-] Usage: ./jsdig.sh <text file containing URLs>\n"
	exit 0
fi

URLS="$(cat $1)"

setup() {
	# clear from previous run
	if [[ -f links.lst ]]; then
		rm links.lst
	fi
	REGEXFILE="strings.json" # regex to grep js for
	cat $REGEXFILE | jq '.[]' | sed 's/^"//' | sed 's/"$//' > /tmp/strings.lst

	# list of domains from the URLS to grep for...
	GREPSTRING="$(echo "$URLS" | awk -F / '{print $3}' | sort -u | tr '\n' '|' | sed 's/|/\\|/g' | sed 's/..$//')"
	GREPSTRING="${GREPSTRING}\|amazonaws\|core\.windows\.net" # only js files hosted on the server or cloud buckets

	USERAGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.122 Safari/537.36"
}

# run hakrawler
find_js() {
	printf "[+] Grabbing links from $(echo "$URLS" | wc -l | tr -d ' ') URLs...\n"
	DEPTH=1 # crawl depth. lower this for large redundant targets (ie. ecommerce sites)
	LINKS="$(echo "$URLS" | hakrawler -d $DEPTH -h "User-Agent: $USERAGENT" -insecure -subs | grep "$GREPSTRING" | tee links.lst)"
	sort -u -o links.lst links.lst
	JSLINKS="$(echo $LINKS | grep \.js)"

	# unique the array
	JSLINKS="$(echo "${JSLINKS[@]}" | tr ' ' '\n' | sort -u)"

	echo "[+] Found $(wc -l links.lst | awk '{print $1}') unique links, $(echo "$JSLINKS" | wc -l | awk '{print $1}') js files"
}

download_js() {
	THREADLIMIT=10 # change if necessary
	RAND=$RANDOM
	RUNFILE="/tmp/$RAND-jsdig.cmds.lst"
	JOBFILE="/tmp/$RAND-jsdig.jobs.lst"

	echo "[DEBUG] Runfile: $RUNFILE"

	# create a parallel command file for aria2
	for URL in $(echo "$JSLINKS"); do
		JSFILE=$(echo -n "$URL" | rev | awk -F/ '{print $1}' | rev)
		# create an output dir for aria2 using FQDN
		OUTDIR="$(echo -n "$URL" | awk -F/ '{print $3}' | cut -d: -f1 | tr -d '\n')"
		if [ ! -d "$OUTDIR" ]; then
			mkdir "$OUTDIR"
		fi
		URL="'$URL'"
		CMD="aria2c --console-log-level=error --check-certificate=false --http-no-cache=true -U '$USERAGENT' --file-allocation=none -m 1 --dht-message-timeout=3 --connect-timeout=3 -t 3 -c -d $OUTDIR --out=$JSFILE $URL"
		echo "$CMD" >> $RUNFILE
	done

# run aria2
	echo "[+] Downloading $(wc -l $RUNFILE | awk '{print $1}') js files..."
	cat "$RUNFILE" | parallel -j $THREADLIMIT --joblog $JOBFILE {} 1>/dev/null

	RUNFILE="/tmp/$RAND-jsbeautify.cmds.lst"
	JOBFILE="/tmp/$RAND-jsbeautify.jobs.lst"
	for DIR in $(ls -d */ | tr -d \/); do
		printf "[+] Downloaded $(ls $DIR | wc -w | tr -d ' ') js files from $YELLOW$DIR$NOCOLOR\n"

		# create a parallel command file for js-beautify
		for FILE in $(ls $DIR); do
			CMD="js-beautify -r $DIR/$FILE"
			echo "$CMD" >> $RUNFILE
		done
	done
}

# run js-beautify
beautify_js() {
	echo "[+] Beautifying $(wc -l $RUNFILE | awk '{print $1}') js files with $THREADLIMIT threads..."
	cat "$RUNFILE" | parallel -j $THREADLIMIT --joblog $JOBFILE {} 1>/dev/null
}

# grep the js for secrets
grep_js() {
	for DIR in $(ls -d */ | tr -d \/); do
		for FILE in $(ls $DIR); do
			grep --color=always -H -n -f /tmp/strings.lst $DIR/$FILE
		done
	done       
}

# cleanup
cleanup() {
	rm /tmp/strings.lst
	rm /tmp/$RAND-*
}

setup
find_js
download_js
beautify_js
grep_js
cleanup
