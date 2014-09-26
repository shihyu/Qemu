#搭建 ARM Linux核心開發Debug 環境

### CROSS_COMPILE - linaro
```
arm-linux-gnueabi-linaro_4.9.1-2014.07
https://github.com/Christopher83/linaro_toolchains_2014

https://launchpad.net/linaro-toolchain-binaries/
https://launchpad.net/linaro-toolchain-binaries/trunk/2013.10/+download/gcc-linaro-arm-linux-gnueabihf-4.8-2013.10_linux.tar.bz2


arm-unknown-linux-gnueabi-linaro_4.8.3-2013.12 // 目前使用這成功
```
```
source build.env
```
- 成功可看到下面訊息
```
$arm-unknown-linux-gnueabi-gcc -v

Using built-in specs.
COLLECT_GCC=arm-unknown-linux-gnueabi-gcc
COLLECT_LTO_WRAPPER=/media/ssd/arm_work/arm-unknown-linux-gnueabi-linaro_4.8.3-2013.12/bin/../libexec/gcc/arm-unknown-linux-gnueabi/4.8.3/lto-wrapper
Target: arm-unknown-linux-gnueabi
Configured with: /media/hdd_linux/crosstool-ng/.build/src/gcc-linaro-4.8-2013.12/configure --build=x86_64-build_unknown-linux-gnu --host=x86_64-build_unknown-linux-gnu --target=arm-unknown-linux-gnueabi --prefix=/media/hdd_linux/crosstool-ng/builds/arm-unknown-linux-gnueabi --with-sysroot=/media/hdd_linux/crosstool-ng/builds/arm-unknown-linux-gnueabi/arm-unknown-linux-gnueabi/sysroot --enable-languages=c,c++,fortran --with-arch=armv7-a --with-tune=cortex-a9 --with-fpu=vfpv3-d16 --with-float=softfp --with-pkgversion='crosstool-NG hg+default-4cfbdb295328 - Linaro GCC 2013.12' --enable-__cxa_atexit --disable-libmudflap --disable-libgomp --disable-libssp --disable-libquadmath --disable-libquadmath-support --with-gmp=/media/hdd_linux/crosstool-ng/.build/arm-unknown-linux-gnueabi/buildtools --with-mpfr=/media/hdd_linux/crosstool-ng/.build/arm-unknown-linux-gnueabi/buildtools --with-mpc=/media/hdd_linux/crosstool-ng/.build/arm-unknown-linux-gnueabi/buildtools --with-isl=/media/hdd_linux/crosstool-ng/.build/arm-unknown-linux-gnueabi/buildtools --with-cloog=/media/hdd_linux/crosstool-ng/.build/arm-unknown-linux-gnueabi/buildtools --with-libelf=/media/hdd_linux/crosstool-ng/.build/arm-unknown-linux-gnueabi/buildtools --with-host-libstdcxx='-static-libgcc -Wl,-Bstatic,-lstdc++,-Bdynamic -lm' --enable-threads=posix --enable-multilib --with-local-prefix=/media/hdd_linux/crosstool-ng/builds/arm-unknown-linux-gnueabi/arm-unknown-linux-gnueabi/sysroot --enable-c99 --enable-long-long --with-mode=thumb --without-isl
Thread model: posix
gcc version 4.8.3 20131202 (prerelease) (crosstool-NG hg+default-4cfbdb295328 - Linaro GCC 2013.12)
```

### 產生根文件系統
```
make -j8 ARCH=arm CROSS_COMPILE=arm-eabi- defconfig
```
- 打開 Busybox 選項
```
CONFIG_STATIC=y
CONFIG_INSTALL_NO_USR=y


CONFIG_FEATURE_PREFER_APPLETS=y
CONFIG_FEATURE_SH_STANDALONE=y
```
```
make -j8 ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabi- 
make -j8 ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabi-  install // 產生  _install 資料夾

```
- 建立ARM version的root filesystem image

