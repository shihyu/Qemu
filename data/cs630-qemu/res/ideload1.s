//-----------------------------------------------------------------
//	ideload1.s
//
//	This example performs the same program loading service as 
//	our earlier 'quikload.s' demo, but it avoids relying on a 
//	ROM-BIOS (real-mode) software interrupt routine; instead,
//	it directly accesses the Fixed Disk Controller's hardware 
//	interface (as could also be done when in protected-mode). 
//
//	 to assemble: $ as ideload1.s -o ideload1.o
//	 and to link: $ ld ideload1.o -T ldscript -o ideload1.b
//
//	NOTE: This code begins executing with CS:IP = 0000:7C00.
//
//	programmer: ALLAN CRUSE
//	written on: 21 OCT 2006
//-----------------------------------------------------------------

	.include	"platform.inc"	# for hardware parameters
	.code16				# for Pentium 'real-mode'

	.section	.text
#------------------------------------------------------------------
start:	ljmp	$0x07C0, $main		# re-normalize CS and IP
#------------------------------------------------------------------
	.equ	IDE_DATA,	IDE_CMD_BLOCK+0
	.equ	IDE_FEATURES,	IDE_CMD_BLOCK+1
	.equ	IDE_ERROR,	IDE_CMD_BLOCK+1
	.equ	IDE_COUNT,	IDE_CMD_BLOCK+2
	.equ	IDE_LBA_LOW,	IDE_CMD_BLOCK+3
	.equ	IDE_LBA_MID,	IDE_CMD_BLOCK+4
	.equ	IDE_LBA_HIGH,	IDE_CMD_BLOCK+5
	.equ	IDE_DEVICE,	IDE_CMD_BLOCK+6
	.equ	IDE_STATUS,	IDE_CMD_BLOCK+7
	.equ	IDE_COMMAND,	IDE_CMD_BLOCK+7
	.equ	IDE_ALT_STATUS,	IDE_CTL_BLOCK+2
	.equ	IDE_CONTROL,	IDE_CTL_BLOCK+2
#------------------------------------------------------------------
main:	mov	%cs, %ax		# address our variables
	mov	%ax, %ds		#   using DS register

	call	device_selection 
	call	write_parameters
	call	initiate_command
	call	wait_for_results
	call	read_sector_data

	jmp	exec_application
#------------------------------------------------------------------
#------------------------------------------------------------------
ide_status:	.short	0		# for controller status
sector_lba:	.int	DISK_LBA	# location to read from
		.equ	NUM_BLOCKS, 16	# count sectors to read
#------------------------------------------------------------------
device_selection:

	# await controller-status: BSY==0 and DRQ==0  
	mov	$IDE_STATUS, %dx	# port-address into DX
	xor	%cx, %cx		# load timeout counter
spin1:	in	%dx, %al		# input current status
	test	$0x88, %al		# BSY==0 and DRQ==0?
	loopnz	spin1			# no, continue testing

	# write to Drive/Head register to select device 
	mov	$IDE_DEVICE, %dx	# port-address into DX
	mov	$0xE0, %al		# use LBA=1, Drive=0
	out	%al, %dx		# output to controller

	mov	$IDE_STATUS, %dx	# port-address into DX
	xor	%cx, %cx		# load timeout counter
spin2:	in	%dx, %al		# input current status
	test	$0x88, %al		# BSY==0 and DRQ==0?	
	loopnz	spin2			# no, continue testing
	
	ret
#------------------------------------------------------------------
write_parameters:

	mov	$IDE_COUNT, %dx		# port for Sector-Count 
	mov	$NUM_BLOCKS, %al	# how many disk-sectors 
	out	%al, %dx		# output register-value

	mov	$IDE_LBA_LOW, %dx	# port for LBA[7..0]  
	mov	sector_lba+0, %al	# value of low byte
	out	%al, %dx		# output register-value

	mov	$IDE_LBA_MID, %dx	# port for LBA[15..8]
	mov	sector_lba+1, %al	# value of mid byte
	out	%al, %dx		# output register-value

	mov	$IDE_LBA_HIGH, %dx	# port for LBA[23..16]
	mov	sector_lba+2, %al	# value of high byte
	out	%al, %dx		# output register-value

	mov	$IDE_DEVICE, %dx	# port for LBA[27..24]
	mov	sector_lba+3, %al	# value of high nybble
	and	$0x0F, %al		# isolate nybble bits
	or	$0xE0, %al		# specify LBA, Drive 0
	out	%al, %dx		# output register-value

	ret
#------------------------------------------------------------------
initiate_command:

	mov	$IDE_COMMAND, %dx	# port for command byte
	mov	$0x20, %al		# 'Read Sector' command
	out	%al, %dx		# output register-value
	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
wait_for_results:

	xor	%ax, %ax		# clear the accumulator
	mov	$IDE_ALT_STATUS, %dx	# alternate status port
	xor	%cx, %cx		# setup timeout counter
spin3:	in	%dx, %al		# input current status
	test	$0x80, %al		# check: BSY==1?
	loopnz	spin3			# yes, continue checking
	test	$0x08, %al		# check: DRQ==0?
	loopz	spin3			# no, continue checking

	test	$0x01, %al		# any errors indicated?
	jz	noerr			# no, transfer the data

	mov	$IDE_ERROR, %dx		# else select error-port 
	in	%dx, %al		# input error settings
	shl	$8, %ax			# and shift them to AH  
noerr:
	mov	$IDE_STATUS, %dx	# select status port
	in	%dx, %al		# and clear interrupt
	mov	%ax, ide_status		# save status w/error

	ret
#------------------------------------------------------------------
read_sector_data:

	testw	$0xFF01, ide_status	# any errors recorded?
	jnz	failed			# yes, don't take risk

	mov	$0x1000, %ax		# address program arena
	mov	%ax, %es		#   using ES register
	xor	%di, %di		# point ES:DI to region
	cld				# do forward processing

	mov	NUM_BLOCKS, %bp		# setup a loop counter
nxblk:	
	mov	$IDE_DATA, %dx		# port-address for data
	mov	$256, %cx		# CX = words-per-sector
	rep	insw			# input data into arena

	mov	$IDE_STATUS, %dx
spin6:	in	%dx, %al
	test	$0x80, %al
	loopnz	spin6
	test	$0x08, %al
	jnz	nxblk	

failed:	ret
#------------------------------------------------------------------
exec_application:

	# check signature for validity of the program
	mov	$0x1000, %ax		# address program arena
	mov	%ax, %es		#   using ES register
	cmpw	$0xABCD, %es:0		# first word is 0xABCD?
	jne	skip			# no, bypass execution

	lcall	$0x1000, $0x0002	# far call to program
skip:
	mov	$0x00, %ah		# await_keypress function
	int	$0x16			# request BIOS service
	int	$0x19			# reboot the workstation
#------------------------------------------------------------------
	.org	510			# offset to boot-signature
	.byte	0x55, 0xAA		# value for boot-signature
#------------------------------------------------------------------
	.end				# nothing else to assemble
