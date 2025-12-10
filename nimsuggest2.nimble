# Package

version       = "0.1.0"
author        = "nimsuggest2 contributors"
description   = "Fast, reliable token-based IDE tooling for Nim - a nimsuggest replacement"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["nimsuggest2"]


# Dependencies

requires "nim >= 2.2.6"
requires "unittest2"

# Tasks

task docs, "Generate documentation":
  exec "nim doc --project --index:on --outdir:htmldocs src/nimsuggest2.nim"
  echo "Documentation generated in htmldocs/"

task test, "Run all working tests":
  echo "Running test suite..."
  echo ""
  
  # Build nimsuggest2 first
  echo "Building nimsuggest2 in release mode..."
  exec "nim c -d:release -o:bin/nimsuggest2 src/nimsuggest2.nim"
  
  echo ""
  echo "=".repeat(80)
  echo "Running comprehensive test suite (v4 protocol)..."
  echo "Tests native commands, passthrough commands, and compatibility"
  echo "Note: Requires nimsuggest in PATH for comparison tests"
  echo "      Set SKIP_NIMSUGGEST=1 to skip comparison and run faster"
  echo "=".repeat(80)
  exec "nim c -d:release -o:bin/test_nimsuggest2_comprehensive tests/test_nimsuggest2_comprehensive.nim"
  exec "./bin/test_nimsuggest2_comprehensive"
  
  echo ""
  echo "All tests completed!"

task benchmark, "Run performance benchmarks":
  echo "Running performance benchmarks..."
  echo ""
  echo "Note: This compares nimsuggest vs nimsuggest2 performance."
  echo "Ensure 'nimsuggest' is available in your PATH for comparison."
  echo ""
  
  # Build nimsuggest2 in release mode
  echo "Building nimsuggest2 in release mode..."
  exec "nim c -d:release -o:bin/nimsuggest2 src/nimsuggest2.nim"
  
  echo ""
  echo "Compiling benchmark..."
  exec "nim c -d:release -o:bin/benchmark_comparison tests/benchmark_comparison.nim"
  
  echo ""
  echo "Running benchmarks..."
  exec "./bin/benchmark_comparison"
  
  echo ""
  echo "Benchmarks completed!"