```
#include <stdio.h>

int main(int argc, char *argv[])
{
    printf("Hello world\n");
    return 0;
}
```
```
arm-eabi-readelf -a test | ag 'lib'
      [正在要求程式解譯器：/lib/ld-linux.so.3]
 0x00000001 (NEEDED)                     共享函式庫：[libc.so.6]
00010554  00000216 R_ARM_JUMP_SLOT   00000000   __libc_start_main
     2: 00000000     0 FUNC    GLOBAL DEFAULT  UND __libc_start_main@GLIBC_2.4 (2)
    94: 00008429     2 FUNC    GLOBAL DEFAULT   13 __libc_csu_fini
   104: 00000000     0 FUNC    GLOBAL DEFAULT  UND __libc_start_main@@GLIBC_
   108: 000083e9    64 FUNC    GLOBAL DEFAULT   13 __libc_csu_init
  000000: 版本: 1  檔案：libc.so.6  計數：1

test 這個二進位文件需要三個共享庫: “ld-linux.so.3″,“libc.so.6″
```
```
cd _install/
mkdir -p proc sys dev etc etc/init.d lib

cd arm-unknown-linux-gnueabi-linaro_4.8.3-2013.12
find . -name  'libc.so.6'
cp -a /media/ssd/arm_work/arm-unknown-linux-gnueabi-linaro_4.8.3-2013.12/arm-unknown-linux-gnueabi/sysroot/lib/* .


cp /media/ssd/arm_work/gcc-linaro-arm-linux-gnueabihf-4.8-2013.10_linux/arm-linux-gnueabihf/libc/lib/arm-linux-gnueabihf/* lib
```

- 掛載系統目錄
```
cat << EOF > etc/fstab 
proc  /proc  proc  defaults  0  0
sysfs  /sys  sysfs defaults  0  0
tmpfs  /tmp  tmpfs defaults  0  0
EOF
```
```
cat << EOF > etc/inittab 
::sysinit:/etc/init.d/rcS
::respawn:-/bin/sh
tty2::askfirst:-/bin/sh
::ctrlaltdel:/bin/umount -a -r
EOF 
```
-  etc/init.d/rcS
```
#! /bin/sh

MAC=08:90:90:59:62:21
IP=192.168.100.2
Mask=255.255.255.0
Gateway=192.168.100.1
 

/sbin/ifconfig lo 127.0.0.1
ifconfig eth0 down
ifconfig eth0 hw ether $MAC
ifconfig eth0 $IP netmask $Mask up
route add default gw $Gateway

/bin/mount -a
/bin/mount -t  sysfs sysfs /sys
/bin/mount -t tmpfs tmpfs /dev
/sbin/mdev -s

mount -o remount,rw,noatime -n /dev/root /
```
- chmod 755 etc/init.d/rcS

- 產生 rootfs, 可在temp 下新增修改檔案
```
find ./ | cpio -o -H newc | gzip > ../rootfs.img
```



### 產生核心
```
make -j8 ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabi- vexpress_defconfig

make -j8 ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabi- menuconfig
```
```
CONFIG_EXPERIMENTAL=y
# 使得編譯的內核包含一些調試信息，使得調試更容易。
CONFIG_DEBUG_INFO=y
CONFIG_KGDB=y
# 使用串口進行通信
CONFIG_KGDB_SERIAL_CONSOLE=y
# 使能該選項可以kgdb 不依賴 notifier_call_chain() 機制來獲取斷點異常, 這樣就可以對 notifier_call_chain() 機制實現相關的函數進行單步調試。
CONFIG_KGDB_LOW_LEVEL_TRAP=y
# 使能該選項將使得內核使用幀指針寄存器來維護堆棧，從而就可以正確地執行堆棧回溯，即函數調用棧信息。
CONFIG_FRAME_POINTER=y
# ( 如果你選擇了KGDB_SERIAL_CONSOLE, 這個選項將自動被選上) 激活" 魔術 SysRq" 鍵. 該選項對kgdboc 調試非常有用，kgdb 向其註冊了'g' 魔術鍵來激活kgdb 。
CONFIG_MAGIC_SYSRQ=y
# 選擇這個選項來驅動qemu-kvm的網卡設備，以備以後使用。
CONFIG_8139CP=y
# 該選項是將內核的一些內存區域空間設置為只讀，這樣可能導致kgdb 的設置軟斷點功能失效
CONFIG_DEBUG_SET_MODULE_RONX=n
# 將內核的一些內存區域空間設置為只讀，這樣可能導致kgdb 的設置軟斷點功能失效
CONFIG_DEBUG_RODATA=n


CONFIG_MODULE_FORCE_LOAD=y
CONFIG_MODULE_UNLOAD=y
CONFIG_MODULE_FORCE_UNLOAD=y
# CONFIG_MODVERSIONS is not set
# CONFIG_MODULE_SRCVERSION_ALL is not set
```

- make  ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabi- -j8

### 安裝 tftp
- sudo apt-get install tftp-hpa tftpd-hpa
- /etc/default/tftpd-hpa
```
# /etc/default/tftpd-hpa
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/tftpboot"
TFTP_ADDRESS="0.0.0.0:69"
TFTP_OPTIONS="-l -c -s"
```

- 建立 tftpboot
```
sudo mkdir /tftpboot
sudo chmod 777 /tftpboot
```

