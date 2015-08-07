//-----------------------------------------------------------------
//	whycrash.s
//
//	This program creates an exception-handler for any General
//	Protection Exceptions (Interrupt-0x0D) which will display
//	some diagnostic information (to aid us in determining the
//	cause of a system 'crash' that occurs in protected-mode).
//
//	 to assemble: $ whycrash.s -o whycrash.o
//	 and to link: $ ld whycrash.o -T ldscript -o whycrash.b
//
//	NOTE: This code begins executing with CS:IP = 1000:0002.
//
//	programmer: ALLAN CRUSE
//	written on: 02 MAR 2004
//	revised on: 23 SEP 2006 -- to use the GNU assembler syntax
//-----------------------------------------------------------------

	.code16				# for Pentium 'real-mode'

	.section	.text
#------------------------------------------------------------------
	.word	0xABCD			# programming 'signature'
#------------------------------------------------------------------
begin:	mov	%sp, %cs:exit_pointer+0		# save loader's SP
	mov	%ss, %cs:exit_pointer+2		# save loader's SS

	mov	%cs, %ax		# address program's data
	mov	%ax, %ss		#    with SS register
	lea	tos, %sp		# establish new stacktop

	call	build_interrupt_gate
	call	enter_protected_mode
	call	execute_fault13_demo
finis:	call	leave_protected_mode

	lss	%cs:exit_pointer, %sp	# recover loader's SS:SP
	lret				# and exit to the loader
#------------------------------------------------------------------
exit_pointer:	.word	0, 0		# for saving stack-address
#------------------------------------------------------------------
# EQUATES for our segment-selectors
	.equ	sel_es, 0x0008		# vram-segment selector
	.equ	sel_cs, 0x0010		# code-segment selector
	.equ	sel_ds, 0x0018		# data-segment selector
	.equ	sel_fs, 0x0020		# flat-segment selector
#------------------------------------------------------------------
	.align	8		# quadword-alignment is required
theGDT:	.word	0x0000, 0x0000, 0x0000, 0x0000	# null descriptor
	.word	0x0007, 0x8000, 0x920B, 0x0080	# vram descriptor
	.word	0xFFFF, 0x0000, 0x9A01, 0x0000	# code descriptor
	.word	0xFFFF, 0x0000, 0x9201, 0x0000	# data descriptor
	.word	0xFFFF, 0x0000, 0x9200, 0x008F	# flat descriptor
#------------------------------------------------------------------
theIDT:	.zero	256 * 8			# for 256 gate-descriptors
#------------------------------------------------------------------
#------------------------------------------------------------------
build_interrupt_gate:
	
	# setup gate-descriptor for General Protection Exceptions

	mov	%cs, %ax		# address the IDT array
	mov	%ax, %ds		#   using DS register
	mov	$0x0D, %ebx		# gate-number into EBX
	lea	theIDT(,%ebx,8), %di	# point DS:DI to entry

	movw	$isrGPF, 0(%di)		# loword of entry-point 
	movw	$sel_cs, 2(%di)		# code-segment selector
	movw	$0x8E00, 4(%di)		# gate-type=0xE (32-bit)
	movw	$0x0000, 6(%di)		# hiword of entry-point

	ret
#------------------------------------------------------------------
enter_protected_mode:

	cli				# no device interrupts
	mov	%cr0, %eax		# current machine status
	bts	$0, %eax		# set image of PE-bit 
	mov	%eax, %cr0		# turn on protection
	
	lgdt	%cs:regGDT		# establish the GDT
	lidt	%cs:regIDT		# establish the IDT

	mov	$sel_ds, %ax		# address program stack
	mov	%ax, %ss		#   using SS register
	ljmp	$sel_cs, $pm		# also reload CS and IP
pm:
	ret				# back to main procedure
#------------------------------------------------------------------
leave_protected_mode:
	
	mov	$sel_ds, %ax		# real-mode limit/rights
	mov	%ax, %ds		#   into DS register
	mov	%ax, %es		#   also ES register
	
	mov	$sel_fs, %ax		# put 4GB segment-limit 
	mov	%ax, %fs		#   into FS register
	mov	%ax, %gs		#   also GS register

	mov	%cr0, %eax		# get machine status
	btr	$0, %eax		# reset PE-bit image
	mov	%eax, %cr0		# turn off protection

	ljmp	$0x1000, $rm		# must reload CS and IP
