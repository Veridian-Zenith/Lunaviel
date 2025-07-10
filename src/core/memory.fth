\ ============================================================================
\ Lunaviel Core Memory Map Parser - src/core/memory.fth
\ ============================================================================
\ Interfaces with UEFI Boot Services to retrieve the memory map.
\ Extracts and counts usable memory for paging/heap allocation.
\ ============================================================================
\ Author: Dae Euhwa
\ License: AGPLv3 + VCL1.0
\ ============================================================================

\ ----------------------------------------------------------------------------
\ External UEFI print function (linked from UefiPrint.obn)
external uefi_print_string ( c-addr u -- )
: print ( c-addr u -- ) uefi_print_string ;
: log   ( c-addr u -- ) print ;

\ ----------------------------------------------------------------------------
\ Globals

\ EFI_SYSTEM_TABLE pointer (populated in boot.fth)
variable efi-system-table

\ UEFI memory descriptor structure (per UEFI Spec 2.10, §7.2)
\ Total size: 56 bytes (with 4-byte padding)
struct
  uint32_t Type
  uint32_t Pad
  uint64_t PhysicalStart
  uint64_t VirtualStart
  uint64_t NumberOfPages
  uint64_t Attribute
end-struct efi_memory_descriptor

\ Memory type constants (subset)
0  constant EfiReservedMemoryType
7  constant EfiConventionalMemory
11 constant EfiRuntimeServicesCode
12 constant EfiRuntimeServicesData
14 constant EfiLoaderData

\ Maximum descriptors we will track
1024 constant MAX_MEMORY_DESCRIPTORS

\ ----------------------------------------------------------------------------
\ Buffers & State

4096 constant MEMMAP_BUFFER_SIZE
create memmap-buffer MEMMAP_BUFFER_SIZE allot

variable memmap-size         \ in-out size of memmap-buffer
variable memmap-desc-size    \ descriptor size from EFI
variable memmap-key          \ key from GetMemoryMap
variable memmap-desc-count   \ total descriptor count
variable usable-region-count \ count of usable memory regions

\ ----------------------------------------------------------------------------
\ Initialization

: clear-memmap-vars ( -- )
  MEMMAP_BUFFER_SIZE memmap-size !
  0 memmap-desc-size !
  0 memmap-key !
  0 memmap-desc-count !
  0 usable-region-count !
;

\ ----------------------------------------------------------------------------
\ EFI BootServices struct pointer (offset 72 from EFI_SYSTEM_TABLE base)
: get-boot-services ( -- ptr )
  efi-system-table @ 72 + @ ;

\ ----------------------------------------------------------------------------
\ GetMemoryMap stub (to be replaced with OBNC wrapper later)
: get-memory-map ( -- success? )
  \ This will eventually be a real call:
  \ GetMemoryMap(
  \   INOUT size_t *MemoryMapSize,
  \   OUT   EFI_MEMORY_DESCRIPTOR *MemoryMap,
  \   OUT   UINTN *MapKey,
  \   OUT   size_t *DescriptorSize,
  \   OUT   UINT32 *DescriptorVersion
  \ )
  \ For now: mock descriptor size as 56 bytes (UEFI spec)
  56 memmap-desc-size !
  true ;

\ ----------------------------------------------------------------------------
\ Parse the memory map buffer into usable regions
: parse-memmap-descriptors ( -- )
  s" [mem] Parsing memory descriptors..." log

  memmap-desc-size @
  memmap-size @
  / dup memmap-desc-count !
  0
  ?do
    \ Calculate base address of descriptor i
    i memmap-desc-size @ * memmap-buffer +
    \ Read memory type
    dup @                             \ (addr type)

    dup EfiConventionalMemory = if
      \ Count usable region
      usable-region-count @ 1+ usable-region-count !
    then
    drop
  loop

  usable-region-count @ . ( -- print count )
  s" [mem] Usable memory regions counted." log ;

\ ----------------------------------------------------------------------------
\ Full memory map parse flow
: parse-memory-map ( -- )
  clear-memmap-vars
  s" [mem] Requesting EFI memory map..." log
  get-memory-map
  if
    parse-memmap-descriptors
  else
    s" [mem] Failed to get memory map!" log
  then ;
