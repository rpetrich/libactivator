#!/bin/sh
for FILE in $1/*.lproj
do
	BASENAME=$(basename "$FILE")
	ln -s "$2/$BASENAME" "$3/$BASENAME"
done
