	.equ   seg_code, 0x7C0
.code16            		#使用16位模式汇编(GAS 默认认为 .S 文件是 pure 32-bits i386 code)
.text            		#代码段开始(为 link script 做定位)
	ljmp   $seg_code, $start
start:
        mov    %cs, %ax
        mov    %ax, %ds
        call   DispStr          #调用显示字符串例程
INF:    jmp    INF	        #无限循环(GAS 没有 $ 作为当前行标号的约定)
DispStr:
	# set standard 80x25 textmode
	mov	$0x0003, %ax
	int	$0x10
	# load 8x8 character-glyphs
	mov	$0x1112, %ax
	xor	%bx, %bx
	int	$0x10
	# write the string to VRAM
	mov     $0xb800, %ax	# VRAM(显存)的段地址
	mov     %ax, %es
	xor     %di, %di
	mov     $BootMessage, %si
	movb    $0x07, %ah
	mov	len, %cx
nxpel:	
	lodsb			# the same as the following two instrucions
	#movb    %ds:(%si), %al
	#inc     %si
	
	stosw			# the same as the following three instructions
	#movb    %al, %es:0(%di)
	#movb 	 %ah, %es:1(%di)
	#add     $0x02, %di

	loop	nxpel
	# reboot if any key is pressed
	xor	%ah, %ah
	int	$0x16

	int	$0x19
	ret
BootMessage: .ascii "Hello, world!"
len: .word . - BootMessage
.org 510            		# 填充到 510 字节，使生成的二进制代码恰好为512字节
.word 0xaa55        		# 结束标志
