//-----------------------------------------------------------------
//	emulate.s	(a modification of our 'tryvm86.s' demo)
//
//	This program, after entering protected-mode, executes  
//	a real-mode procedure in Virtual-8086 emulation mode.
//	This program emulates the 'io-sensitive' instructions 
//	which occur in VM86-mode if IOPL<3, and which trigger
//	General Protection Faults with an error-code of zero. 
//
//	 to assemble: $ as emulate.s -o emulate.o 
//	 and to link: $ ld emulate.o -T ldscript -o emulate.o 
//
//	NOTE: This code begins executing with CS:IP = 1000:0002. 
//
//	programmer: ALLAN CRUSE
//	written on: 23 MAR 2004
//	revised on: 28 APR 2004 -- added io-sensitive emulations
//	bug repair: 28 APR 2004 -- enlarged TSS to include iomap
//	revised on: 05 NOV 2006 -- to use GNU assembler's syntax
//-----------------------------------------------------------------

	.code16				# for Pentium 'real-mode'

	.section	.text
#------------------------------------------------------------------
	.word	0xABCD			# programming signature 
#------------------------------------------------------------------
main:	mov	%sp, %cs:exit_pointer+0	# preserve the loader's SP
	mov	%ss, %cs:exit_pointer+2	# preserve the loader's SS

	mov	%cs, %ax		# address this segment 
	mov	%ax, %ds		#   with DS register  
	mov	%ax, %ss		#  adjust SS register 
	lea	tos0, %esp		# establish new stacktop 
	
	call	initialize_os_tables
	call	enter_protected_mode
	call	execute_program_demo 
	call	leave_protected_mode 

	lss	%cs:exit_pointer, %sp	# recover saved stacktop  
	lret				# back to program loader  
#------------------------------------------------------------------
exit_pointer:	.word	0, 0		# holds loader's SS and SP  
#------------------------------------------------------------------
	.align	8 		# CPU requires quadword alignment
theGDT:	.word	0x0000, 0x0000, 0x0000, 0x0000	# null descriptor
	.equ	sel_es, (.-theGDT)+0	# vram-segment's selector 
	.word	0x0007, 0x8000, 0x920B, 0x0080	# vram descriptor 
	.equ	sel_cs, (.-theGDT)+0	# code-segment's selector 
	.word	0xFFFF, 0x0000, 0x9A01, 0x0000	# code descriptor 
	.equ	sel_ss, (.-theGDT)+0	# data-segment's selector 
	.word	0xFFFF, 0x0000, 0x9201, 0x0000	# data descriptor 
	.equ	sel_fs, (.-theGDT)+0	# flat-segment's selector 
	.word	0xFFFF, 0x0000, 0x9200, 0x008F	# flat descriptor 
	.equ	sel_ts, (.-theGDT)+0	# task-segment's selector 
	.word	0x2168, theTSS, 0x8901, 0x0000	#  TSS descriptor 
	.equ	limGDT, (.-theGDT)-1	# the GDT-segment's limit 
#------------------------------------------------------------------
theIDT:	.space	2048		# enough for 256 gate-descriptors
#------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001	# image for GDTR register
regIDT:	.word	0x07FF, theIDT, 0x0001	# image for IDTR register
regIVT:	.word	0x03FF, 0x0000, 0x0000	# image for IDTR register
#------------------------------------------------------------------
enter_protected_mode: 

	cli				# no device interrupts 
	mov	%cr0, %eax		# get machine status 
	bts	$0, %eax		# set PE-bit to 1 
	mov	%eax, %cr0		# enable protection 

	lgdt	regGDT			# setup register GDTR  
	lidt	regIDT			# setup register IDTR 

	ljmp	$sel_cs, $pm		# reload register CS 
pm:	
	mov	$sel_ss, %ax		
	mov	%ax, %ss		# reload register SS 
	mov	%ax, %ds		# reload register DS 

	xor	%ax, %ax		# use 'null' selector 
	mov	%ax, %es		# to purge invalid ES 
	mov	%ax, %fs		# to purge invalid FS 
	mov	%ax, %gs		# to purge invalid GS 

	ret				# back to main routine 
