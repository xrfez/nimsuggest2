# nimsuggest2 Testing Framework

**Last Updated**: December 9, 2025

## Overview

Comprehensive testing suite for nimsuggest2 that:
1. Compares outputs with nimsuggest for compatibility
2. Tests all protocol commands with protocol v4
3. Tests both stdin and TCP modes
4. Benchmarks performance vs nimsuggest
5. Fuzzes with realistic IDE workloads

## Test Structure

```
tests/
├── TESTS.md                    # This file
├── README.md                   # Testing guide
├── config.nims                 # Test configuration
├── test_utils.nim              # Shared test utilities
├── test1.nim                   # Basic sanity tests
├── test_commands.nim           # Command output comparison tests
├── test_modes.nim              # stdin/TCP mode tests
├── test_passthrough.nim        # Passthrough command tests (NEW)
├── benchmarks.nim              # Performance benchmarks
├── fixtures/                   # Test source files
│   ├── basic.nim              # Basic Nim constructs
│   ├── advanced.nim           # Advanced features
│   ├── multimodule/           # Multi-file project
│   │   ├── main.nim
│   │   ├── module_a.nim
│   │   └── module_b.nim
│   └── stdlib_usage.nim       # Uses stdlib modules
└── results/                    # Test output comparison
```

## Test Coverage

### Commands Tested

#### Natively Implemented (11 commands)
- [x] `def` - Go to definition
- [x] `sug` - Autocomplete (known differences)
- [x] `use` - Find usages
- [x] `dus` - Definition + usages
- [x] `chk` - Check for errors
- [x] `chkFile` - Check single file
- [x] `highlight` - Highlight symbol
- [x] `outline` - Document outline
- [x] `known` - File known check
- [x] `project` - Get project file
- [x] `globalSymbols` - Global search

#### Passthrough to nimsuggest (7 commands)
- [x] `con` - Context-aware suggestions (requires type inference)
- [x] `mod` - Module info (requires semantic data)
- [x] `declaration` - Find declaration (requires semantic analysis)
- [x] `expand` - Macro expansion (requires macro engine)
- [x] `type` - Type at position (requires type checker)
- [x] `inlayHints` - Inlay hints (requires type inference)
- [x] `recompile` - Force recompile (semantic only)

#### Server Control (5 commands)
- [x] `quit` - Shutdown server
- [x] `debug` - Toggle debug logging
- [x] `terse` - Toggle terse output
- [x] `changed` - Mark file as changed
- [x] `status` - Server status

### Nim Constructs Tested
- [x] Procedures (proc, func, method, iterator)
- [x] Types (object, enum, distinct, ref, ptr)
- [x] Variables (var, let, const)
- [x] Generics (type parameters, constraints)
- [x] Templates and macros
- [x] Import statements (std/, relative, package)
- [x] Export statements
- [x] Pragmas and annotations
- [x] Operators and symbols
- [x] Nested modules and scopes
- [x] Documentation comments
- [x] String literals and escapes
- [x] Numeric literals
- [x] Comments (single/multi-line)

### Protocol Modes
- [x] stdin mode
- [x] TCP mode
- [x] Protocol v4
- [x] EPC mode (Emacs)

### Performance Benchmarks
- [x] Startup time
- [x] First query latency
- [x] Memory usage
- [x] Query response times (per command)
- [x] Cache hit rate
- [x] Large project indexing

## Running Tests

```bash
# Run all tests
nimble test

# Run specific test suite
nim c -r tests/test1.nim
nim c -r tests/test_commands.nim
nim c -r tests/test_modes.nim
nim c -r tests/test_passthrough.nim
nim c -r tests/benchmarks.nim

# Run benchmarks only
nimble benchmark

# Verbose test output
nim c -r -d:verbose tests/test_commands.nim
```

## Known Differences

### `sug` Command
nimsuggest2 uses token-based autocomplete with different ranking:
- May return more results (doesn't filter by semantic scope)
- Different quality scores (based on name matching)
- Faster but less context-aware

**Action**: Tests verify results are valid, not exact match

### Passthrough Commands
Commands that require semantic type info are delegated to nimsuggest:
- `con` - Context-aware suggestions
- `mod` - Module info
- `declaration` - Find declaration
- `expand` - Macro expansion
- `type` - Type at position
- `inlayHints` - Inlay type hints
- `recompile` - Force recompile

**Testing Strategy**:
1. Test that nimsuggest2 correctly forwards requests
2. Test that nimsuggest2 correctly returns responses
3. Verify --no-nimsuggest mode gracefully handles these commands
4. Compare passthrough vs direct nimsuggest for consistency

### endLine/endCol
nimsuggest2 uses token-based estimation:
- Usually accurate for outline
- May differ by a few columns for complex constructs

## Test Results Tracking

### Compatibility Score (vs nimsuggest)

| Command | Type | Exact Match % | Compatible % | Notes |
|---------|------|--------------|--------------|-------|
| **Native Commands** |
| def     | Native | TBD | TBD | Should be ~95%+ |
| sug     | Native | TBD | TBD | Known differences |
| use     | Native | TBD | TBD | Should be ~90%+ |
| outline | Native | TBD | TBD | Should be ~95%+ |
| chk     | Native | TBD | TBD | Delegates to nim check |
| **Passthrough Commands** |
| con     | Passthrough | TBD | TBD | Should match nimsuggest |
| type    | Passthrough | TBD | TBD | Should match nimsuggest |
| mod     | Passthrough | TBD | TBD | Should match nimsuggest |
| expand  | Passthrough | TBD | TBD | Should match nimsuggest |
| declaration | Passthrough | TBD | TBD | Should match nimsuggest |
| inlayHints | Passthrough | TBD | TBD | Should match nimsuggest |
| outline | TBD          | TBD          | Should be ~95%+ |
| chk     | TBD          | TBD          | Delegates to nim check |

### Performance Comparison

| Metric | nimsuggest | nimsuggest2 | Speedup |
|--------|------------|-------------|---------|
| Startup | TBD | TBD | TBD |
| First query | TBD | TBD | TBD |
| Memory (MB) | TBD | TBD | TBD |
| def (ms) | TBD | TBD | TBD |
| sug (ms) | TBD | TBD | TBD |
| use (ms) | TBD | TBD | TBD |

## Test Implementation Progress

- [x] Test infrastructure setup
- [x] Test fixture files created
- [x] Command comparison tests implemented
- [x] Protocol mode tests implemented
- [x] Benchmark suite implemented
- [ ] Results analysis and documentation (run tests to populate)

## Test Status

**Status**: ✅ Ready to run

All test infrastructure and test suites have been implemented. To execute:

```bash
# Quick verification
nim c -r tests/test1.nim

# Full test suite
nimble test

# Performance benchmarks
nimble benchmark
```

## Future Test Improvements

1. **Fuzzing**: Random input generation for robustness testing
2. **Stress Testing**: Large projects (>1000 files)
3. **Regression Testing**: Track changes over versions
4. **Integration Testing**: Real IDE integration (VSCode, Emacs)
5. **Coverage Analysis**: Code coverage metrics
