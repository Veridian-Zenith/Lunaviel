\ ============================================================================
\ Lunaviel Core Paging Initialization - src/core/paging.fth
\ ============================================================================
\ Sets up 48-bit virtual memory paging with identity mapping for kernel space
\ Enables paging via inline CR register manipulation (x86_64)
\ ============================================================================
\ Author: Dae Euhwa
\ License: AGPLv3 + VCL1.0
\ ============================================================================

\ ----------------------------------------------------------------------------
\ External UEFI print bridge (linked from UefiPrint.obn)
\ Stack: ( c-addr u -- )
external uefi_print_string
: print ( c-addr u -- ) uefi_print_string ;
: log   ( c-addr u -- ) print ;

\ ----------------------------------------------------------------------------
\ Constants
4096       constant PAGE_SIZE

\ Page Table Entry Flags (x86_64 long mode)
$001       constant P_PRESENT
$002       constant P_WRITABLE
$080       constant P_PS         \ Page Size (2MiB)

\ ----------------------------------------------------------------------------
\ Allocate page-aligned memory for paging structures
create pml4-table PAGE_SIZE allot align
create pdpt-table PAGE_SIZE allot align
create pd-table  PAGE_SIZE allot align

\ ----------------------------------------------------------------------------
\ Inline Assembly Helpers — GCC-style for register access
\ NOTE: Requires Forth environment with `asm` capability

\ Load CR3 (page table base register)
: load-cr3 ( addr -- )
  \ Assumes address in RDI
  asm volatile (
    "mov %0, %%cr3"
    :
    : "r" (rdi)
    : "memory"
  ) ;

\ Read CR0 → ( -- val )
: read-cr0
  asm volatile (
    "mov %%cr0, %0"
    : "=r" (rax)
    :
    : "memory"
  ) ;

\ Write CR0 ← ( val -- )
: write-cr0
  asm volatile (
    "mov %0, %%cr0"
    :
    : "r" (rdi)
    : "memory"
  ) ;

\ Read CR4 → ( -- val )
: read-cr4
  asm volatile (
    "mov %%cr4, %0"
    : "=r" (rax)
    :
    : "memory"
  ) ;

\ Write CR4 ← ( val -- )
: write-cr4
  asm volatile (
    "mov %0, %%cr4"
    :
    : "r" (rdi)
    : "memory"
  ) ;

\ ----------------------------------------------------------------------------
\ Construct identity-mapped page tables
\ Identity-maps first 1GiB of physical memory using 2MiB pages
: setup-page-tables ( -- )
  s" [paging] Setting up page tables..." log

  \ Zero tables to start clean
  pml4-table PAGE_SIZE 0 fill
  pdpt-table PAGE_SIZE 0 fill
  pd-table  PAGE_SIZE 0 fill

  \ Fill Page Directory (PD) with 512 2MiB mappings
  512 0 do
    i 21 lshift                        \ base address = i * 2^21
    P_PRESENT or P_WRITABLE or P_PS or
    pd-table i cells + !
  loop

  \ PDPT[0] → PD
  pdpt-table 0 cells + pd-table
  P_PRESENT or P_WRITABLE or
  !

  \ PML4[0] → PDPT
  pml4-table 0 cells + pdpt-table
  P_PRESENT or P_WRITABLE or
  !

  s" [paging] Page tables setup complete." log ;

\ ----------------------------------------------------------------------------
\ Enable paging in CR registers
\ Activates 64-bit paging with PAE and PG bits
: enable-paging ( -- )
  \ Load CR3 with PML4 physical address
  pml4-table ptr>u64 load-cr3

  \ Enable PAE (bit 5 in CR4)
  read-cr4
  $20 or
  write-cr4

  \ Enable paging (bit 31 in CR0)
  read-cr0
  $80000000 or
  write-cr0

  s" [paging] Paging enabled." log ;

\ ----------------------------------------------------------------------------
\ Public Entry Point — to be called from runtime.fth
: load-paging ( -- )
  setup-page-tables
  enable-paging ;