#------------------------------------------------------------------
leave_protected_mode: 

	mov	$sel_fs, %ax		# address 4GB r/w segment
	mov	%ax, %fs		#   using FS register
	mov	%ax, %gs		#    and GS register

	mov	$sel_ss, %ax		# address 64KB r/w segment
	mov	%ax, %ds		#   using DS register
	mov	%ax, %es		#    and ES register

	mov	%cr0, %eax		# get machine status 
	btr	$0, %eax		# reset PE-bit to 0 
	mov	%eax, %cr0		# disable protection 

	lidt	regIVT			# load IDTR register-image 

	ljmp	$0x1000, $rm		# reload register CS 
rm:	
	mov	%cs, %ax	
	mov	%ax, %ss		# reload register SS 
	mov	%ax, %ds		# reload register DS 

	sti				# interrupts allowed 
	ret				# back to main routine 
#------------------------------------------------------------------
#------------------------------------------------------------------
initialize_os_tables:

	# initialize IDT descriptor for gate 0x0D
	mov	$0x0D, %ebx		# ID-number for GP-fault
	lea	theIDT(, %ebx, 8), %di	# address gate-descriptor
	movw	$isrGPF, 0(%di)		# entry-point loword
	movw	$sel_cs, 2(%di)		# selector for code
	movw	$0x8E00, 4(%di)		# 386 interrupt-gate
	movw	$0x0000, 6(%di)		# entry-point hiword

	# initialize 'iomap' field in TSS 
	lea	theTSS, %di		# address our TSS segment
	movw	$68, 0x66(%di)		# where the bitmap begins   
	
	cld
	lea	68(%di), %di
	mov	$8192, %cx
	xor	%ax, %ax
	rep	stosb

	ret
#------------------------------------------------------------------
execute_program_demo:

	mov	%esp, theTSS+4 		# current stack-address  
	mov	%ss,  theTSS+8		# preserved in 'theTSS'

	mov	$sel_ts, %ax		# establish 'theTSS' as
	ltr	%ax			#  Task-State Segment

	pushfl				# insure NT-bit is clear  
	btrl	$14, (%esp)		# in the EFLAGS register
	popfl				# before executing iretd

	pushl	$0			# register-image for GS
	pushl	$0			# register-image for FS
	pushl	$0			# register-image for DS
	pushl	$0			# register-image for ES
	pushl	$0x1000			# register-image for SS
	pushl	$tos3			# register-image for SP
	pushl	$0x00020000		# EFLAGS (note: IOPL=0)
	pushl	$0x1000			# register-image for CS
	pushl	$write_tty 		# register-image for IP
	iretl				# enter Virtual-8086 mode 
#------------------------------------------------------------------
finish_up_main_thread:
	lss	%cs:theTSS+4, %esp	# restore saved stackptr
	ret				# return to main routine
#------------------------------------------------------------------
msg:	.ascii	" Hello from Virtual-8086 mode \n\r"
len:	.word	. - msg			# length of message-text
att:	.byte	0x1F			# intense white upon blue
#------------------------------------------------------------------
write_tty:

mov $0xB800, %ax
mov %ax, %gs
movw $0x3F41, %gs:210

mov $0xAAAAAAAA, %eax
mov $0xBBBBBBBB, %ebx
mov $0xCCCCCCCC, %ecx
mov $0xDDDDDDDD, %edx
mov $0xEEEEEEEE, %esi
mov $0xFFFFFFFF, %edi


	int	$0x1C

movw $0x3F49, %gs:212



	mov	%cs, %ax
	mov	%ax, %ds
	mov	%ax, %es
	mov	$0x0F, %ah
	int	$0x10
movw $0x3F4A, %gs:214
	mov	$0x03, %ah
	int	$0x10

movw $0x3F4B, %gs:216

	lea	msg, %bp
	mov	len, %cx
	mov	att, %bl
	mov	$0x1301, %ax
	int	$0x10

	hlt				# privileged instruction
#------------------------------------------------------------------
#------------------------------------------------------------------
isrGPF:	
	# verify that the exception occurred in Virtual-8086 mode
	btl	$17, 12(%esp)		# was VM-flag set?
	jc	emulate			# yes, do emulation

jmp show_stack

	ljmp	$sel_cs, $finish_up_main_thread # else quit
