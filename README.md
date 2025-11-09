# Pluto FRM Info

Have you ever saved a `pluto.frm` firmware file and then lost track of which build it was? Or perhaps a whole directory full of different .frm files with cryptic names? This little shell script will analyze the .frm file(s) and give you a little report about each one.

```
% ./pluto-frm-info.sh *.frm
Version information for pluto-1e2d-main-syncdet.frm:
device-fw 1e2d
buildroot 2022.02.3-adi-5712-gf70f4a
linux v5.15-20952-ge14e351
u-boot-xlnx v0.20-PlutoSDR-25-g90401c

Version information for pluto-peakrdl-clean.frm:
device-fw abfa
buildroot 2022.02.3-adi-5712-gf70f4a
linux v5.15-20952-ge14e351
u-boot-xlnx v0.20-PlutoSDR-25-g90401c

Version information for pluto-peakrdl-debug.frm:
device-fw d124
buildroot 2022.02.3-adi-5712-gf70f4a
linux v5.15-20952-ge14e351
u-boot-xlnx v0.20-PlutoSDR-25-g90401c
```

The first line gives the `device-fw` *description*. This is created in the Makefile by `git describe --abbrev=4 --always --tags`, based on the git commit hash of the code the .frm file was built with. It may be just the first four characters of the hash, as shown here. It can also include tag information, if tags are in use in your repository, in which case it also inserts the number of commits between the latest tag and the current commit.

Note that if you commit, build a version, make some changes, and build another version without committing beforehand, you will end up with two builds that have the same description. There is no mechanism in the current build procedure to catch that situation, so there's no way to extract that information from the .frm file.

## Theory of Operation

The .frm file for loading new firmware into an ADALM PLUTO, as built with the Analog Devices [plutosdr-fw](https://github.com/analogdevicesinc/plutosdr-fw) Makefile, is in the format of a device tree blob. That is, a compiled binary representation of a Linux device tree. Without specialized tools, this is an opaque binary file (a blob) that is difficult to understand.

So, the first step in understanding the file is to decompile it. Fortunately, the device tree compiler tool, `dtc`, is also able to decompile binary device trees into an ASCII source format.

The decompiled source is in a structured format, and also in a very consistent physical layout. It mostly consists of large image blocks, represented as long strings of two-digit hexadecimal byte values, enclosed in square brackets, each on one very long line of text. There is an image block of this type for each binary resource needed to program a Pluto device. Among other things, this includes an image of the Linux filesystem as it will appear in a RAM disk. The build procedure places certain information about other components of the build into defined locations within the filesystem, in order to make that information available to the Pluto user. We take advantage of the rigid format of the decompiled ASCII format to extract the hexadecimal byte values encoding the filesystem image. This is done in two steps. First, `sed` is used to find the header of this image object, identified by its name `ramdisk@1`, and extract the second line after the line containing that string. Second, the hex data is found between the square brackets using `awk`. This all depends on the exact format of the decompilation, as created by `dtc` in its decompilation mode.

We convert the hexadecimal values into binary using `xxd`. This binary is gzip compressed, so we use `gunzip` to uncompress it. The result is a CPIO archive file containing the Linux filesystem. We use `cpio` to extract from the archive the contents of the file that would be `/opt/VERSIONS` when installed. This file contains the information we are after; we print it to stdout.

That whole procedure is wrapped in a little loop, so it runs once for each file named (or expanded from a wildcard pattern) on the script's command line.

## Prerequisites

This is a bash script, which I've developed on macOS Sequoia and Raspberry Pi OS (Debian) bookworm. It ought to work on any Unix-like system.

You will probably need to install some or all of these utilities before the script will work. These should all be available in your favorite package manager, if not already installed on your system.
- dtc
- sed
- awk
- xxd
- gunzip (part of gzip)
- cpio

**A special note about `cpio` for macOS users**: the script uses the `--to-stdout` command line flag to avoid writing any files to your host's filesystem. The version of `cpio` that Apple ships with macOS does not support this feature, but the version available in [Homebrew](https://brew.sh) does. When you install `cpio` using brew, you're warned that brew's cpio does not override the Apple-provided cpio by default (it's installed "keg-only"). It provides a modification you can install in your shell's startup script to add brew's cpio to the path, so you always get brew's cpio. If you do that, you can use the standard version of this script, named `pluto-frm-info.sh`. If you choose not to do that (which is what I recommend), and your brew installation is in `/opt/homebrew` as usual, you can use the modified version found in `pluto-frm-info-macOS.sh`. If your brew installation is elsewhere, modify the path to cpio in the macOS version.

## Speed

This script does a substantial amount of work on largish data objects, so it can be slow. It takes about 3 seconds per file to run on my 2024 M4 Pro Mac Mini, but it takes about 75 seconds per file on my Raspberry Pi 4B.

## Credits

Thanks to all those unknown developers who shared their sed and awk scripts and tutorials on the web, where they could be scraped for LLM training. I don't know enough `sed` or `awk` to have written the respective command lines without a lot of research and struggle. I used suggestions provided by everybody's favorite search engine when I asked how to do those tasks, and in this case the LLM-generated answers were more immediately useful than the first few hits of presumably human-generated content.

## Missing Features

- Output build time, building user, and building hostname. This information is in the .frm file somewhere, so this feature might be added with some additional research.

- Describe changes since the commit that appears in the build description. As noted above, I think this information is not contained in the .frm file, so it cannot be added.

