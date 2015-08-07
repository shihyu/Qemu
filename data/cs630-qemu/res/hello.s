//----------------------------------------------------------------
//	hello.s
//
//	This is just a test-program to invoke Linux system-calls.
//
//		assemble using:  $ as hello.s -o hello.o
//		and link using:  $ ld hello.o -o hello
//
//	programmer: ALLAN CRUSE
//	written on: 18 MAR 2004
//----------------------------------------------------------------

	.equ	sys_EXIT, 1		# ID-number for 'exit'
	.equ	sys_WRITE, 4		# ID-number for 'write'
	.equ	dev_STDOUT, 1		# ID-number for STDOUT


	.section	.data
msg:	.ascii	" Hello \n\r"		# contents of message
len:	.long	. - msg			# count of characters

	.section	.text
_start:	
	# write a message to the standard output device-file
	movl	$sys_WRITE, %eax	# system-call ID-number
	movl	$dev_STDOUT, %ebx	# device-file ID-number
	movl	$msg, %ecx		# message address
	movl	len, %edx		# message length
	int	$0x80			# enter the kernel
 
	# return control to the command-shell
	movl	$sys_EXIT, %eax		# system-call ID-number
	movl	$0, %ebx		# program's exit-status
	int	$0x80			# enter the kernel

	.global	_start			# entry-point is public

