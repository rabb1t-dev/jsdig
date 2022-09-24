## jsdig.sh
### description
This script is quick way to find secrets in client side javascript when pentesting a web application. It will:
1) grab all .js links from a given list of web URLs
2) download the files locally
3) beautify/unminify them
4) grep them for a given set of regex strings

### dependencies
jsdig has four dependencies:
- hakrawler ([github.com/hakluke/hakrawler](https://github.com/hakluke/hakrawler))
- aria2 ([github.com/aria2/aria2](https://github.com/aria2/aria2))
- js-beautify ([github.com/beautify-web/js-beautify](https://github.com/beautify-web/js-beautify))
- jq ([stedolan.github.io/jq/download/](https://stedolan.github.io/jq/download/))
