#!/usr/bin/env bash

for fn in $(ls | grep [A-Z])
do
	mv -i $fn `echo $fn | tr 'A-Z' 'a-z'`
done
