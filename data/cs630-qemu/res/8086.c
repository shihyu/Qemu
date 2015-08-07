//----------------------------------------------------------------
//	8086.c				    (formerly 'dosio.c')
//
//	This character-mode Linux device-driver supports mapping
//	of the conventional MS-DOS memory areas into user space,
//	and it allows a client task to execute I/O instructions.
//
//	NOTE: Written and tested w/ Linux kernel version 2.6.12.
//
//	programmer: ALLAN CRUSE
//	written on: 13 AUG 2005
//	revised on: 23 JUL 2006 -- for kernel version 2.6.17.6
//----------------------------------------------------------------

#include <linux/module.h>	// for init_module()
#include <linux/fs.h>		// for file_operations
#include <linux/mm.h>		// for vm_area_struct
#include <asm/uaccess.h>	// for copy_to_user()
#include <asm/io.h>		// for phys_to_virt()

char modname[] = "8086";
int my_major = 86;
unsigned long mm_base = 0x000000000;
unsigned long mm_size = 0x000110000;


int my_open( struct inode *inode, struct file *file )
{
	struct thread_struct	*ts = &current->thread;

	ts->iopl = (3 << 12);
	set_iopl_mask( ts->iopl );
	return	0;
}


int my_mmap( struct file *file, struct vm_area_struct *vma )
{
	unsigned long	region_length = vma->vm_end - vma->vm_start;
	unsigned long	region_origin = vma->vm_pgoff * PAGE_SIZE;
	unsigned long	phys_address = mm_base + region_origin;
	unsigned long	virt_address = vma->vm_start;

	// sanity check: mapped region cannot extend beyond device 
	if ( region_origin + region_length > mm_size ) return -EINVAL;

	// let the kernel know not to try swapping out this region
	vma->vm_flags |= VM_RESERVED;

	// tell the kernel to exclude this region from core dumps
	vma->vm_flags |= VM_IO;

	if ( io_remap_pfn_range( vma, virt_address, phys_address>>PAGE_SHIFT,
		region_length, vma->vm_page_prot ) ) return -EAGAIN;

	return	0;  // SUCCESS
}


loff_t my_llseek( struct file *file, loff_t pos, int whence )
{
	loff_t	newpos = -1;
	
	switch ( whence )
		{
		case 0:	/* SEEK_SET */ 	newpos = pos; break;
		case 1:	/* SEEK_CUR */	newpos = file->f_pos + pos; break;
		case 2: /* SEEK_END */	newpos = mm_size + pos; break;
		}

	if (( newpos < 0 )||( newpos > mm_size )) return -EINVAL;
	file->f_pos = newpos;
	return	newpos; 
}

ssize_t my_read( struct file *file, char *buf, size_t len, loff_t *pos )
{
	void	*from = phys_to_virt( *pos );
	int	bytes = mm_size - *pos;

	// client may not read past the end of the DOS memory-area
	if ( bytes <= 0 ) return 0;

	// kernel must not copy more than the client has requested 
	if ( len < bytes ) bytes = len;

	// ok, some error occurs if not all these bytes get copied
	if ( copy_to_user( buf, from, bytes ) ) return -EFAULT;	

	// otherwise, advance file-pointer and report bytes copied
	*pos += bytes;
	return	bytes;
}


static struct file_operations 
my_fops =	{
		owner:		THIS_MODULE,
		llseek:		my_llseek,
		mmap:		my_mmap,
		open:		my_open,
		read:		my_read,
		};

int init_module( void )
{
	printk( "<1>\nInstalling \'%s\' module ", modname );
	printk( "(major=%d) \n", my_major );
	return	register_chrdev( my_major, modname, &my_fops );
}

void cleanup_module( void )
{
	unregister_chrdev( my_major, modname );
	printk( "<1>Removing \'%s\' module\n", modname );
}

MODULE_LICENSE( "GPL" );
