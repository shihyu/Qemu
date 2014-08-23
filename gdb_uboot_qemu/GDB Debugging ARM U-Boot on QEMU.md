# GDB Debugging ARM U-Boot on QEMU


### Qemu
```
對arm支持較好的qemu版本: qemu-linaro。可以用git拿到源碼。
git clone git://git.linaro.org/qemu/qemu-linaro.git

```



- 編譯器使用
```
https://github.com/Christopher83/linaro_toolchains_2014
linaro_toolchains_2013
arm-unknown-linux-gnueabi-linaro_4.8.3-2013.12
```


```
http://ftp.denx.de/pub/u-boot/u-boot-2014.07.tar.bz2

make vexpress_ca9x4_config ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabi-

make all ARCH=arm CROSS_COMPILE=arm-unknown-linux-gnueabi-
```

- 運行u-boot.bin:
```
qemu-system-arm -M vexpress-a9  -serial stdio -kernel u-boot
```
### GDB
```
1. 先運行
qemu-system-arm -M vexpress-a9  -serial stdio -kernel u-boot -s -S
然後，在另一個虛擬終端窗口執行：

arm-linux-gnueabi-gdb u-boot
...
(gdb) target remote localhost:1234
```

```
GDB Debugging ARM U-Boot on QEMU
1 Introduction

QEMU is a generic and open source machine emulator and virtualizer. In this article, we will use it as a machine emulator and run the U-Boot on top of it. It will also be demonstrated about how to debug U-Boot with GDB. 

2 Installation and Compilation

2.1 Cross Toolchain

Install one of the cross toolchain accordingly. available toolchains: 
DENX - ELDK (Embedded Linux Development Kit) : document
Mentor Graphics - Sourcery ARM EABI toolchain : document
BuildRoot - buildroot-2011.11.tar.bz2 : document

2.2 QEMU package

Install Debian QEMU package. 
# apt-get install qemu
Or on a host running Ubuntu, try 
$ sudo apt-get install qemu-kvm-extras
We may also check if ARM versatilePB is supported by QEMU. 
$ qemu-system-arm -M \?

2.3 Download U-Boot

Fetch the current Das U-Boot source code through git. 
$ git clone git://git.denx.de/u-boot.git
Or download a released version from ftp site.

2.4 Compile U-Boot.

$ cd u-boot/
$ make versatileqemu_config
$ make
Or if a cross toolchain with different prefix is used, ELDK's "arm-linux-gnueabi-" for example, 
$ make CROSS_COMPILE=arm-linux-gnueabi-

3 Testing and Debugging

3.1 Normal Mode

We can execute QEMU to run U-Boot for ARM, then develop and debug as we wish. 
$ qemu-system-arm -nographic -M versatilepb -m 128 -kernel u-boot
U-Boot 2011.12-00046-gbfcc40b-dirty (Dec 26 2011 - 18:11:37)

DRAM:  128 MiB
WARNING: Caches not enabled
Using default environment

In:    serial
Out:   serial
Err:   serial
Net:   SMC91111-0
Warning: failed to set MAC address

VersatilePB #

A list of u-boot commands and environment variables, 
VersatilePB # help
?       - alias for 'help'
base    - print or set address offset
bdinfo  - print Board Info structure
bootm   - boot application image from memory
bootp   - boot image via network using BOOTP/TFTP protocol
cmp     - memory compare
cp      - memory copy
crc32   - checksum calculation
dhcp    - boot image via network using DHCP/TFTP protocol
env     - environment handling commands
erase   - erase FLASH memory
flinfo  - print FLASH memory information
go      - start application at address 'addr'
help    - print command description/usage
iminfo  - print header information for application image
loop    - infinite loop on address range
md      - memory display
mm      - memory modify (auto-incrementing address)
mtest   - simple RAM read/write test
mw      - memory write (fill)
nm      - memory modify (constant address)
ping    - send ICMP ECHO_REQUEST to network host
printenv- print environment variables
protect - enable or disable FLASH write protection
reset   - Perform RESET of the CPU
setenv  - set environment variables
tftpboot- boot image via network using TFTP protocol
version - print monitor, compiler and linker version
VersatilePB #
VersatilePB # printenv
baudrate=38400
bootargs=root=/dev/nfs mem=128M ip=dhcp netdev=25,0,0xf1010000,0xf1010010,eth0
bootdelay=2
bootfile=/tftpboot/uImage
ethact=SMC91111-0
stderr=serial
stdin=serial
stdout=serial
verify=n

Environment size: 219/8188 bytes
VersatilePB #

3.2 Debugging with GDB

While QEMU's built-in monitor provides limited debugging support, it can act as a remote debugging target for GDB. 
$ qemu-system-arm -nographic -M versatilepb -m 128 -kernel u-boot -S -s
'-S' tells QEMU not to start CPU at startup. We must type 'c' in monitor to let it continue. '-s' is shorthand for '-gdb tcp::1234', telling QEMU to wait for gdb connection on TCP port 1234. 

On the other hand, we start the ARM GDB and set target to TCP port 1234 as well. 
$ arm-linux-gnueabi-gdb u-boot
GNU gdb (GDB) 7.3
Copyright (C) 2011 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.  Type "show copying"
and "show warranty" for details.
This GDB was configured as "--host=i686-eldk-linux --target=arm-linux-gnueabi".
For bug reporting instructions, please see:
<http://www.gnu.org/software/gdb/bugs/>...
Reading symbols from /home/winfred/u-boot/u-boot...done.
(gdb) target remote :1234
Remote debugging using :1234
_start () at start.S:64
64              b       reset
(gdb)

We are able to use GDB for source level debugging now. 
(gdb) n
188             mrs     r0,cpsr
(gdb) n
189             bic     r0,r0,#0x1f
(gdb) b board_init_f
Breakpoint 1 at 0x10b70: file board.c, line 270.
(gdb) c
Continuing.

Breakpoint 1, board_init_f (bootflag=0) at board.c:270
270             gd = (gd_t *) ((CONFIG_SYS_INIT_SP_ADDR) & ~0x07);
(gdb)

3.3 Debugging After Relocation

In order to debug U-Boot after relocation, we need to know the address which U-Boot relocates itself to. There are couple of ways to get it, 
Get it from U-Boot 'bdinfo' command.
VersatilePB # bdinfo
arch_number = 0x00000183
boot_params = 0x00000100
DRAM bank   = 0x00000000
-> start    = 0x00000000
-> size     = 0x08000000
ethaddr     = (not set)
ip_addr     = 0.0.0.0
baudrate    = 38400 bps
TLB addr    = 0x07FF0000
relocaddr   = 0x07FC5000
reloc off   = 0x07FB5000
irq_sp      = 0x07FA2F70
sp start    = 0x07FA2F60
FB base     = 0x00000000
VersatilePB #
Print the value of gd->relocaddr. Since gd is avalable after board_init_f(), and it is storeed in register $r1,
(gdb) b relocate_code
Breakpoint 1 at 0x1007c: file start.S, line 226.
(gdb) c
Continuing.

Breakpoint 1, relocate_code () at start.S:226
226             mov     r5, r1  /* save addr of gd */
(gdb) p/x ((gd_t *)$r1)->relocaddr
$1 = 0x7fc5000
(gdb)

Having the relocated address, we need to reload the symbol file accordingly. 
(gdb) d
Delete all breakpoints? (y or n) y
(gdb) symbol-file
Discard symbol table from `/home/winfred/u-boot/u-boot'? (y or n) y
No symbol file now.
(gdb) add-symbol-file u-boot 0x7fc5000
add symbol table from file "u-boot" at
.text_addr = 0x7fc5000
(y or n) y
Reading symbols from /home/winfred/u-boot/u-boot...done.
(gdb)

Then, debug U-Boot after relocation. Let's try to break at the first function after the relocation, 
(gdb) b board_init_r
Breakpoint 2 at 0x7fc5d64: file board.c, line 455.
(gdb) c
Continuing.

Breakpoint 2, board_init_r (id=0x7fa2f70, dest_addr=133976064) at board.c:455
455             gd = id;
(gdb)

Happy debugging.

4 Reference
Balau, U-boot for ARM on QEMU
Balau, Booting Linux with U-Boot on QEMU ARM
Khem Raj, Debugging Linux systems using GDB and QEMU
QEMU Documentation
U-Boot Documentation - Debugging UBoot
GDB Documentation - Debugging Remote Programs
Date: 2011-12-26 Thu
HTML generated by org-mode 6.33x in emacs 23
```