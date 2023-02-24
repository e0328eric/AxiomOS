ENTRY(_start)

SECTIONS
{
    . = 1M;

    .text :
    {
        KEEP(*(.multiboot))
        *(.text .text.*)
    }
    /* Read-only data. */
	.rodata :
	{
		*(.rodata .rodata.*)
	}

	/* Read-write data (initialized) */
	.data :
	{
		*(.data)
	}

	.data.rel.ro :
	{
		*(.data.rel.ro.local*) *(data.rel.ro data.rel.ro.*)
	}

	/* Read-write data (uninitialized) and stack */
	.bss :
	{
		*(COMMON)
		*(.bss)
	}
}
