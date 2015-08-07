	.equ   seg_code, 0x07C0	# 结合ljmp, 指定代码的加载位置，当然，也可以在外面指定
.code16          		#使用16位模式汇编(GAS 默认认为 .S 文件是 pure 32-bits i386 code)
.text            		#代码段开始(为 link script 做定位)
	ljmp   $seg_code, $start
start:
        mov    %cs, %ax
        mov    %ax, %ds
        mov    %ax, %es
        call   DispStr          #调用显示字符串例程
INF:    jmp    INF	        #无限循环(GAS 没有 $ 作为当前行标号的约定)
DispStr:
        mov    $BootMessage, %ax
        mov    %ax, %bp         # ES:BP = 串地址
        mov    $13, %cx         # CX = 串长度
        mov    $0x1301, %ax     # AH = 13,  AL = 01h
        mov    $0x00c, %bx      # 页号为0(BH = 0) 黑底红字(BL = 0Ch,高亮)
        mov    $0x00, %dl
        int    $0x10            # 10h 号中断
        ret
BootMessage:.ascii "Hello, world!"
.org 510            		# 填充到 510 字节，使生成的二进制代码恰好为512字节
.word 0xaa55        		# 结束标志
