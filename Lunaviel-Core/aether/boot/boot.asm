; Multiboot header constants
MULTIBOOT_MAGIC        equ 0x1BADB002
MULTIBOOT_FLAGS        equ 0x00000003  ; Align modules and provide memory map
MULTIBOOT_CHECKSUM     equ -(MULTIBOOT_MAGIC + MULTIBOOT_FLAGS)

; Kernel stack size (16KB)
KERNEL_STACK_SIZE      equ 16384

section .multiboot
align 4
    dd MULTIBOOT_MAGIC
    dd MULTIBOOT_FLAGS
    dd MULTIBOOT_CHECKSUM

section .bss
align 16
kernel_stack:
    resb KERNEL_STACK_SIZE
kernel_stack_top:

section .text
global _start
extern kmain

_start:
    ; Set up kernel stack
    mov esp, kernel_stack_top

    ; Push multiboot info
    push ebx    ; Multiboot information structure
    push eax    ; Multiboot magic value

    ; Initialize processor state
    cli                     ; Disable interrupts
    cld                     ; Clear direction flag

    ; Enable PAE (Physical Address Extension)
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; Set up long mode page tables
    ; PML4
    mov eax, pd_table
    or eax, 0b11           ; Present + Writable
    mov [pml4_table], eax

    ; Setup identity mapping for first 2MB
    mov eax, 0x83         ; Present + Writable + Huge
    mov [pd_table], eax

    ; Load PML4 into CR3
    mov eax, pml4_table
    mov cr3, eax

    ; Enable long mode
    mov ecx, 0xC0000080   ; EFER MSR
    rdmsr
    or eax, 1 << 8        ; Set LME bit
    wrmsr

    ; Enable paging
    mov eax, cr0
    or eax, 1 << 31       ; Set PG bit
    mov cr0, eax

    ; Load GDT for long mode
    lgdt [gdt64.pointer]

    ; Jump to long mode
    jmp gdt64.code:long_mode_start

section .data
align 4096
pml4_table:
    times 512 dq 0
pd_table:
    times 512 dq 0

section .rodata
gdt64:
    dq 0                          ; Zero entry
.code: equ $ - gdt64
    dq (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53) ; Code segment
.pointer:
    dw $ - gdt64 - 1             ; GDT size
    dq gdt64                     ; GDT address

section .text
bits 64
long_mode_start:
    ; Update segment registers
    mov ax, 0
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; Call kernel main
    call kmain

    ; If kernel returns, halt
.halt:
    cli
    hlt
    jmp .halt
