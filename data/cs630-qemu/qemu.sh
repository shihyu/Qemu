#!/bin/bash

[ -z "$1" ] && exit -1

image="$1".img
qemu-system-i386 -m 129M -fda $image -boot a
