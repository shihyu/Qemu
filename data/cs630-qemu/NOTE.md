# NOTE

## Chapter 15 & 17

### Compile manydot.s on 64bit hosts

```
$ as --32 resources/manydots.s -o resources/manydots.o
$ ld -m elf_i386 resources/manydots.o -o resources/manydots
$ ./resources/manydots 
How many dots do you want to see? 10
..........
$
```

### Using hello.s and try32bit.s

- hello.s

```
$ as --32 resources/hello.s -o resources/hello.o 
$ ld -m elf_i386 resources/hello.o -o resources/hello
$ resources/hello
```

- hello.s + try32bit.s:

```
$ ./configure resources/try32bit.s 
$ make
$ dd if=resources/hello.o of=pmboot.img seek=13
$ make pmboot
```

### Compile loadmap.cpp in gentoo 64bit

```
$ g++ -m32 loadmap.cpp -o loadmap
```

- why gentoo? because, in ubuntu 64bit and debian 64bit, it can not find the
suitable libstdc++, the ld not work normally. even if you do not have gentoo,
do not worry, you can use -S with readelf or -h with objdump instead of loadmap
to get the map of hello.o.

- In lesson 17, the basic procedure is the same, you just need to substitute
try32bit.s as trydebug.s

## Chapter 19

if you want to run hello in elfexec.s, the memory given to qemu should more
than 128M for the text and data section of hello will be copied to 0x08048000
and 0x08049000 which is more than 128M, so in qemu.sh we use.

```
qemu-system-i386 -m 129M -fda $image -boot a
```

## Chapter 23 and later?

if you want to support smp with qemu, you can use the -smp options.
