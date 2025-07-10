\ ============================================================================
\ Lunaviel Core Runtime Initialization - src/core/runtime.fth
\ ============================================================================
\ Prepares kernel-side runtime environment post-UEFI handoff
\ ============================================================================
\ Author: Dae Euhwa
\ License: AGPLv3 + VCL1.0
\ ============================================================================

\ ----------------------------------------------------------------------------
\ External print function from OBNC runtime
\ Linked from src/core/UefiPrint.obn
\ Stack: ( c-addr u -- )
external uefi_print_string

\ ----------------------------------------------------------------------------
\ Logging convenience
: print ( c-addr u -- ) uefi_print_string ;
: log   ( c-addr u -- ) print ;

\ ----------------------------------------------------------------------------
\ Main entry for runtime logic
\ Called at end of efi_main → handoff-runtime
\ Stack: ( -- )
: runtime-start
  s" === Runtime Initialization ===" log
  load-paging
  initialize-kheap
  setup-idt
  runtime-diagnostics
  enter-userland ;

\ ----------------------------------------------------------------------------
\ Paging Setup (stub)
\ Future implementation will map 1GiB identity, kernel higher half
\ Stack: ( -- )
: load-paging
  s" [paging] Initializing 48-bit virtual memory..." log
  s" [paging] Paging enabled (stub)." log ;

\ ----------------------------------------------------------------------------
\ Kernel Heap Initialization (stub)
\ Heap is required for drivers, subsystems, userland prep
\ Stack: ( -- )
: initialize-kheap
  s" [heap] Kernel heap init..." log
  s" [heap] Heap ready (stub)." log ;

\ ----------------------------------------------------------------------------
\ IDT / Interrupt Setup (stub)
\ Real setup will later configure APIC + syscall gates
\ Stack: ( -- )
: setup-idt
  s" [idt] Setting up interrupt table..." log
  s" [idt] IDT loaded (stub)." log ;

\ ----------------------------------------------------------------------------
\ Kernel Runtime Diagnostics (optional)
\ Useful for printing boot stats, memory regions, etc.
\ Stack: ( -- )
: runtime-diagnostics
  s" [diag] Runtime state OK." log ;

\ ----------------------------------------------------------------------------
\ Hand off control to userland Lisp init
\ Stack: ( -- )
: enter-userland
  s" [userland] Executing init.lisp..." log
  include ../user/init.lisp ;

\ ----------------------------------------------------------------------------
\ Automatically execute runtime sequence
\ This is triggered when included by boot.fth
runtime-start
