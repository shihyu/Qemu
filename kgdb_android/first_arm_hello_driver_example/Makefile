obj-m := hello.o

KERN := /media/shihyu/toshiba/android_44_pure/goldfish/
PWD :=$(shell pwd)
ARCH=arm
CROSS_COMPILE=arm-eabi-
CC=$(CROSS_COMPILE)gcc
LD=$(CROSS_COMPILE)ld
all:
	$(MAKE) -C $(KERN) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) M=$(PWD) modules
	adb push *.ko /data/app/
clean:
	-rm -rf *.o *.ko *.mod.c .*.cmd *.order *.symvers .tmpversions

