//-----------------------------------------------------------------
//	ideload2.s
//
//	This example performs the same program loading service as 
//	our earlier 'quikload.s' demo, but it avoids relying on a 
//	ROM-BIOS (real-mode) software interrupt routine; instead,
//	it directly accesses the Fixed Disk Controller's hardware 
//	interface (as could also be done when in protected-mode). 
//	Note that the Disk Controller's Bus Master DMA capability 
//	is used to transfer sector-data directly from the disk to 
//	system memory without requiring the cpu to be involved. 
//
//	 to assemble: $ as ideload2.s -o ideload2.o
//	 and to link: $ ld ideload2.o -T ldscrip2 -o ideload2.b
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
	.equ	DMA_COMMAND, 	DMA_CTL_BLOCK+0
	.equ	DMA_STATUS,	DMA_CTL_BLOCK+2
	.equ	DMA_POINTER,	DMA_CTL_BLOCK+4
#------------------------------------------------------------------
ide_status:	.short	0		# for controller status
dma_status:	.byte	0		# for DMA-engine status
sector_lba:	.int	DISK_LBA	# location to read from
		.equ	NUM_BLOCKS, 16	# count sectors to read
#------------------------------------------------------------------
		.align	8
prd_table:	.int	0x00010000	# physical region start
		.short	NUM_BLOCKS*512	# holds sixteen sectors 
		.short	0x8000		# EOT-bit for interrupt  
#------------------------------------------------------------------
main:	mov	%cs, %ax		# address our variables
	mov	%ax, %ds		#   using DS register

	call	device_selection 
	call	setup_bus_master
	call	write_parameters
	call	initiate_command
	call	trigger_transfer
	call	await_completion
	call	check_for_errors
	jmp	exec_application
#------------------------------------------------------------------
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
	mov	$NUM_BLOCKS, %al	# read sixteen sectors
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
	mov	$0xC8, %al		# 'Read Sector DMA' cmd
	out	%al, %dx		# output register-value
	ret
#------------------------------------------------------------------
#------------------------------------------------------------------
check_for_errors:

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

	mov	$IDE_DATA, %dx		# port-address for data
	mov	$256, %cx		# CX = words-per-sector
	rep	insw			# input data into arena

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
setup_bus_master:

	# load address of the Physical Region Descriptor Table

	mov	$DMA_POINTER, %dx	# port for PRDT address
	mov	$prd_table+0x7C00, %eax	# value of PRDT address
	out	%eax, %dx		# output value to port

	# specify direction for the data-transfer (i.e., to memory)
	
	mov	$DMA_COMMAND, %dx	# port for the command
	mov	$0x08, %al		# set 'write-to-memory'
	out	%al, %dx		# output value to port

	# clear status interrupt-bit (bit 2) and error-bit (bit 1)

	mov	$DMA_STATUS, %dx	# port for DMA status
	in	%dx, %al		# input current value
	or	$0x06, %al		# set bits #2 and #1
	out	%al, %dx 		# output value to port

	ret
#------------------------------------------------------------------
trigger_transfer:

	# engage the Bus Master by writing '1' to command-bit 0 
	
	mov	$DMA_COMMAND, %dx	# port for DMA command
	in	%dx, %al		# use current direction
	or	$0x01, %al		# set 'activation' bit
	out	%al, %dx		# output value to port

	ret
#------------------------------------------------------------------
await_completion:

	# OK, the processor can spin while the DMA remains active

	mov	$100, %bp		# setup a timeout counter
spin7:
	mov	$DMA_STATUS, %dx	# port for DMA status
	in	%dx, %al		# read current setting
	test	$0x01, %al		# check: DMA is active?
	jz	cease			# no, we disengage DMA
	loopnz	spin7			# else continue spinning 
	dec	%bp			# decrement timeout
	jnz	spin7			# and continue spinning
cease:
	# stop the DMA function by writing '0' to command-bit 0

	mov	$DMA_COMMAND, %dx	# port for DMA command
	in	%dx, %al		# read current setting
	and	$0xFE, %al		# clear activation bit 
	out	%al, %dx		# output value to port

	# check DMA status for errors (and to clear interrupt)

	mov	$DMA_STATUS, %dx	# port for DMA status
	in	%dx, %al
	out	%al, %dx
	mov	%al, dma_status		# store DMA status

	ret
#------------------------------------------------------------------
	.org	510			# offset to boot-signature
	.byte	0x55, 0xAA		# value for boot-signature
#------------------------------------------------------------------
	.end				# nothing else to assemble
