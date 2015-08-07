//-----------------------------------------------------------------
//	quikload.s
//
//	This is a 'quick-and-dirty' boot-loader that you can use
//	(or modify) for CS630's in-class exercises in Fall 2006. 
//
//	 to assemble: $ as quikload.s -o quikload.o
//	 and to link: $ ld quikload.o -T ldscript -o quikload.b
//	 and install: $ dd if=quikload.b of=/dev/sda4
//
//	NOTE: This code begins execution with CS:IP = 0000:7C00.
//
//	programmer: ALLAN CRUSE
//	written on: 12 SEP 2006
//-----------------------------------------------------------------

	.code16
	.text
#------------------------------------------------------------------
	ljmp	$0x07C0, $main		# re-normalize CS and IP
#------------------------------------------------------------------
packet:	.byte	16, 0, 16, 0		# packet-size, sector-count
	.word	0x0000, 0x1000		# memory-address for code
	.quad	0x0A3E6D4B		# LBA for starting sector
#------------------------------------------------------------------
main:	# setup segment-registers to address our program data	
	mov	%cs, %ax
	mov	%ax, %ds
	mov	%ax, %es

	# transfer sectors from disk to memory
	lea	packet, %si
	mov	$0x80, %dl
	mov	$0x42, %ah
	int	$0x13

	# verify that our program's signature-word is present
	les	packet+4, %bx
	cmpw	$0xABCD, %es:0
	jne	err

	# transfer control to our program's entry-point
	lcall	$0x1000, $0x0002

fin:	# await keypress, then reboot
	mov	$0x00, %ah
	int	$0x16
	int	$0x19

err:	# TODO: We ought to display an error-message here
	jmp	fin
	
	.org	510
	.byte	0x55, 0xAA
	.end


