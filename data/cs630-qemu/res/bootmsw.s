//----------------------------------------------------------------
//	bootmsw.s
//
//	This program is designed as a boot-sector replacement for
//	a floppy diskette that has no important data-files on it.
//	It uses the unprivileged 'smsw' instruction to obtain the
//	current value from the Pentium's 16-bit MSW register, and
//	then displays that value in binary format to allow a user
//	to inspect the current setting of that register's PE-bit.
//
//	 assemble with:  $ as bootmsw.s -o bootmsw.o
//	 and link with:  $ ld bootmsw.o -T ldscript -o bootmsw.b
//	 install using:  $ dd if=bootmsw.b of=/dev/fd0
//
//	WARNING: This will ruin access to any files on DOS disks!
//
//	NOTE: This code begins executing with CS:IP = 0000:7C00.
//
//	programmer: ALLAN CRUSE
//	written on: 20 AUG 2006 
//----------------------------------------------------------------
	.code16				# for Pentium 'real-mode' 
	.section	.text
#-----------------------------------------------------------------
start:	ljmp	$0x07C0, $main		# renormalize CS and IP	
#-----------------------------------------------------------------
msg:	.ascii	"\r\n MSW="		# our messaage's legend
buf:	.ascii	"xxxxxxxxxxxxxxxx \r\n"	# our message's content
len:	.word	. - msg			# length of our message
#-----------------------------------------------------------------
main:	# setup segment-registers to address this segment's data

	mov	%cs, %ax		# address this segment
	mov	%ax, %ds		#   with DS register
	mov	%ax, %es		#   also ES register

	# get the current value from MSW (the Machine Status Word)

	smsw	%ax			# store current MSW to AX

	# format our message-string (expresing MSW in binary notation) 

	xor	%di, %di 		# initialize buffer-index
nxbit:	mov	$'0', %dl		# numeral '0' into DL 
	shl	$1, %ax			# next bit to carry-flag
	adc	$0, %dl 		# adjust numeral in DL
	mov	%dl, buf(%di)		# write numeral to buffer
	inc	%di			# advance buffer index
	cmp	$16, %di		# buffer-index equals 16?
	jne	nxbit			# no, process another bit

	# display our message at current page's cursor-location

	mov	$0x0F, %ah		# get curent video-page
	int	$0x10			# request BIOS service

	mov	$0x03, %ah		# get cursor's location
	int	$0x10			# request BIOS service

	lea	msg, %bp 		# point ES:BP to string
	mov	len, %cx		# message-length in CX
	mov	$0x0A, %bl		# bright green on black
	mov	$0x1301, %ax		# write_string to screen
	int	$0x10			# request BIOS service

	# now begin an infinite loop (until the machine reboots)

freeze:	jmp	freeze			# spin here until reboot
#-----------------------------------------------------------------
	.org	510			# boot-signature offset
	.byte	0x55, 0xAA		# and signature's value
#-----------------------------------------------------------------
	.end				# nothing else to assemble

