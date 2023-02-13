ENTRY(start)

SECTIONS
{
    . = 1M;

    .boot :
    {
        *(.multiboot)
    }

    .text :
    {
        *(.text)
    }
    /* Read-only data. */
	.rodata :
	{
		*(.rodata)
	}
 
	/* Read-write data (initialized) */
	.data :
	{
		*(.data)
	}
 
	/* Read-write data (uninitialized) and stack */
	.bss :
	{
		*(COMMON)
		*(.bss)
	}
}
