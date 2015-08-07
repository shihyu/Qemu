//-----------------------------------------------------------------
//	platform.inc
//
//	programmer: ALLAN CRUSE
//	written on: 21 OCT 2006
//-----------------------------------------------------------------

	# EQUATES for some platform-specific hardware parameters
	# in Kudlick Classroom and CS Lab machines (Fall 2006)

	.equ	IDE_CMD_BLOCK, 0xFE00	# IDE command-block port
	.equ	IDE_CTL_BLOCK, 0xFE10	# IDE control-block port
	.equ	DMA_CTL_BLOCK, 0xFEA0	# DMA control-block port
	.equ	DISK_LBA,  0x0A3E6D4B	# Logical Block Address
	

