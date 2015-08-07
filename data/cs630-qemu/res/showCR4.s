//-----------------------------------------------------------------
//	showCR4.s		 (for Midterm Exam II, Question V)
//
//	Here is one possible solution to Question V on Midtern II.
//	It is a boot-sector replacement that displays the contents
//	at startup of Control Register CR4 in hexadecimal format.
//
//	  to assemble: $ as showCR4.s -o showCR4.o
//	  and to link: $ ld showCR4.o -T ldscript -o showCR4.b
//	  and install: $ dd if=showCR4.b of=/dev/sda4 
//
//	NOTE: This code begins executing with CS:IP = 0000:7C00.
//
//	programmer: ALLAN CRUSE
//	written on: 12 NOV 2006
//-----------------------------------------------------------------

	.code16				# for Pentium 'real-mode'

	.section	.text
#------------------------------------------------------------------
	ljmp	$0x07C0, $main
#------------------------------------------------------------------
hex:	.ascii	"0123456789ABCDEF"
msg:	.ascii	"\r\n     CR4="
buf:	.ascii	"xxxxxxxx \r\n"
len:	.word	. - msg
hue:	.byte	0x0E
#------------------------------------------------------------------
main:	# setup a stack (so we can use 'call/ret/push/pop/int')
	xor	%ax, %ax		# address bottom 64K ram
	mov	%ax, %ss		#  with the SS register
	mov	$0x7C00, %sp		# establish top-of-stack

	# setup registers DS and ES for accessing program's data
	mov	%cs, %ax		# address our variables
	mov	%ax, %ds		#   using DS register
	mov	%ax, %es		#    and ES register

	# format the contents of register CR4 as a digit-string
	mov	%cr4, %eax		# copy CR4 into EAX
	lea	buf, %di		# point DS:DI to buffer
	call	eax2hex			# convert to hex string

	# use ROM-BIOS functions to draw message on the screen
	mov	$0x0F, %ah		# page_number into BH
	int	$0x10			# invoke BIOS service
	mov	$0x03, %ah		# cursor-posn to DH,DL
	int	$0x10			# invoke BIOS service
	lea	msg, %bp		# point ES:BP to msg
	mov	len, %cx		# setup CX with length
	mov	hue, %bl		# setup BL with colors
	mov	$0x1301, %ax		# write_string function
	int	$0x10			# invoke BIOS service

	# await user's keypress before rebooting
	mov	$0x00, %ah		# get_keyboard_input
	int	$0x16			# invoke BIOS service
	int	$0x19			# then reboot machine
#------------------------------------------------------------------
eax2hex:  # converts EAX to a hexadecimal digit-string at DS:DI
	pusha				# preserve registers
	mov	$8, %cx			# generate 8 digits
nxnyb:
	rol	$4, %eax		# next nybble into AL
	mov	%al, %bl		# copy nybble into BL
	and	$0x0F, %bx		# isolate nybble bits
	mov	hex(%bx), %dl		# lookup ascii value
	mov	%dl, (%di)		# put char in buffer
	inc	%di			# advance buf index 
	loop	nxnyb			# do other nybbles
	popa				# restore registers
	ret				# go back to caller
#------------------------------------------------------------------
	.org	510			# boot-signature's offset
	.byte	0x55, 0xAA		# value of boot-signature
#------------------------------------------------------------------
	.end				# no more to be assembled

