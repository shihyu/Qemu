insmod globalmem.ko
mknod /dev/globalmem c 245 0
#section.sh globalmem > gdb
#put.sh gdb
