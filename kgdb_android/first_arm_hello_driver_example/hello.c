#include <linux/init.h>
#include <linux/module.h> 
MODULE_LICENSE("Dual BSD/GPL");
static int hello_init(void)
{
    printk(KERN_ALERT "Hello, Tekkaman Ninja ！\n");
    return 0;
}
static void hello_exit(void)
{
    printk(KERN_ALERT "Goodbye, Tekkaman Ninja ！\n Love Linux !Love ARM ! Love KeKe !\n");
}
module_init(hello_init);
module_exit(hello_exit);
