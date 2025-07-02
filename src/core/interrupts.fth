\ Lunaviel Core Interrupt Handling
\ Copyright (c) 2025 Veridian Zenith
\ License: AGPLv3 or Veridian Commercial License

\ Interrupt controller constants
$20 constant PIC1-COMMAND
$21 constant PIC1-DATA
$A0 constant PIC2-COMMAND
$A1 constant PIC2-DATA
$08 constant IRQ0-VECTOR

\ Interrupt handler structure
begin-structure interrupt-handler
    field: handler-address
    field: handler-data
end-structure

\ Interrupt handlers table
create interrupt-table 256 cells allot

\ Initialize interrupt controller
: init-pic ( -- )
    \ Initialize master PIC
    $11 PIC1-COMMAND outb
    $20 PIC1-DATA outb
    $04 PIC1-DATA outb
    $01 PIC1-DATA outb

    \ Initialize slave PIC
    $11 PIC2-COMMAND outb
    $28 PIC2-DATA outb
    $02 PIC2-DATA outb
    $01 PIC2-DATA outb ;

\ Register interrupt handler
: register-handler ( vector handler data -- )
    cells interrupt-table + ! ;

\ Default interrupt handler
: default-handler ( -- )
    ." Unhandled interrupt" ;

\ Initialize interrupt handlers
: init-handlers ( -- )
    256 0 ?do
        ['] default-handler i register-handler
    loop ;

\ Enable hardware interrupts
: enable-interrupts ( -- )
    $FB in-al, $21 out-al, ;

\ Initialize interrupt system
: init-interrupts ( -- )
    init-pic
    init-handlers
    enable-interrupts ;

\ Start interrupt system
init-interrupts
