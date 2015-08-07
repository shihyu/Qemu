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
//      modifiedby: falcon <wuzhangjin@gmail.com>, 2008-09-16
//-----------------------------------------------------------------

	.code16
	.text
#------------------------------------------------------------------
	ljmp	$0x07C0, $main		# re-normalize CS and IP
#------------------------------------------------------------------
main:	# setup segment-registers to address our program data	
	mov	%cs, %ax
	mov	%ax, %ds
	mov	%ax, %es

	# transfer sectors from disk to memory
	mov     $0x1000, %ax
	mov     %ax, %es
	mov     $0, %bx
        mov     $1, %ax
	mov     $2879, %cl
	call    ReadSector

	# verify that our program's signature-word is present
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
	
    /* ==================================================================
       Routine: ReadSector
       Action: Read %cl Sectors from %ax sector(floppy) to %es:%bx(memory)
         Assume sector number is ’x’, then:
            x/(BPB_SecPerTrk) = y,
            x%(BPB_SecPerTrk) = z.
         The remainder ’z’ PLUS 1 is the start sector number;
         The quotient ’y’ devide by BPB_NumHeads(RIGHT SHIFT 1 bit)is cylinder
            number;
         AND ’y’ by 1 can got magnetic header.
    */
    ReadSector:
        push     %ebp
        mov      %esp,%ebp
        sub      $2,%esp        /* Reserve space for saving %cl */
        mov      %cl,-2(%ebp)
        push     %bx            /* Save bx */
        mov      $18, %bl     /* %bl: the devider */
        div      %bl            /* ’y’ in %al, ’z’ in %ah */
        inc      %ah            /* z++, got start sector */
        mov      %ah,%cl        /* %cl <- start sector number */
        mov      %al,%dh        /* %dh <- ’y’ */
        shr      $1,%al         /* ’y’/BPB_NumHeads */
        mov      %al,%ch        /* %ch <- Cylinder number(y>>1) */
        and      $1,%dh         /* %dh <- Magnetic header(y&1) */
        pop      %bx            /* Restore %bx */
        /* Now, we got cylinder number in %ch, start sector number in %cl, magnetic
            header in %dh. */
        mov      $0, %dl
    GoOnReading:
        mov      $2,%ah
        mov      -2(%ebp),%al     /* Read %al sectors */
        int      $0x13
        jc       GoOnReading      /* If CF set 1, mean read error, reread. */
        add      $2,%esp
        pop      %ebp
        ret

	.org	510
	.byte	0x55, 0xAA
	.end
