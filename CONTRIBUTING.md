# Contributing to Lunaviel Core

First off, thank you for considering contributing to Lunaviel Core! It's people like you that help make Lunaviel Core an innovative and cutting-edge operating system kernel.

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the issue list as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

* Use a clear and descriptive title
* Describe the exact steps which reproduce the problem
* Provide specific examples to demonstrate the steps
* Describe the behavior you observed after following the steps
* Explain which behavior you expected to see instead and why
* Include wave patterns and resonance data if relevant
* Include system specifications (CPU, memory, etc.)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* Use a clear and descriptive title
* Provide a step-by-step description of the suggested enhancement
* Provide specific examples to demonstrate the steps
* Describe the current behavior and explain which behavior you expected to see instead
* Explain why this enhancement would be useful
* Include wave harmonization impact analysis if applicable

### Pull Requests

* Fill in the required template
* Do not include issue numbers in the PR title
* Follow our coding style
* Include appropriate test cases
* Document new code based on our documentation styleguide
* End all files with a newline
* Avoid platform-dependent code
* Consider wave harmonization impacts

## Styleguides

### Git Commit Messages

* Use the present tense ("Add feature" not "Added feature")
* Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
* Limit the first line to 72 characters or less
* Reference issues and pull requests liberally after the first line
* Consider starting the commit message with an applicable emoji:
    * 🌊 when improving wave harmonization
    * ⚡️ when improving performance
    * 🔒 when dealing with security
    * 📝 when writing docs
    * 🐛 when fixing a bug
    * 🔥 when removing code or files

### Zig Styleguide

* Use 4 spaces for indentation
* Keep lines under 100 characters
* Document public functions and types
* Include wave harmonization comments where relevant
* Follow Zig standard library conventions
* Use meaningful variable names
* Optimize for readability

### Documentation Styleguide

* Use Markdown for documentation
* Document all public interfaces
* Include wave harmonization details
* Provide examples where appropriate
* Keep technical accuracy
* Update relevant diagrams
* Document error conditions

## Development Process

1. Fork the repo
2. Create a branch from `main`
3. Make your changes
4. Run tests
5. Update documentation
6. Submit PR

### Setting Up Development Environment

```fish
# Clone your fork
git clone git@github.com:username/Lunaviel.git

# Add upstream remote
git remote add upstream git@github.com:Veridian-Zenith/Lunaviel.git

# Install dependencies
./scripts/setup.fish

# Create branch
git checkout -b feature-name
```

### Testing

```fish
# Run all tests
./scripts/test.fish

# Run specific test suite
./scripts/test.fish memoria
```

### Wave Harmonization Testing

When making changes that affect system wave patterns:

1. Run wave analysis tools
2. Document resonance patterns
3. Test under various loads
4. Verify cache behavior
5. Check power efficiency

## Project Structure

```
Lunaviel/
├── CONTRIBUTING.md
├── LICENSE
├── README.md
├── extra/
│   └── specs.txt
├── scripts/
│   └── build.fish
└── Lunaviel-Core/
    ├── aether/       # Boot and initialization
    ├── astral/       # System interface
    ├── docs/         # Documentation
    ├── memoria/      # Memory management
    ├── scripts/      # Build and test scripts
    ├── seer/         # Monitoring
    ├── src/          # Core source
    │   ├── drivers/  # Driver framework
    │   └── kernel/   # Kernel core
    └── sylph/        # Task management
```

## Wave Harmonization Guidelines

When working with wave-harmonized components:

1. Consider resonance impacts
2. Test wave patterns
3. Document flow changes
4. Optimize cache usage
5. Monitor power impact

## Resources

* [Development Guide](Lunaviel-Core/docs/development.md)
* [Architecture Overview](Lunaviel-Core/docs/architecture.md)
* [Wave Harmonization Principles](Lunaviel-Core/docs/waves.md)
* [Testing Guide](Lunaviel-Core/docs/testing.md)
* [Documentation Guide](Lunaviel-Core/docs/documentation.md)

## Questions?

Feel free to:

* [Join our Discord](https://discord.gg/lunaviel)
* [Post on our Forum](https://forum.lunaviel.org)
* [Email the team](team@lunaviel.org)

Thank you for contributing to Lunaviel Core!
