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

# Tasks

task docs, "Generate documentation":
  exec "nim doc --project --index:on --outdir:htmldocs src/nimsuggest2.nim"
  echo "Documentation generated in htmldocs/"
