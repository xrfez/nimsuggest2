#[**********************************************************************
*                            nimsuggest2                              *
*                                                                     *
*  A fast, reliable token-based IDE tool for Nim                      *
*                                                                     *
*  Copyright (c) 2025 Joshua Fenner                                   *
*                                                                     *
*  Licensed under the MIT License. See LICENSE file for details.      *
**********************************************************************]#

## Main entry point for nimsuggest2
## A fast, reliable token-based IDE tool for Nim

import std/[os, strutils, sets, parseopt]
import nimsuggest2/[tokenizer, symbols, imports, cache, project, queries, server_sync]

# Use server_sync as the main server module
type Server = server_sync.Server
type ServerMode = server_sync.ServerMode
const smStdin = server_sync.smStdin
const smTcp = server_sync.smTcp

proc newServer(mode: ServerMode, port: int = 6000, emitEof: bool = true): Server =
  server_sync.newServer(mode, port, emitEof)

proc findProjectFile(startPath: string): string =
  ## Find project file by walking up directory tree
  ## Looks for .nimble, .cfg, .nims files and returns corresponding .nim file
  const extensions = [".nims", ".cfg", ".nimcfg", ".nimble"]
  var
    candidates: seq[string] = @[]
    dir =
      if fileExists(startPath):
        startPath.parentDir()
      else:
        startPath
    prev = dir
    nimblepkg = ""
  let pkgname = startPath.splitFile().name

  while dir.len > 0:
    for (kind, path) in walkDir(dir, relative = false):
      if kind == pcFile:
        let (_, name, ext) = splitFile(path)
        if ext in extensions and name != "config":
          let nimFile = changeFileExt(dir / name, ".nim")
          if fileExists(nimFile):
            candidates.add(nimFile)
          if ext == ".nimble":
            if nimblepkg.len == 0:
              nimblepkg = name
              # Check previous folder for source
              if dir != prev:
                let altNim = prev / nimFile.extractFilename()
                if fileExists(altNim):
                  candidates.add(altNim)

    # Prefer matches with package name
    let pkgname = if nimblepkg.len > 0: nimblepkg else: pkgname
    for c in candidates:
      if pkgname in c.extractFilename():
        return c

    if candidates.len > 0:
      return candidates[0]

    prev = dir
    dir = parentDir(dir)

  return ""

proc showHelp() =
  echo """
nimsuggest2 - Fast token-based IDE tooling for Nim

Usage:
  nimsuggest2 [options] <command> <file>
  nimsuggest2 --stdin [file]           - NimSuggest protocol mode (stdin)
  nimsuggest2 --port:6000 [file]       - NimSuggest protocol mode (TCP)

Commands:
  def <file>:<line>:<col>     - Go to definition
  suggest <file>:<line>:<col> - Code completion suggestions
  usage <file>:<line>:<col>   - Find all usages
  outline <file>              - List all symbols in file
  index <file>                - Index project from file
  
Server Options:
  --stdin                     - Run in stdin/stdout mode (NimSuggest protocol)
  --port:PORT                 - Run TCP server on PORT (default: 6000)
  --address:HOST              - Bind to HOST (default: 127.0.0.1)
  --autobind                  - Pick free port automatically and print to stdout
  --clientProcessId:PID       - Monitor PID and shutdown if it dies
  --v1, --v2, --v3, --v4      - Protocol version (default: v2)
  --tester                    - Enable tester mode (implies --stdin)
  --epc                       - Enable EPC mode (emacs)
  --debug                     - Enable debug output
  --log                       - Enable verbose logging
  --refresh                   - Perform automatic refreshes
  --maxresults:N              - Limit suggestions to N results
  --find                      - Find project file automatically
  --exceptionInlayHints:on|off - Enable/disable exception inlay hints
  --no-nimsuggest             - Disable nimsuggest fallback (use only token-based analysis)
  --no-eof                    - Don't emit !EOF! markers
  --verbose                   - Enable verbose logging to stderr
  
Options:
  --help, -h                  - Show this help
  --version, -v               - Show version
  
Examples:
  nimsuggest2 suggest myfile.nim:10:5
  nimsuggest2 def myfile.nim:20:15
  nimsuggest2 outline myfile.nim
  
  # Server mode (NimSuggest protocol)
  nimsuggest2 --stdin myproject.nim
  echo "outline myfile.nim" | nimsuggest2 --stdin myproject.nim
"""

proc showVersion() =
  echo "nimsuggest2: 0.1.0"
  echo "nim compiler: " & NimVersion
  echo "protocol version: 4 (supports v1-v4)"
  echo "mode: token-based analysis with nimsuggest fallback"
  echo "capabilities: sug, def, use, dus, outline, highlight, chk, known, project"