- restart service
```
sudo service tftpd-hpa restart
```
- test tftp
```
tftp host—ip  // ex tftp localhost
get or put
```

### 啟動 tap
- sudo ./nettap.sh  // 必須加上 sudo 
```
tunctl -u shihyu -t tap0 
ifconfig tap0 192.168.100.1 up 
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -I FORWARD 1 -i tap0 -j ACCEPT
iptables -I FORWARD 1 -o tap0 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

- 如果成功下ifconfig 會出現下面 message
```
tap0      Link encap:Ethernet  HWaddr 0a:18:ee:c4:f0:d0   
          inet addr:192.168.100.1  Bcast:192.168.100.255  Mask:255.255.255.0 
          UP BROADCAST MULTICAST  MTU:1500  Metric:1 
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0 
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0 
          collisions:0 txqueuelen:500  
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B) 
```

### 啟動 QEMU
```
qemu-system-arm -M vexpress-a9 -kernel zImage -initrd rootfs.img -serial stdio -append "root=/dev/ram rdinit=/sbin/init console=ttyAMA0" -k en-us -net nic -net tap,ifname=tap0,script=no
```
```
qemu-system-arm -M vexpress-a9 -kernel zImage -initrd rootfs.img -serial stdio -append "root=/dev/ram rdinit=/sbin/init console=ttyAMA0" -k en-us -net nic -net tap,ifname=tap0,script=no -gdb tcp::1234 -S
```

### 啟動 GDB
```
arm-unknown-linux-gnueabi-gdb ./vmlinux
target remote localhost:1234
```

### Debug Module
```
time make -j8 ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabi-
```
```
// globalmem.c
/*======================================================================
    A globalmem driver as an example of char device drivers

    The initial developer of the original code is Baohua Song
    <author@linuxdriver.cn>. All Rights Reserved.
======================================================================*/
#include <linux/module.h>
#include <linux/types.h>
#include <linux/fs.h>
#include <linux/errno.h>
#include <linux/mm.h>
#include <linux/sched.h>
#include <linux/init.h>
#include <linux/cdev.h>
#include <asm/io.h>
//#include <asm/system.h>
#include <asm/uaccess.h>
#include <linux/slab.h>

#define GLOBALMEM_SIZE  0x1000  /*全局内存最大4K字节*/
#define MEM_CLEAR 0x1  /*清0全局内存*/
#define GLOBALMEM_MAJOR 245    /*预设的globalmem的主设备号*/

static int globalmem_major = GLOBALMEM_MAJOR;
/*globalmem设备结构体*/
struct globalmem_dev {
    struct cdev cdev; /*cdev结构体*/
    unsigned char mem[GLOBALMEM_SIZE]; /*全局内存*/
};

struct globalmem_dev* globalmem_devp; /*设备结构体指针*/
/*文件打开函数*/
int globalmem_open(struct inode* inode, struct file* filp) {
    /*将设备结构体指针赋值给文件私有数据指针*/
    filp->private_data = globalmem_devp;
    return 0;
}
/*文件释放函数*/
int globalmem_release(struct inode* inode, struct file* filp) {
    return 0;
}

/* ioctl设备控制函数 */
static int globalmem_ioctl(struct inode* inodep, struct file* filp, unsigned
                           int cmd, unsigned long arg) {
    struct globalmem_dev* dev = filp->private_data;/*获得设备结构体指针*/

    switch (cmd) {
    case MEM_CLEAR:
        memset(dev->mem, 0, GLOBALMEM_SIZE);
        printk(KERN_INFO "globalmem is set to zero\n");
        break;

    default:
        return  - EINVAL;
    }

    return 0;
}

/*读函数*/
static ssize_t globalmem_read(struct file* filp, char __user* buf, size_t size,
                              loff_t* ppos) {
    unsigned long p =  *ppos;
    unsigned int count = size;
    int ret = 0;
    struct globalmem_dev* dev = filp->private_data; /*获得设备结构体指针*/

    /*分析和获取有效的写长度*/
    if (p >= GLOBALMEM_SIZE) {
        return count ?  - ENXIO : 0;
    }

    if (count > GLOBALMEM_SIZE - p) {
        count = GLOBALMEM_SIZE - p;
    }

    /*内核空间->用户空间*/
    if (copy_to_user(buf, (void*)(dev->mem + p), count)) {
        ret =  - EFAULT;
    } else {
        *ppos += count;
        ret = count;

        printk(KERN_INFO "read %d bytes(s) from %d\n", count, p);
    }

    return ret;
}

