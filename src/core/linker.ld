ENTRY(efi_main)
SECTIONS {
    . = 0x200000;
    .text : { *(.text) }
    .data : { *(.data) }
    .rodata : { *(.rodata) }
    .bss : { *(.bss) }
    /DISCARD/ : { *(.eh_frame) }
}