emulate:
	push	%ebp
	mov	%esp, %ebp
	pushal

	mov	$sel_fs, %ax		# address 4GB memory
	mov	%ax, %ds		#  with DS register

	# compute address of the faulting instruction in ESI
	mov	12(%ebp), %si 		# fetch the CS-image
	movzx	%si, %esi		# extend to 32 bits
	shl	$4, %esi 		# sixteen times CS
	mov	8(%ebp), %ax 		# fetch the IP-image
	movzx	%ax, %eax		# extend to 32 bits
	add	%eax, %esi		# add offset to base

	# switch on the faulting instruction's opcode
	cmpb	$0xCD, (%esi)		# was it 'int-nn'?
	je	emulate_int		# yes, then emulate	
	
	cmpb	$0xCF, (%esi) 		# was it 'iret'?
	je	emulate_iret		# yes, then emulate	
	
	cmpb	$0x9C, (%esi)		# was it 'pushf'?
	je	emulate_pushf		# yes, then emulate	
	
	cmpb	$0x9D, (%esi)		# was it 'popf'?
	je	emulate_popf		# yes, then emulate	
	
	cmpb	$0xFA, (%esi)		# was it 'cli'?
	je	emulate_cli		# yes, then emulate	
	
	cmpb	$0xFB, (%esi)		# was it 'sti'?
	je	emulate_sti		# yes, then emulate	

	# more emulations can go here (e.g., pushfd/popfd/iretd)	

	ljmp	$sel_cs, $finish_up_main_thread # else quit
em_exit:
	popal
	pop	%ebp
	add	$4, %esp
	iretl
#------------------------------------------------------------------
emulate_int:
	
	# advance IP-image past the two-byte 'int-nn' instruction
	addw	$2, 8(%ebp) 		# advance the IP-image

	# decrement SP-image to make room for three pushed words
	subw	$6, 20(%ebp) 		# make room for 3 words

	# compute address of the ring3 stacktop in EDI
	movw	24(%ebp), %di		# fetch the SS-image
	movzx	%di, %edi		# extend to 32 bits
	shl	$4, %edi		# sixteen times CS
	mov	20(%ebp), %ax 		# fetch the SP-image
	movzx	%ax, %eax		# extend to 32 bits
	add	%eax, %edi		# add offset to base

	# transfer IP, CS, and FLAGS images to the ring3 stack
	mov	8(%ebp), %ax 		# fetch IP-image
	mov	%ax, 0(%edi)		# store IP-image
	mov	12(%ebp), %ax 		# fetch CS-image
	mov	%ax, 2(%edi) 		# store CS-image
	mov	16(%ebp), %ax 		# fetch FL-image
	mov	%ax, 4(%edi) 		# store FL-image

	# clear the IF-bit and TF-bit in the EFLAGS image
	btrl	$9, 16(%ebp) 		# reset CF-bit	
	btrl	$8, 16(%ebp) 		# reset TF-bit	

	# get the interrupt ID-number in EBX
	mov	(%esi), %ax		# fetch int-nn instruction
	movzx	%ah, %ebx		# extend int-ID to 32-bits
	
	# use real-mode interrupt-vector as the return-address
	mov	0(, %ebx, 4), %ax 	# get vector loword
	mov	%ax, 8(%ebp)		# setup as IP-image
	mov	2(, %ebx, 4), %ax 	# get vector hiword
	mov	%ax, 12(%ebp) 		# setup as CS-image

	# ok, we're ready to return to the VM86 task
	jmp	em_exit	
#------------------------------------------------------------------
emulate_iret:
	
	# advance IP-image past the one-byte 'iret' instruction
	addw	$1, 8(%ebp)		# advance the IP-image

	# compute address of the ring3 stacktop in EDI
	mov	24(%ebp), %di 		# fetch the SS-image
	movzx	%di, %edi		# extend to 32 bits
	shl	$4, %edi 		# sixteen times CS
	mov	20(%ebp), %ax 		# fetch the SP-image
	movzx	%ax, %eax		# extend to 32 bits
	add	%eax, %edi 		# add offset to base

	# transfer IP, CS, and FLAGS images to the ring0 stack
	mov	0(%edi), %ax 		# fetch IP-image
	mov	%ax, 8(%ebp)		# store IP-image
	mov	2(%edi), %ax		# fetch CS-image
	mov	%ax, 12(%ebp)		# store CS-image
	mov	4(%edi), %ax		# fetch FL-image
	mov	%ax, 16(%ebp)		# store FL-image

	# increment SP-image to discard the three poped words
	addw	$6, 20(%ebp)		# discard 3 words

	# ok, we're ready to return to the VM86 task
	jmp	em_exit	
