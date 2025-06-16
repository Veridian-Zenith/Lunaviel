/* Kernel linker script */
OUTPUT_FORMAT(elf64-x86-64)
ENTRY(_start)

SECTIONS {
    /* Kernel is loaded at 1MB by Multiboot bootloader */
    . = 1M;

    .boot ALIGN(4K) : {
        KEEP(*(.multiboot))
    }

    .text ALIGN(4K) : {
        _code = .;
        *(.text)
        *(.text.*)
    }

    .rodata ALIGN(4K) : {
        _rodata = .;
        *(.rodata)
        *(.rodata.*)
    }

    .data ALIGN(4K) : {
        _data = .;
        *(.data)
        *(.data.*)
    }

    .bss ALIGN(4K) : {
        _bss = .;
        *(COMMON)
        *(.bss)
        *(.bss.*)
        _ebss = .;
    }

    /* Add segment for initial page tables */
    .pagetables ALIGN(4K) : {
        _pagetables = .;
        . += 3 * 4K;  /* Space for PML4, PDP, and PD */
    }

    /* Kernel end marker */
    _kernel_end = ALIGN(4K);

    /* Discard unnecessary sections */
    /DISCARD/ : {
        *(.eh_frame)
        *(.note.*)
        *(.comment)
    }
}
