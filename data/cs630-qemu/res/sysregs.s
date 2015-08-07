//-----------------------------------------------------------------
//	sysregs.s
//	
//	This boot-sector program displays current values from some
//	of the Pentium processor's most important system registers
//	(although two of these registers cannot be accessed unless
//	the processor is switched into 'Protected-Mode', and it is 
//	left as an exercise here for you to accomplish that feat).
//
//	 assemble using:  $ as sysregs.s -o sysregs.o
//	 and link using:  $ ld sysregs.o -T ldscript -o sysregs.b
//	
//	NOTE: This program begins executing with CS:IP = 0000:7C00.	
//	
//	programmer: ALLAN CRUSE
//	written on: 07 SEP 2006
//-----------------------------------------------------------------

	# manifest constant
	.equ	seg_boot, 0x07C0	# segment for BOOT_LOCN

	.code16				# for Pentium 'real-mode'

	.section	.text
#------------------------------------------------------------------
start:	ljmp	$seg_boot, $main	# re-normalize CS and IP
#------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"	# table of Base-16 digits
#------------------------------------------------------------------
idtr:	.space	6 			# room to store 48-bits
gdtr:	.space	6			# room to store 48-bits
ldtr:	.space	2			# room to store 16-bits
tr:	.space	2			# room to store 16-bits
cr0:	.space	4			# room to store 32-bits
#------------------------------------------------------------------
msg:	.ascii	"\r\n Values in some System Registers: \r\n\n"
	.ascii	" IDTR="		# text identifying field
_idtr:	.ascii	"xxxxxxxxxxxx "		# buffer for field-value
	.ascii	" GDTR="		# text identifying field
_gdtr:	.ascii	"xxxxxxxxxxxx "		# buffer for field-value
	.ascii	" LDTR="		# text identifying field
_ldtr:	.ascii	"xxxx "			# buffer for field-value
	.ascii	" TR="			# text identifying field
_tr:	.ascii	"xxxx "			# buffer for field-value
	.ascii	" CR0="			# text identifying field
_cr0:	.ascii	"xxxxxxxx "		# buffer for field-value
eoln:	.ascii	"\r\n\n"		# skip past a blank line 
len:	.word	. - msg			# number of message chars
hue:	.byte	0x0A			# bright green upon black
#------------------------------------------------------------------
main:	# setup segment-registers DS and ES to address our data

	mov	%cs, %ax		# address our variables
	mov	%ax, %ds		#   with DS register
	mov	%ax, %es		#   also ES register

	# store current contents of Control Regizter 0 
	mov	%cr0, %eax		# get the Machine Status
	mov	%eax, cr0		# assign value to memory

	# store current contents of registers IDTR and GDTR
	sidtl	idtr			# store register IDTR
	sgdtl	gdtr			# store register GDTR

	## sldt	ldtr		# <--- Illegal in 'real-mode'
	## str	tr		# <--- Illegal in 'real-mode'


	# format the register-value from IDTR
	lea	idtr, %si
	lea	_idtr, %di
	mov	$6, %cx
	call	bin2hex

	# format the register-value from GDTR
	lea	gdtr, %si
	lea	_gdtr, %di
	mov	$6, %cx
	call	bin2hex

	# format the register-value from CR0
	lea	cr0, %si
	lea	_cr0, %di
	mov	$4, %cx
	call	bin2hex

	# write the formatted message-string to the screen
	call	display_report

fini:	# await keypress, then reboot
	mov	$0x00, %ah		# get_keyboard_input
	int	$0x16			# request BIOS service
	int	$0x19			# then reboot machine
#------------------------------------------------------------------
bin2hex:  # converts CX-byte value at DS:SI to hex-string at DS:DI
	pusha
	add	%cx, %si	# point DS:SI past memory-value
nxpair:	
	dec	%si		# back up to next source-byte
	mov	(%si), %al	# load byte into AL register
	.rept	2		# (code-fragment occurs twice)
	rol	$4, %al		# rotate next nybble as lowest
	mov	%al, %bl	# copy resulting byte into BL
	and	$0x0F, %bx	# convery nybble-value to word
	mov	hex(%bx), %dl	# look up nybble's hex numeral
	mov	%dl, (%di)	# store numeral in output string
	inc	%di		# and advance the buffer pointer
	.endr			# (end of duplicated fragment)
	loop	nxpair		# again for any remaining bytes
	popa
	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
display_report:

	# get current page-number in BH
	mov	$0x0F, %ah		# get_video_status
	int	$0x10			# request BIOS service

	# get cursor (row, column) in DH, DL
	mov	$0x03, %ah		# get_cursor_position
	int	$0x10			# request BIOS service

	# transfer message-string to the screen
	mov	$0x13, %ah		# write_string function
	mov	$0x01, %al		# and update the cursor
	lea	msg, %bp		# point ES:BP to string
	mov	len, %cx		# string's length in CX
	mov	hue, %bl		# color attribute in BL
	int	$0x10			# request BIOS service

	ret
#------------------------------------------------------------------
	.org	510			# offset to signature-word 
	.byte	0x55, 0xAA		# value for boot-signature
#------------------------------------------------------------------
	.end				# no more to b e assembled