#------------------------------------------------------------------
emulate_pushf:

	# advance IP-image past the one-byte 'pushf' instruction
	addw	$1, 8(%ebp)		# advance the IP-image

	# decrement SP-image to make room for the pushed word
	subw	$2, 20(%ebp)		# make room for 1 word

	# compute address of the ring3 stacktop in EDI
	mov	24(%ebp), %di 		# fetch the SS-image
	movzx	%di, %edi		# extend to 32 bits
	shl	$4, %edi 		# sixteen times CS
	mov	20(%ebp), %ax		# fetch the SP-image
	movzx	%ax, %eax		# extend to 32 bits
	add	%eax, %edi 		# add offset to base

	# transfer FLAGS images to the ring3 stack
	mov	16(%ebp), %ax 		# fetch FL-image
	mov	%ax, 0(%edi) 		# store FL-image

	# ok, we're ready to return to the VM86 task
	jmp	em_exit	
#------------------------------------------------------------------
emulate_popf:

	# advance IP-image past the one-byte 'popf' instruction
	addw	$1, 8(%ebp) 		# advance the IP-image

	# compute address of the ring3 stacktop in EDI
	mov	24(%ebp), %di		# fetch the SS-image
	movzx	%di, %edi		# extend to 32 bits
	shl	$4, %edi		# sixteen times CS
	mov	20(%ebp), %ax 		# fetch the SP-image
	movzx	%ax, %eax		# extend to 32 bits
	add	%eax, %edi 		# add offset to base

	# transfer FLAGS images to the ring0 stack
	mov	0(%edi), %ax 		# fetch FL-image
	mov	%ax, 16(%ebp) 		# store FL-image

	# increment SP-image to discard the poped word
	addw	$2, 20(%ebp) 		# discard 1 word 

	# ok, we're ready to return to the VM86 task
	jmp	em_exit	
#------------------------------------------------------------------
emulate_cli:

	# advance IP-image past the one-byte 'cli' instruction
	addw	$1, 8(%ebp) 		# advance the IP-image

	# clear the IF-bit in the EFLAGS register-image
	btrl	$9, 16(%ebp) 		# reset the IF-bit

	# ok, we're ready to return to the VM86 task
	jmp	em_exit	
#------------------------------------------------------------------
emulate_sti:

	# advance IP-image past the one-byte 'sti' instruction
	addw	$1, 8(%ebp) 		# advance the IP-image

	# set the IF-bit in the EFLAGS register-image
	btsl	$9, 16(%ebp) 		# set the IF-bit

	# ok, we're ready to return to the VM86 task
	jmp	em_exit	
#------------------------------------------------------------------
	.align	16			# assure stack alignment
	.space	512			# reserved for stack use 
tos3:					# label fop top-of-stack 
#------------------------------------------------------------------
	.align	16			# assure stack alignment
	.space	512			# reserved for stack use 
tos0:					# label fop top-of-stack 
#------------------------------------------------------------------
	.ascii	"UUUUUUUUUUUUUUUU"
#------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"
buf:	.ascii	" xxxxxxxx "

eax2hex:
	pushal
	
	mov	$8, %ecx
nxnyb:
	rol	$4, %eax
	mov	%al, %bl
	and	$0x0F, %ebx
	mov	hex(%ebx), %dl
	mov	%dl, (%edi)
	inc	%edi
	loop	nxnyb

	popal
	ret



show_stack:
	push	%ebp
	mov	%esp, %ebp

	pushal
	pushl	$0
	mov	%ds, (%esp)
	pushl	$0
	mov	%es, (%esp)

	mov	$sel_ss, %ax
	mov	%ax, %ds

	mov	$sel_es, %ax
	mov	%ax, %es

	xor	%ebx, %ebx
nxelt:	
	mov	-40(%ebp, %ebx, 4), %eax
	lea	buf+1, %edi
	call	eax2hex

	imul	$160, %ebx, %edi
	add	$240, %edi

	lea	buf, %esi
	cld
	mov	$10, %ecx
	mov	$0x70, %ah
nxpel:
	lodsb
	stosw
	loop	nxpel	

	inc	%ebx
	cmp	$22, %ebx
	jb	nxelt


freeze:	jmp	freeze

	pop	%es
	pop	%ds
	popal
	ret
	
	.align	16
theTSS:	.space	0x168			# 32bit Task-State Segment 
	.end				# no more to be assembled
