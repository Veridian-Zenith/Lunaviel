\ ============================================================================
\ Lunaviel Core Kernel Bootloader Entry Point - src/core/boot.fth
\ ============================================================================
\ UEFI-Compatible Boot Sequence (Forth)
\ ============================================================================
\ Author: Dae Euhwa
\ License: AGPLv3 + VCL1.0
\ ============================================================================

\ ----------------------------------------------------------------------------
\ UEFI System Table Pointer (64-bit address)
\ This will be passed from the UEFI loader into our kernel.
2variable efi-system-table

\ ----------------------------------------------------------------------------
\ External Bindings (linked to OBNC modules)
\ `uefi_print_string` must be provided by src/core/UefiPrint.obn
\ Stack: ( c-addr u -- )
external uefi_print_string

\ ----------------------------------------------------------------------------
\ Print and logging helper words
\ `print` and `log` route ASCII strings through the UEFI output protocol
: print ( c-addr u -- ) uefi_print_string ;
: log   ( c-addr u -- ) print ;

\ ----------------------------------------------------------------------------
\ Entrypoint for UEFI bootloader
\ Receives EFI_SYSTEM_TABLE pointer from UEFI stub
: efi_main ( efi-table-addr -- )
  efi-system-table 2!                \ Store the pointer globally

  s" Lunaviel Core Kernel (UEFI Boot)..." log
  s" ===================================" log

  check-cpu
  setup-stack
  parse-memory-map
  handoff-runtime ;

\ ----------------------------------------------------------------------------
\ CPU Feature Check Stub
\ Placeholder for CPUID validation (x86_64 capability check)
: check-cpu ( -- )
  s" [boot] Checking CPU (stub)..." log ;

\ ----------------------------------------------------------------------------
\ Stack Setup (usually handled by UEFI)
\ Logs that stack is valid and does not reconfigure
: setup-stack ( -- )
  s" [boot] Stack OK (UEFI provided)." log ;

\ ----------------------------------------------------------------------------
\ EFI Memory Map Parsing (stub)
\ Will later populate memory map layout and usable regions
: parse-memory-map ( -- )
  s" [boot] Parsing EFI memory map (stub)..." log ;

\ ----------------------------------------------------------------------------
\ Transition to Kernel Runtime Logic
\ Loads and runs the core runtime module
: handoff-runtime ( -- )
  s" [boot] Handoff to runtime.fth..." log
  include runtime.fth ;

\ ----------------------------------------------------------------------------
\ Manual test harness (optional)
\ Comment this out unless testing without UEFI stub
\ here 0 efi_main