when isMainModule:
  var
    useStdin = false
    useTcp = false
    port = 6000
    address = "127.0.0.1"
    autobind = false
    clientProcessId = 0
    protocolVersion = 2 # Default to v2 (matches nimsuggest)
    testerMode = false
    epcMode = false
    debugMode = false
    logMode = false
    refreshMode = false
    maxResults = 0
    findProject = false
    exceptionInlayHints = "" # empty = not set, "on"/"off"
    useNimSuggestFallback = true # Enabled by default!
    emitEof = true
    verbose = false
    projectFile = ""
    remainingArgs: seq[string] = @[]

  # Parse options
  var p = initOptParser(commandLineParams())
  while true:
    p.next()
    case p.kind
    of cmdEnd:
      break
    of cmdShortOption, cmdLongOption:
      case p.key.normalize
      of "help", "h":
        showHelp()
        quit(0)
      of "version", "v":
        showVersion()
        quit(0)
      of "info":
        case p.val.normalize
        of "nimver":
          echo NimVersion
          quit(0)
        of "protocolver":
          echo "4"
          quit(0)
        of "capabilities":
          echo "unknownFile"
          quit(0)
        else:
          echo "Unknown info query: ", p.val
          quit(1)
      of "stdin":
        useStdin = true
      of "port":
        useTcp = true
        if p.val.len > 0:
          port = parseInt(p.val)
      of "address":
        address = p.val
        useTcp = true
      of "autobind":
        useTcp = true
        autobind = true
      of "clientprocessid":
        clientProcessId = parseInt(p.val)
      of "v1":
        protocolVersion = 1
      of "v2":
        protocolVersion = 2
      of "v3":
        protocolVersion = 3
      of "v4":
        protocolVersion = 4
      of "tester":
        testerMode = true
        emitEof = true
        # Don't force stdin mode - let --stdin or --autobind/--port determine the mode
      of "epc":
        epcMode = true
        useTcp = true
      of "debug":
        debugMode = true
        verbose = true
      of "log":
        logMode = true
        verbose = true
      of "refresh":
        refreshMode = true
      of "maxresults":
        maxResults = parseInt(p.val)
      of "find":
        findProject = true
      of "exceptioninlayhints":
        exceptionInlayHints = p.val
      of "no-nimsuggest":
        useNimSuggestFallback = false
      of "no-eof":
        emitEof = false
      of "verbose":
        verbose = true
      else:
        echo "Unknown option: --", p.key
        quit(1)
    of cmdArgument:
      remainingArgs.add(p.key)

  # Server mode
  if useStdin or useTcp:
    # First arg is optional project file
    if remainingArgs.len > 0:
      projectFile = remainingArgs[0]

      # If --find flag is set, try to find the project file
      if findProject and projectFile.len > 0:
        let discoveredProject = findProjectFile(projectFile)
        if discoveredProject.len > 0:
          if verbose:
            stderr.writeLine(
              "[nimsuggest2] Auto-discovered project file: ", discoveredProject
            )
          projectFile = discoveredProject
        else:
          if verbose:
            stderr.writeLine(
              "[nimsuggest2] Could not auto-discover project file, using: ", projectFile
            )

    let mode = if useStdin: smStdin else: smTcp
    var srv = newServer(mode, port, emitEof)
    srv.address = address
    srv.verbose = verbose
    srv.autobind = autobind
    srv.protocolVersion = protocolVersion
    srv.clientProcessId = clientProcessId
    srv.maxResults = if maxResults > 0: maxResults else: 100 # Default to 100
    srv.epcMode = epcMode
    srv.useNimSuggestFallback = useNimSuggestFallback
    srv.start(projectFile)
    quit(0)

  # CLI mode
  if remainingArgs.len == 0:
    showHelp()
    quit(0)

  let cmd = remainingArgs[0]

  case cmd
  of "outline":
    if remainingArgs.len < 2:
      echo "Error: outline requires a file path"
      quit(1)

    let filePath = remainingArgs[1]
    if not fileExists(filePath):
      echo "Error: File not found: ", filePath
      quit(1)

    # Extract and display symbols
    let syms = extractSymbolsFromFile(filePath)
    echo "Symbols in ", filePath, ":"
    for sym in syms.symbols:
      echo "  ", sym.kind, " ", sym.name, " at line ", sym.line
  of "index":
    if remainingArgs.len < 2:
      echo "Error: index requires a file path"
      quit(1)

    let filePath = remainingArgs[1]
    if not fileExists(filePath):
      echo "Error: File not found: ", filePath
      quit(1)

    # Index the project
    var cache = newCacheManager()
    let idx = buildProjectIndex(filePath, cache)

    echo "Indexed files:"
    for file in idx.files:
      echo "  ", file
  of "suggest", "def", "usage":
    echo "Command '", cmd, "' not yet implemented"
    echo "Use 'outline' or 'index' for now"
    quit(1)
  else:
    echo "Unknown command: ", cmd
    echo "Use --help for usage information"
    quit(1)
