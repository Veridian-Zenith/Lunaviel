ENTRY(efi_main)
SECTIONS {
  . = 0x100000;
  .text : { *(.text .text.*) }
  .rodata : { *(.rodata .rodata.*) }
  .data : { *(.data .data.*) }
  .bss : { *(COMMON) *(.bss .bss.*) }
  /DISCARD/ : { *(.eh_frame) *(.note .note.*) }
}
