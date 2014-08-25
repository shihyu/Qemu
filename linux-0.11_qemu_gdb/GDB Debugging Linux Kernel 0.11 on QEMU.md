# GDB Debugging Linux Kernel 0.11 on QEMU

```
qemu-system-i386 -m 16M -boot a -fda Image -hda rootfs/hdc-0.11-new.img

qemu-system-x86_64 -m 16M -boot a -fda Image -hda rootfs/hdc-0.11-new.img -gdb tcp::1234 -S

這邊有兩個 -s 與 -S，分別代表不同意義

-s(小寫 s)：運行虛擬機時將 1234 端口開啟成調試端口，供 eclipse 網絡調試時使用
-S(大寫 S)：啟動虛擬機時要「凍住」虛擬機，等待調試器發出繼續運行的命令
-fda：在 qemu 中，是使用檔案來模擬磁碟的，這邊的意思是，使用 Imgae 這個檔案來當作 floppy A
-m：設定模擬的記憶體有多大，這邊設定記憶體大小為 16MB

順利的話，應該會顯示黑畫面，代表目前 QEMU 被凍住，等待 GDB client
在開另一個 terminal，鍵入
```


```
遇到 qemu-linaro "could not load PC BIOS"

sudo apt-get install seabios

將 seabios 套件安裝，並且在 /usr/local/share/qemu 作連結，指令如下：

# ln -sf /usr/share/bios/*.bin 
```

```
gdb tools/system
```
```
連線至遠端
(gdb) target remote localhost:1234
```

```
下中斷，停在 CS = 0x7C00 的地方，也就是 BIOS 把 MBR 載入的地方
(gdb)  br *0x7c00
```

```
在此時，bios 把控制權正式的交給了 linux，也就是說這裡開始就是我們自己控制的地方
而 0x7C00 對應的 code 應該是 bootsect.S

觀察0x7DFE 與 0x7DFF的值是否為0x55，0xAA

(gdb) x/16b 0x7DF0
```

```
因為這邊是組合語言，所以要用 si 來單步
(gdb) si
```

```
下中斷

(gdb) b main
執行至中斷 ，則就會執行到 main 中
```

