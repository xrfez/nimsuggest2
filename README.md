# nimsuggest2

Fast, reliable token-based IDE tooling for Nim - a nimsuggest replacement that doesn't crash or hog resources.

## Features

- **✅ Token-based parsing** - No full AST required, 250x faster than targets
- **✅ Multi-file project indexing** - Follows imports recursively
- **✅ Nim compiler-compatible import resolution** - Supports nim.cfg, nimbledeps, version matching
- **✅ Smart caching** - 6x speedup on repeated queries
- **✅ Export/re-export tracking** - Handles `export module` and selective exports
- **✅ Simple and reliable** - Clean code, comprehensive tests, no memory leaks
- **✅ NimSuggest protocol compatible** - Drop-in replacement with TCP and stdin modes
- **✅ nimlangserver ready** - Fully compatible with existing language server
- **✅ Hybrid mode** - Optional nimsuggest fallback for type-heavy features with fault tolerance

## Installation

```bash
nimble install
```

## Usage

### NimSuggest Protocol Mode (for Language Servers)

```bash
# Default mode - hybrid (fast token-based + nimsuggest fallback)
nimsuggest2 --autobind myproject.nim

# Fast-only mode - disable nimsuggest fallback
nimsuggest2 --autobind --no-nimsuggest myproject.nim

# TCP mode with specific port
nimsuggest2 --port:6000 myproject.nim

# Stdin mode (for manual testing)
nimsuggest2 --stdin myproject.nim
```

**Default Hybrid Mode:**
- Fast token-based operations for completions, definitions, usages
- Automatically delegates unsupported commands to nimsuggest
- Fault-tolerant: auto-restarts nimsuggest on crashes
- Best of both worlds: speed + complete feature set
- Enabled by default (nimlangserver can't pass custom flags)

**Use `--no-nimsuggest` to disable fallback and use only token-based analysis**

See [HYBRID_ARCHITECTURE.md](HYBRID_ARCHITECTURE.md) for details.

**Protocol commands:**
```
sug myfile.nim:10:5    # Code completion at line 10, column 5
def myfile.nim:20:12   # Go to definition
use myfile.nim:15:8    # Find all usages
outline myfile.nim     # List all symbols
chk myfile.nim         # Check for errors/warnings
chkFile myfile.nim     # Same as chk
quit                   # Exit server
```

### Command Line

```bash
# Show all symbols in a file
nimsuggest2 outline myfile.nim

# Index a project (follows all imports)
nimsuggest2 index myproject.nim
```

### As a Library

```nim
import nimsuggest2/[tokenizer, symbols, project, queries]

# Extract symbols from a file
let idx = extractSymbolsFromFile("myfile.nim")
for sym in idx.symbols:
  echo sym.name, ": ", sym.kind

# Build project index
var cache = newCacheManager()
let project = buildProjectIndex("main.nim", cache)

# Query for symbols
let matches = project.findSymbol("myFunction")
```

## Project Structure

```
nimsuggest2/
├── src/
│   ├── nimsuggest2.nim          # Main executable
│   └── nimsuggest2/             # Library modules
│       ├── tokenizer.nim           # Fast Nim tokenizer (730 lines)
│       ├── symbols.nim             # Symbol extraction
│       ├── imports.nim             # Import resolution (Nim-compatible)
│       ├── cache.nim               # File caching (6x speedup)
│       ├── project.nim             # Project indexing
│       └── queries.nim             # Symbol queries
├── tests/                          # Test suite
│   ├── test_tokenizer.nim
│   ├── test_symbols.nim
│   ├── test_imports.nim
│   ├── test_project.nim
│   ├── test_resolution_complete.nim
│   └── ...
├── examples/                       # Examples and benchmarks
└── docs/                          # Documentation
    ├── IMPORT_RESOLUTION.md       # Import resolution details
    ├── PERFORMANCE.md             # Performance analysis
    └── ...
```

## Architecture

### Token-Based Approach

Unlike nimsuggest which uses full semantic analysis:
- Parses tokens only (no AST construction)
- Pattern matches for symbols (procs, types, consts, etc.)
- Tracks exports with simple rules
- 250x faster for large files

### Import Resolution

Matches Nim compiler exactly:
1. Current file's directory
2. --path: from nim.cfg/config.nims
3. nimbledeps/pkgs/
4. ~/.nimble/pkgs2/ (version-matched)
5. Nim stdlib

See [IMPORT_RESOLUTION.md](IMPORT_RESOLUTION.md) for details.

### Caching Strategy

- File-level caching with mtime tracking
- Invalidates on file changes
- Caches tokenization + symbol extraction
- 6x speedup on repeated queries

## Performance

From [PERFORMANCE.md](PERFORMANCE.md):

| File Size | Tokenization | Symbol Extraction | Total |
|-----------|--------------|-------------------|-------|
| 2KB       | 0.04ms       | 0.01ms           | 0.05ms |
| 20KB      | 0.23ms       | 0.09ms           | 0.32ms |
| 200KB     | 1.93ms       | 0.51ms           | 2.44ms |
| 2MB       | 19.3ms       | 5.1ms            | 24.4ms |

**Multi-file project** (3 files, 21 symbols): ~4ms total

## Testing

```bash
# Run all tests
nimble test

# Run specific test suites
nimble testCore        # Core functionality
nimble testResolution  # Import resolution

# Run benchmarks
nimble bench
```

All tests passing ✓

## Documentation

- [IMPORT_RESOLUTION.md](IMPORT_RESOLUTION.md) - Import resolution details
- [PERFORMANCE.md](PERFORMANCE.md) - Performance benchmarks
- [TOKENIZER_SUMMARY.md](TOKENIZER_SUMMARY.md) - Tokenizer implementation

## Roadmap

- [x] Fast tokenizer
- [x] Symbol extraction
- [x] Import resolution (Nim-compatible)
- [x] Project indexing
- [x] Export tracking
- [x] File caching
- [x] Proper nimble structure
- [ ] NimSuggest protocol implementation
- [ ] LSP server integration
- [ ] Editor plugins

## Why nimsuggest2?

**Current nimsuggest problems:**
- Crashes frequently
- Memory leaks (100% CPU, excessive RAM)
- Slow on large projects
- Unreliable
- Hard to debug

**Our solution:**
- Never crashes (token-based, no complex analysis)
- Minimal memory usage
- Fast (250x faster than targets)
- Simple, testable code
- Easy to extend

## Contributing

Tests and bug reports welcome! See [AGENTS.md](AGENTS.md) for development notes.

## License

MIT