rm:	mov	%cs, %ax		# address program stack
	mov	%ax, %ss		#   with real-mode SS 
	
	lidt	%cs:regIVT		# restore real-mode IVT
	sti				# device interrupts ok

	ret				# back to main procedure
#------------------------------------------------------------------
#------------------------------------------------------------------
regGDT:	.word	0x0027, theGDT, 0x0001	# image for register GDTR	
regIDT:	.word	0x07FF, theIDT, 0x0001	# image for register IDTR
regIVT:	.word	0x03FF, 0x0000, 0x0000	# image for register IDTR
#------------------------------------------------------------------
execute_fault13_demo:
	
	# here we try executing an impermissible instruction
	# in order to trigger the processor's entry into our
	# fault-handler for any General Protection Exception

	int	$0x10		# no gate exists for this ID

	ret			# Note: this is 'dead' code!
#------------------------------------------------------------------
isrGPF:  # Interrupt Service Routine for General Protection Faults
	pushal				# push the CPU registers
	pushl	%ds			
	pushl	%es			
	pushl	%fs
	pushl	%gs

	# the following loop draws each stack-element onscreen

	mov	$sel_es, %ax		# address video memory
	mov	%ax, %es		#   with ES register

	mov	$sel_ds, %ax		# address program data 
	mov	%ax, %ds		#   with DS register

	mov	%esp, %ebp		# copy stacktop to EBP
	xor	%edx, %edx		# start element-count
nxelt:
	call	draw_stack_element	# draw current element
	inc	%edx			# increment the count
	cmp	$ELTS, %edx		# all elements shown?
	jb	nxelt			# no, show another one

	jmp	finis			# jump to program exit
#------------------------------------------------------------------
eax2hex:  # converts value in EAX to hexadecimal string at DS:DI
	pusha				# preserve registers

	mov	$8, %cx			# number of nybbles
nxnyb:
	rol	$4, %eax		# next nybble into AL
	mov	%al, %bl		# copy nybble into BL
	and	$0xF, %bx		# isolate nybble bits
	mov	hex(%bx), %dl		# lookup nybble digit
	mov	%dl, (%di)		# put digit in buffer
	inc	%di			# advance buffer-index
	loop	nxnyb			# again if more nybbles 

	popa				# restore registers
	ret				# back to the caller
#------------------------------------------------------------------
#------------------------------------------------------------------
field:	.ascii	" GS= FS= ES= DS=EDI=ESI=EBP=ESP="
	.ascii	"EBX=EDX=ECX=EAX=err=EIP= CS=EFL="
	.equ	ELTS, ( . - field )/4	# number of stack elements
#------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"	# list of the hex numerals
buf:	.ascii	" nnn=xxxxxxxx "	# buffer for output-string
len:	.word	. - buf			# length for output-string
hue:	.byte	0x50			# colors: black-on-magenta
#------------------------------------------------------------------
draw_stack_element:  # the element-number is found in regster EDX

	mov	field(,%edx,4), %eax	# get the field's name 
	mov	%eax, buf+1		# put name into buffer

	mov	(%ebp,%edx,4), %eax	# get the field's value
	lea	buf+5, %di		# point DS:DI into buffer 
	call	eax2hex			# convert value to string

	mov	$ELTS, %eax		# total count of elements
	sub	%edx, %eax		# minus the number drawn
	imul	$160, %eax, %edi	# times size of screenrow  
	sub	$28, %edi		# minus size of outputmsg

	cld				# do forward processing
	lea	buf, %si		# point DS:SI to source
	mov	hue, %ah		# setup color-code in AH
	mov	len, %cx		# setup character-count
nxchr:	
	lodsb				# fetch next character
	stosw				# store char and color
	loop	nxchr			# again if other chars

	ret				# back to the caller
#------------------------------------------------------------------
	.align	16			# assures stack alignment
	.space	512, 0xFF		# initialize for this demo
tos:					# label for 'top-of-stack' 
#------------------------------------------------------------------
	.end				# nothing else to assemble
