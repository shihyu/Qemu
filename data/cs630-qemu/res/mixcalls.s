//-----------------------------------------------------------------
//	mixcalls.s
//
//	This program will illustrate a few 'calls' and 'returns'
//	between a 16-bit code-segment and a 32-bit code-segment.
//	(Messages are shown to confirm the transfers succeeded.)
//
//	  to assemble: $ as mixcalls.s -o mixcalls.o
//	  and to link: $ ld mixcalls.o -T ldscript -o mixcalls.b
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 30 OCT 2006
//-----------------------------------------------------------------


	.section	.text
#------------------------------------------------------------------
	.word	0xABCD
#------------------------------------------------------------------
#==================================================================
	.code16
#==================================================================
#------------------------------------------------------------------
main:	mov	%sp, %cs:exit_pointer+0	
	mov	%ss, %cs:exit_pointer+2	

	mov	%cs, %ax
	mov	%ax, %ds
	mov	%ax, %ss
	lea	tos, %sp

	call	enter_protected_mode
	call	execute_program_demo
	call	leave_protected_mode
	call	show_goodbye_message

	lss	%cs:exit_pointer, %sp
	lret
#------------------------------------------------------------------
exit_pointer:	.word	0, 0
#------------------------------------------------------------------
msg32:	.ascii	" Hello from 32-bit code-segment "
len32:	.long	. - msg32
hue32:	.byte	0x5F
#------------------------------------------------------------------
msg16:	.ascii	" Hello from 16-bit code-segment "
len16:	.short	. - msg16
hue16:	.byte	0x3F
#------------------------------------------------------------------
msgrm:	.ascii	" Goodbye from real-mode segment "
	.ascii	"\r\n\n"
lenrm:	.short	. - msgrm
huerm:	.byte	0x70
#------------------------------------------------------------------
#------------------------------------------------------------------
	.align	8
theGDT:	# Global Descriptors and the equates for their selectors
	.word	0x0000, 0x0000, 0x0000, 0x0000

	.equ	sel_es, (.-theGDT)+0
	.word	0x0007, 0x8000, 0x920B, 0x0080

	.equ	sel_cs, (.-theGDT)+0
	.word	0xFFFF, 0x0000, 0x9A01, 0x0000

	.equ	sel_ss, (.-theGDT)+0
	.word	0xFFFF, 0x0000, 0x9201, 0x0000

	.equ	sel_CS, (.-theGDT)+0
	.word	0xFFFF, 0x0000, 0x9A01, 0x0040

	.equ	sel_SS, (.-theGDT)+0
	.word	0xFFFF, 0x0000, 0x9201, 0x0040

	.equ	sel_fs, (.-theGDT)+0
	.word	0xFFFF, 0x0000, 0x9200, 0x008F

	.equ	gate32, (.-theGDT)+0
	.word	mywork, sel_CS, 0x8C00, 0x0000

	.equ	gate16, (.-theGDT)+0
	.word	nowork, sel_cs, 0x8400, 0x0000

	.equ	limGDT, (.-theGDT)-1
#------------------------------------------------------------------
regGDT:	.word	limGDT, theGDT, 0x0001
#------------------------------------------------------------------
execute_program_demo:

	# preserve the 16-bit stack's segment-selector and offset
	mov	%esp, tossave+0		# save caller's SS and ESP
	mov	%ss,  tossave+4		#  so we can later return  

	# switch to 32-bit stack and round for 32-bit alignment
	mov	$sel_SS, %ax		# 32-bit stack-selector 
	mov	%ax, %ss		#  goes in SS register
	and	$0xFFFC, %esp		# insure long alignment

	# call a 32-bit code-segment from a 16-bit code-segment
	lcall	$sel_CS, $hello32	# this pushes CS and IP

	# call a 32-bit code-segment through a 32-bit call-gate
	lcall	$gate32, $0		# this pushes CS and EIP

	# restore the 16-bit stack's segment-selector and offset
	lss	%cs:tossave, %esp	# restore saved SS and ESP 
	ret				# and return to the caller
#------------------------------------------------------------------
tossave:	.long	0, 0	
#------------------------------------------------------------------
#==================================================================
	.code32
#==================================================================
hello32:
	mov	$sel_es, %eax		# address video memory
	mov	%eax, %es		#   with ES register
	mov	$640, %edi		# point ES:EDI to row 4

	mov	$sel_SS, %eax		# address program data
	mov	%eax, %ds		#   with DS register
	lea	msg32, %esi		# point DS:ESI to msg32

	cld				# do forward processing
	mov	len32, %ecx		# ECX = character-count
	mov	hue32, %ah		# AH = color-attributes
.L32:
	lodsb				# fetch next character
	stosw				# store char and color
	loop	.L32			# again for more chars

	.byte	0x66	#<-- use an operand-size override prefix
	lret		# so that this 'lret' will pop CS and IP
#------------------------------------------------------------------
mywork:	# call a 16-bit code-segment from a 32-bit code-segment
	lcall	$sel_cs, $hello16	# this pushes CS and EIP

	# call a 16-bit code-segment through a 16-bit call-gate
	lcall	$gate16, $0		# this pushes CS and IP

	lret				# this pops CS and EIP
#------------------------------------------------------------------
#==================================================================
	.code16
#==================================================================
hello16:
	mov	$sel_es, %ax		# address video memory
	mov	%eax, %es		#   with ES register
	mov	$800, %di		# point ES:DI to row 5

	mov	$sel_ss, %ax		# address program data
	mov	%ax, %ds		#   with DS register
	lea	msg16, %si		# point DS:SI to msg16

	cld				# do forward processing
	mov	len16, %cx		# CX = character-count
	mov	hue16, %ah		# AH = color-attributes
.L16:
	lodsb				# fetch next character
	stosw				# store char and color
	loop	.L16			# again for more chars

	.byte	0x66	#<--- use an operand-size override prefix
	lret		# so that this 'lret' will pop CS and EIP
#------------------------------------------------------------------
nowork:	lret				# this pops CS and IP
#------------------------------------------------------------------
#------------------------------------------------------------------
enter_protected_mode:
	cli
	mov	%cr0, %eax
	bts	$0, %eax
	mov	%eax, %cr0
	lgdt	regGDT
	ljmp	$sel_cs, $pm
pm:	mov	$sel_ss, %ax
	mov	%ax, %ss
	mov	%ax, %ds
	mov	$sel_es, %ax
	mov	%ax, %es
	mov	$sel_fs, %ax
	mov	%ax, %fs
	mov	%ax, %gs
	ret
#------------------------------------------------------------------
leave_protected_mode:
	mov	$sel_ss, %ax
	mov	%ax, %ds
	mov	%ax, %es
	mov	%cr0, %eax
	btr	$0, %eax
	mov	%eax, %cr0
	ljmp	$0x1000, $rm
rm:	mov	%cs, %ax
	mov	%ax, %ss
	mov	%ax, %ds
	sti
	ret
#------------------------------------------------------------------
show_goodbye_message: 	
	mov	%cs, %ax
	mov	%ax, %ds
	mov	%ax, %es
	lea	msgrm, %bp
	mov	lenrm, %cx
	mov	huerm, %bl
	mov	$0, %bh
	mov	$6, %dh
	mov	$0, %dl
	mov	$0x1301, %ax
	int	$0x10
	ret
#------------------------------------------------------------------
	.align	16
	.space	512
tos:
#------------------------------------------------------------------
	.end

NOTE: Based on these examples of mixed 16-bit and 32-bit code, we 
infer a general rule: either the caller needs to use a call-gate,
or the callee needs an operand-size override prefix with 'lret'.
