## Boot Stages
1. `boot.fth` runs from UEFI, prints diagnostics
2. Includes `paging.fth` and sets up virtual memory
3. In future: dynamically load OBNC modules
4. Transfer control to `init.lisp` for system bring-up
