//----------------------------------------------------------------
//	memsize.s
//
//	This boot-sector program demonstrates use of the ROM-BIOS
//	'Get Memory Size' service (int 0x12) in order to find out 
//	the upper limit on memory available for use in real-mode.
//
//	 assemble with:  $ as memsize.s -o memsize.o
//	 and link with:  $ ld memsize.o -T ldscript -o memsize.b
//
//	NOTE: This code begins executing with CS:IP = 0000:7C00.
//
//	programmer: ALLAN CRUSE
//	written on: 28 JAN 2004
//	revised on: 23 AUG 2006 -- using the GNU assembler syntax
//----------------------------------------------------------------

	.code16				# for Pentium 'real mode'

	.section	.text
#-----------------------------------------------------------------
start:	ljmp	$0x07C0, $main		# renormalize CS and IP
#-----------------------------------------------------------------
msg:	.ascii	"\n\r Real-Mode Memory: "	# message legend
buf:	.ascii	"    0 KB \n\r"			# info to report
len:	.word	. - msg				# message length
ten:	.word	10			# decimal-system's radix
#-----------------------------------------------------------------
main:	# setup segment-registers to address our program data

	mov	%cs, %ax		# address thus segment
	mov	%ax, %ds		#   with DS register
	mov	%ax, %es		#   also ES register

	# invoke ROM-BIOS service to obtain memory-size (in KB)

	int	$0x12			# get ram's size into AX

	# use repeated division by ten to convert the binary value 
	# in AX into a decimal digit-string, without leading zeros

	mov	$5, %di			# initialize array-index
nxdgt:	
	xor	%dx, %dx		# extend AX for division
	divw	ten			# divide by decimal-base
	add	$'0', %dl		# change number to ascii
	dec	%di			# move index to the left  
	mov	%dl, buf(%di)		# and store that numeral
	or	%ax, %ax		# did quotient equal 0?
	jnz	nxdgt			# no, get another digit

	# invoke ROM-BIOS video services to display our message

	mov	$0x0F, %ah		# get video-page into BH
	int	$0x10			# request VIDEO service

	mov	$0x03, %ah 		# cursor (row,col) to DX
	int	$0x10			# request VIDEO service

	lea	msg, %bp 		# point ES:DP to string
	mov	len, %cx		# setup CX with length
	mov	$0x0D, %bl		# setup BL with colors
	mov	$0x1301, %ax		# specify write_string
	int	$0x10			# request VIDEO service

freeze:	jmp	freeze			# spin here until reboot
#-----------------------------------------------------------------
	.org	510			# boot-signature's offset
	.byte	0x55, 0xAA		# value of boot-signature
#-----------------------------------------------------------------
	.end				# nothing more to assemble
