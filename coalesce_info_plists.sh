#!/bin/sh
for dir in "$1"/*; do
    if test -d "$dir"; then
    	name=${dir##*/}
    	printf '%s = ' "$name"
		cat "$dir/Info.plist"
		rm "$dir/Info.plist"
		rmdir "$dir" 2> /dev/null
		printf ';\n'
    fi
done