/*写函数*/
static ssize_t globalmem_write(struct file* filp, const char __user* buf,
                               size_t size, loff_t* ppos) {
    unsigned long p =  *ppos;
    unsigned int count = size;
    int ret = 0;
    struct globalmem_dev* dev = filp->private_data; /*获得设备结构体指针*/

    /*分析和获取有效的写长度*/
    if (p >= GLOBALMEM_SIZE) {
        return count ?  - ENXIO : 0;
    }

    if (count > GLOBALMEM_SIZE - p) {
        count = GLOBALMEM_SIZE - p;
    }

    /*用户空间->内核空间*/
    if (copy_from_user(dev->mem + p, buf, count)) {
        ret =  - EFAULT;
    } else {
        *ppos += count;
        ret = count;

        printk(KERN_INFO "written %d bytes(s) from %d\n", count, p);
    }

    return ret;
}

/* seek文件定位函数 */
static loff_t globalmem_llseek(struct file* filp, loff_t offset, int orig) {
    loff_t ret = 0;

    switch (orig) {
    case 0:   /*相对文件开始位置偏移*/
        if (offset < 0) {
            ret =  - EINVAL;
            break;
        }

        if ((unsigned int)offset > GLOBALMEM_SIZE) {
            ret =  - EINVAL;
            break;
        }

        filp->f_pos = (unsigned int)offset;
        ret = filp->f_pos;
        break;

    case 1:   /*相对文件当前位置偏移*/
        if ((filp->f_pos + offset) > GLOBALMEM_SIZE) {
            ret =  - EINVAL;
            break;
        }

        if ((filp->f_pos + offset) < 0) {
            ret =  - EINVAL;
            break;
        }

        filp->f_pos += offset;
        ret = filp->f_pos;
        break;

    default:
        ret =  - EINVAL;
        break;
    }

    return ret;
}

/*文件操作结构体*/
static const struct file_operations globalmem_fops = {
    .owner = THIS_MODULE,
    .llseek = globalmem_llseek,
    .read = globalmem_read,
    .write = globalmem_write,
    .unlocked_ioctl = globalmem_ioctl,
    .open = globalmem_open,
    .release = globalmem_release,
};

/*初始化并注册cdev*/
static void globalmem_setup_cdev(struct globalmem_dev* dev, int index) {
    int err, devno = MKDEV(globalmem_major, index);

    cdev_init(&dev->cdev, &globalmem_fops);
    dev->cdev.owner = THIS_MODULE;
    dev->cdev.ops = &globalmem_fops;
    err = cdev_add(&dev->cdev, devno, 1);

    if (err) {
        printk(KERN_NOTICE "Error %d adding LED%d", err, index);
    }
}

/*设备驱动模块加载函数*/
int globalmem_init(void) {
    int result;
    dev_t devno = MKDEV(globalmem_major, 0);

    /* 申请设备号*/
    if (globalmem_major) {
        result = register_chrdev_region(devno, 1, "globalmem");
    } else { /* 动态申请设备号 */
        result = alloc_chrdev_region(&devno, 0, 1, "globalmem");
        globalmem_major = MAJOR(devno);
    }

    if (result < 0) {
        return result;
    }

    /* 动态申请设备结构体的内存*/
    globalmem_devp = kmalloc(sizeof(struct globalmem_dev), GFP_KERNEL);

    if (!globalmem_devp) {  /*申请失败*/
        result =  - ENOMEM;
        goto fail_malloc;
    }

    memset(globalmem_devp, 0, sizeof(struct globalmem_dev));

    globalmem_setup_cdev(globalmem_devp, 0);
    return 0;

fail_malloc:
    unregister_chrdev_region(devno, 1);
    return result;
}

/*模块卸载函数*/
void globalmem_exit(void) {
    cdev_del(&globalmem_devp->cdev);   /*注销cdev*/
    kfree(globalmem_devp);     /*释放设备结构体内存*/
    unregister_chrdev_region(MKDEV(globalmem_major, 0), 1); /*释放设备号*/
}

MODULE_AUTHOR("Song Baohua");
MODULE_LICENSE("Dual BSD/GPL");

module_param(globalmem_major, int, S_IRUGO);

module_init(globalmem_init);
module_exit(globalmem_exit);
```

```
obj-m	+= globalmem.o
KDIR	= /media/ssd/arm_work/linux-3.15.7

EXTRA_CFLAGS=-g -O0

build:kernel_modules

kernel_modules:
	make -C $(KDIR) M=$(CURDIR) modules

clean:
	make -C $(KDIR) M=$(CURDIR) clean 
```

break 必須加上* 目前原因不清楚 , x86 沒這問題

```
insmod globalmem.ko
mknod /dev/globalmem c 245 0

b *globalmem_write
b *globalmem_read
c
echo "Hello world" > /dev/globalmem   
```
