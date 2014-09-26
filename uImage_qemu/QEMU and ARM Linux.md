### QEMU and ARM Linux 

hello.c - hello.c
```c
#include<stdio.h>
int main()
{
    printf("Hello, Qemu!\n");
    return 0;
}
```

編譯並運行:
```sh
$ arm-none-linux-gnueabi-gcc -o hello hello.c -static
$ qemu-arm ./hello
$ file hello
hello: ELF 32-bit LSB  executable, ARM, EABI5 version 1 (SYSV), \
 statically linked, for GNU/Linux 2.6.16, not stripped
```
不加-static變量的話，運行時則需要使用-L選項鏈接到相應的運行庫
```sh
qemu-arm -L /media/ssd/arm_work/4.3.2/arm-none-linux-gnueabi/libc
```
系統裡安裝了兩套編譯鏈arm-none-eabi-和arm-none-linux-eabi-,很容易讓人混淆，可參考編譯鏈的命名規則：
- arch(架構)-vendor(廠商名)–(os(操作系統名)–)abi(Application Binary Interface，應用程序二進制接口)

舉例說明：

- x86_64-w64-mingw32 = x86_64 「arch」字段 (=AMD64), w64 (=mingw-w64 是」vendor」字段), mingw32 (=GCC所見的win32 API)
- i686-unknown-linux-gnu = 32位 GNU/linux編譯鏈
- arm-none-linux-gnueabi = ARM 架構, 無vendor字段, linux 系統, gnueabi ABI.
- arm-none-eabi = ARM架構, 無廠商, eabi ABI(embedded abi)

兩種編譯鏈的主要區別在於庫的差別，前者沒有後者的庫多，後者主要用於在有操作系統的時候編譯APP用的。前者不包括標準輸入輸出庫在內的很多C標準庫，適合於做面向硬件的類似單片機那樣的開發。因而如果採用arm-none-eabi-gcc來編譯hello.c會出現鏈接錯誤。


qemu-arm和qemu-system-arm的區別：

- qemu-arm是用戶模式的模擬器(更精確的表述應該是系統調用模擬器)，而qemu-system-arm則是系統模擬器，它可以模擬出整個機器並運行操作系統
- qemu-arm僅可用來運行二進制文件，因此你可以交叉編譯完例如hello world之類的程序然後交給qemu-arm來運行，簡單而高效。而qemu-system-arm則需要你把hello world程序下載到客戶機操作系統能訪問到的硬盤裡才能運行

安裝build uImage 所需套件
``` sh
sudo apt-get install u-boot-tools
sudo apt-get install uboot-mkimage
```

使用qemu-system-arm運行Linux內核
``` sh
export PATH=$PATH:/media/ssd/arm_work/4.3.2/bin
export ARCH=arm
export CROSS_COMPILE=arm-none-linux-gnueabi-
make mrproper &&
make clean &&
make versatile_defconfig
make menuconfig
time make uImage -j8
```

```c
#include <stdio.h>

void main() {
    printf("Hello World!\n");
    while(1);
}
```

```sh
$ arm-none-linux-gnueabi-gcc -o init init.c -static
$ echo init |cpio -o --format=newc > initramfs
1280 blocks
$ file initramfs 
initramfs: ASCII cpio archive (SVR4 with no CRC)
```

```sh
qemu-system-arm -M versatilepb -kernel ./arch/arm/boot/uImage  -initrd ../initramfs -serial stdio -append "console=tty1"
```

這時候可以看到，kernel運行並在Qemu自帶的終端裡打印出 Hello World!。
如果我們改變console變量為ttyAMA0, 將在啟動qemu-system-arm的本終端上打印出qemu的輸出。




