#!/bin/bash

# Output version information embedded in one or more
# Pluto firmware files in .frm format.
#
# Specify filename(s) on the command line. Wildcards ok.

for filename in "$@"; do
	echo "Version information for $filename:"
	cat $filename |
		dtc -I dtb -O dts -q |            # decompile the device tree
		sed -n '/ramdisk@1/{n;n;p;q;}' |  # find the ramdisk image entity
		awk -F'[][]' '{print $2}' |       # extract hex data between [] brackets
		xxd -revert -plain |              # convert the hex to binary
		gunzip |                          # decompress the gzip archive
		/opt/homebrew/opt/cpio/bin/cpio --extract --to-stdout --quiet opt/VERSIONS
		                                  # extract the VERSIONS file from /opt
	echo                                  # blank line to separate multiple files
done
