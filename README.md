# Lunaviel Core Kernel

## Overview
Lunaviel Core is a modern microkernel operating system designed for the HP ProBook 450 G9 hardware platform. It combines the reliability of Forth with the structure of Oberon-07 and the flexibility of Common Lisp to create a unique system architecture.

## Architecture
The system is built with three primary components:
1. **Gforth Core**: Bootloader and low-level system management
2. **OBNC Drivers**: Hardware abstraction and device management
3. **SBCL Userland**: High-level system interface and applications

## System Requirements
- HP ProBook 450 G9 or compatible hardware
- 12th Gen Intel Core i3-1215U processor or better
- Minimum 8GB RAM
- NVMe SSD storage

## Building and Installation
### Prerequisites
- Gforth 0.7.3 or later
- OBNC compiler
- SBCL (Steel Bank Common Lisp)
- Standard build tools (make, gcc, etc.)

### Build Instructions
1. Clone the repository:
   ```bash
   git clone https://github.com/veridianzenith/lunaviel.git
   cd lunaviel
   ```

2. Build the core components:
   ```bash
   make core
   ```

3. Build the drivers:
   ```bash
   make drivers
   ```

4. Build the userland components:
   ```bash
   make userland
   ```

5. Create a bootable image:
   ```bash
   make image
   ```

## Project Structure
```
lunaviel/
├── src/
│   ├── core/          # Gforth core components
│   ├── drivers/       # OBNC device drivers
│   ├── fs/            # Filesystem implementation
│   └── user/          # SBCL userland components
├── docs/              # Documentation
├── tools/             # Build tools
└── README.md           # This file
```

## License
Lunaviel Core is dual-licensed under AGPLv3 and the Veridian Commercial License (VCL 1.0). See LICENSE file for details.

## Contributing
Contributions are welcome! Please follow these guidelines:
1. All code must be licensed under AGPLv3
2. Follow the existing code style and architecture
3. Submit pull requests with clear descriptions of changes

## Contact
For more information or commercial licensing inquiries, please contact:
Dae Euhwa - dae@veridianzenith.com
