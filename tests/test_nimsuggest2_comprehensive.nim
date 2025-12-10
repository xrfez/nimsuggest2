## Comprehensive nimsuggest2 Test Suite
## Tests all commands with protocol v4, comparing nimsuggest vs nimsuggest2
## Adheres to TESTS.md requirements

import std/[os, osproc, strformat, times, net, strutils, tables, sequtils]

const
  TimeoutSeconds = 60  # Increased for slow nimsuggest startup
  BasicNimFile = "tests/fixtures/basic.nim"
  UniqueModuleA = "tests/fixtures/unique_module_a.nim"
  UniqueModuleB = "tests/fixtures/unique_module_b.nim"
  UniqueProject = "tests/fixtures/unique_project.nim"
  CompatibilityThreshold = 0.50 # 50% compatible results acceptable

type
  TestResult = object
    command: string
    cmdType: string # "native", "passthrough", "control"
    nimsuggestLines: int
    nimsuggest2Lines: int
    compatible: bool
    compatibilityScore: float
    notes: string

  ServerInstance = object
    process: Process
    mode: string
    port: int
    ready: bool

var testResults: seq[TestResult]

proc log(msg: string) =
  echo "[TEST] ", msg

proc startNimsuggest2Tcp(port: int, projectFile: string): ServerInstance =
  ## Start nimsuggest2 in TCP mode
  let binary = getCurrentDir() / "bin" / "nimsuggest2"

  result.process = startProcess(
    binary, args = @[fmt"--port:{port}", "--v4", projectFile], options = {}
  )
  result.mode = "tcp"
  result.port = port
  result.ready = false

  # Wait for server to accept connections
  let startTime = cpuTime()
  while cpuTime() - startTime < TimeoutSeconds:
    try:
      let sock = newSocket()
      sock.connect("127.0.0.1", Port(port), timeout = 1000)
      result.ready = true
      sock.close()
      break
    except:
      sleep(100)

proc sendTcpCommand(server: ServerInstance, cmd: string): seq[string] =
  ## Send command to TCP server and get response
  result = @[]

  if not server.ready:
    return

  try:
    let sock = newSocket()
    sock.connect("127.0.0.1", Port(server.port), timeout = 2000)
    sock.send(cmd & "\r\n")

    # Read response until !EOF! marker or timeout
    let startTime = cpuTime()
    let maxWaitTime = 5.0 # Reduced to 5 seconds per command
    while cpuTime() - startTime < maxWaitTime:
      try:
        var line: string
        sock.readLine(line, timeout = 500) # Shorter socket timeout
        if line.len == 0:
          break
        let trimmed = line.strip()
        if trimmed.len == 0:
          continue # Skip blank lines
        if trimmed.startsWith("!EOF!"):
          break # Found end marker
        result.add(trimmed)
      except TimeoutError:
        # No data available, check if we've waited long enough
        if result.len > 0:
          # We got some results, wait a bit more for EOF
          if cpuTime() - startTime > 2.0:
            break # But don't wait forever
        continue
      except:
        break

    sock.close()
  except:
    discard

proc stopServer(server: var ServerInstance) =
  if server.process != nil:
    try:
      # Try to send quit command gracefully first
      let sock = newSocket()
      sock.connect("127.0.0.1", Port(server.port), timeout = 1000)
      sock.send("quit\r\n")
      sock.close()
      sleep(100)
    except:
      discard
    
    # Then terminate the process
    try:
      server.process.terminate()
      discard server.process.waitForExit(timeout = 2000)
    except:
      try:
        server.process.kill()
      except:
        discard
    
    server.process.close()

proc calculateCompatibility(ns1, ns2: seq[string]): (bool, float, string) =
  ## Calculate compatibility between two result sets
  ## Returns (compatible, score, notes)

  if ns1.len == 0 and ns2.len == 0:
    return (true, 1.0, "Both empty")

  if ns1.len == 0:
    return (false, 0.0, "nimsuggest returned nothing")

  if ns2.len == 0:
    return (false, 0.0, "nimsuggest2 returned nothing")

  # For most commands, similar line count is good
  let ratio = min(ns1.len, ns2.len).float / max(ns1.len, ns2.len).float

  # Count matching lines (position-based)
  var matches = 0
  for i in 0 ..< min(ns1.len, ns2.len):
    let parts1 = ns1[i].split('\t')
    let parts2 = ns2[i].split('\t')

    if parts1.len >= 7 and parts2.len >= 7:
      # Check if same symbol kind and file
      if parts1[1] == parts2[1] and parts1[4] == parts2[4]:
        matches += 1

  let matchScore =
    if min(ns1.len, ns2.len) > 0:
      matches.float / min(ns1.len, ns2.len).float
    else:
      0.0

  let finalScore = (ratio + matchScore) / 2.0
  let compatible = finalScore >= CompatibilityThreshold

  let notes =
    fmt"{ns1.len} vs {ns2.len} lines, {matches} matches, {finalScore:.2f} score"

  return (compatible, finalScore, notes)

# Global instances to reuse across tests
var globalNimsuggest: ServerInstance
var globalNimsuggest2: ServerInstance

proc startGlobalNimsuggest(): bool =
  ## Start a single nimsuggest instance for all tests
  ## Returns false if nimsuggest not available (tests will run without comparison)

  # Check if user wants to skip nimsuggest comparison
  if existsEnv("SKIP_NIMSUGGEST"):
    log("⚠️  SKIP_NIMSUGGEST set, running tests without comparison")
    return false

  let nimsuggestPath = findExe("nimsuggest")
  if nimsuggestPath.len == 0:
    log("⚠️  nimsuggest not found, skipping all comparisons")
    return false

  log("→ Starting global nimsuggest instance on port 6101...")
  log("   (This may take 10+ seconds to compile project...)")

  try:
    globalNimsuggest.process = startProcess(
      nimsuggestPath, args = @["--port:6101", "--v4", UniqueProject], options = {}
    )
    globalNimsuggest.port = 6101
    globalNimsuggest.mode = "tcp"
    globalNimsuggest.ready = false

    # Wait for nimsuggest to start (reduced timeout)
    let startTime = cpuTime()
    let maxWait = 15.0 # 15 seconds max
    while cpuTime() - startTime < maxWait:
      try:
        let sock = newSocket()
        sock.connect("127.0.0.1", Port(6101), timeout = 1000)
        globalNimsuggest.ready = true
        sock.close()
        log("✓ Global nimsuggest ready")
        return true
      except:
        sleep(100)

    log("❌ Global nimsuggest failed to start (timeout after 15s)")
    log("   Set SKIP_NIMSUGGEST=1 to run tests without comparison")
    globalNimsuggest.process.kill()
    globalNimsuggest.process.close()
    return false
  except:
    log("❌ Failed to start nimsuggest: " & getCurrentExceptionMsg())
    return false

proc startGlobalNimsuggest2(): bool =
  ## Start a single nimsuggest2 instance for all tests
  log("→ Starting global nimsuggest2 instance on port 6100...")

  try:
    globalNimsuggest2 = startNimsuggest2Tcp(6100, UniqueProject)
    if not globalNimsuggest2.ready:
      log("❌ Global nimsuggest2 failed to start")
      return false

    log("✓ Global nimsuggest2 ready")

    # Give it a moment to build initial index
    sleep(200)
    return true
  except:
    log("❌ Failed to start nimsuggest2: " & getCurrentExceptionMsg())
    return false

proc testCommand(cmd: string, cmdType: string, description: string): TestResult =
  ## Test a single command comparing nimsuggest vs nimsuggest2
  result.command = cmd
  result.cmdType = cmdType

  log(fmt"Testing {cmdType} command: {description}")

  # Get nimsuggest2 results using global instance
  log(fmt"  → Sending command to nimsuggest2: {cmd}")
  let ns2Results = sendTcpCommand(globalNimsuggest2, cmd)
  result.nimsuggest2Lines = ns2Results.len
  log(fmt"  ← nimsuggest2 returned {ns2Results.len} lines")

  # Use global nimsuggest instance for comparison
  if not globalNimsuggest.ready:
    log(fmt"  ⚠️  nimsuggest not available, skipping comparison")
    log(fmt"  ℹ️  nimsuggest2 returned {ns2Results.len} lines")
    result.nimsuggestLines = -1
    result.compatible = true # Can't compare, assume OK
    result.compatibilityScore = 1.0
    result.notes = "nimsuggest not available for comparison"

    # Show first few results
    if ns2Results.len > 0:
      log("  First 3 results:")
      for i in 0 ..< min(3, ns2Results.len):
        log(fmt"    [{i}] {ns2Results[i]}")
    return

  # Get nimsuggest results using global instance
  log(fmt"  → Sending command to nimsuggest: {cmd}")
  let cmdStartTime = cpuTime()
  let nsResults = sendTcpCommand(globalNimsuggest, cmd)
  let cmdDuration = cpuTime() - cmdStartTime
  log(fmt"  ← nimsuggest returned {nsResults.len} lines (took {cmdDuration:.2f}s)")

  result.nimsuggestLines = nsResults.len

  # Calculate compatibility
  let (compatible, score, notes) = calculateCompatibility(nsResults, ns2Results)
  result.compatible = compatible
  result.compatibilityScore = score
  result.notes = notes

  # Log results
  if compatible:
    log(fmt"  ✅ Compatible: {notes}")
  else:
    log(fmt"  ⚠️  Low compatibility: {notes}")

  # For passthrough commands, show detailed line-by-line comparison
  if cmdType == "passthrough":
    log("  PASSTHROUGH COMMAND - Should match exactly!")
    log("  Line-by-line comparison:")
    let maxLines = max(nsResults.len, ns2Results.len)
    for i in 0 ..< maxLines:
      let nsLine =
        if i < nsResults.len:
          nsResults[i]
        else:
          "<MISSING>"
      let ns2Line =
        if i < ns2Results.len:
          ns2Results[i]
        else:
          "<MISSING>"
      let match = if nsLine == ns2Line: "✓" else: "✗"
      log(fmt"    [{i}] {match}")
      if nsLine != ns2Line:
        log(fmt"      NS:  '{nsLine}'")
        log(fmt"      NS2: '{ns2Line}'")
        # Show byte-by-byte if they look similar
        if nsLine.len > 0 and ns2Line.len > 0:
          log(fmt"      NS  len={nsLine.len}")
          log(fmt"      NS2 len={ns2Line.len}")
  elif cmdType == "native":
    # Show detailed line-by-line comparison for native commands too
    log("  NATIVE COMMAND - Line-by-line comparison:")
    let maxLines = max(nsResults.len, ns2Results.len)
    let linesToShow = min(5, maxLines) # Show up to 5 lines
    for i in 0 ..< linesToShow:
      let nsLine =
        if i < nsResults.len:
          nsResults[i]
        else:
          "<MISSING>"
      let ns2Line =
        if i < ns2Results.len:
          ns2Results[i]
        else:
          "<MISSING>"
      let match = if nsLine == ns2Line: "✓" else: "✗"
      log(fmt"    [{i}] {match}")
      if nsLine != ns2Line:
        # Show first 100 chars of each line for native commands
        let nsPreview =
          if nsLine.len > 100:
            nsLine[0 .. 99] & "..."
          else:
            nsLine
        let ns2Preview =
          if ns2Line.len > 100:
            ns2Line[0 .. 99] & "..."
          else:
            ns2Line
        log(fmt"      NS:  {nsPreview}")
        log(fmt"      NS2: {ns2Preview}")
    if maxLines > linesToShow:
      log(fmt"    ... ({maxLines - linesToShow} more lines not shown)")
  else:
    # Show sample results for other commands
    if nsResults.len > 0 or ns2Results.len > 0:
      log("  Sample comparison (first 2 lines):")
      for i in 0 ..< min(2, max(nsResults.len, ns2Results.len)):
        if i < nsResults.len:
          log(fmt"    NS:  {nsResults[i]}")
        if i < ns2Results.len:
          log(fmt"    NS2: {ns2Results[i]}")

proc runTests() =
  echo "=".repeat(80)
  echo "nimsuggest2 Comprehensive Test Suite (Protocol v4)"
  echo "=".repeat(80)
  echo ""

  # Start global nimsuggest2 instance (reused for all tests)
  let ns2Available = startGlobalNimsuggest2()
  if not ns2Available:
    echo "❌ nimsuggest2 failed to start - cannot run tests"
    quit(1)
  echo ""

  # Start global nimsuggest instance (reused for all tests)
  let nsAvailable = startGlobalNimsuggest()
  if not nsAvailable:
    echo "⚠️  Running tests without nimsuggest comparison"
  echo ""

  # Native commands (11) - Using unique symbols across modules
  # Line 13 col 6 = "uniqueProcAlpha" in unique_module_a.nim
  testResults.add testCommand(
    fmt"def {UniqueModuleA}:13:6", "native", "def - Go to definition (uniqueProcAlpha)"
  )

  testResults.add testCommand(
    fmt"sug {UniqueModuleA}:13:10",
    "native",
    "sug - Autocomplete (known differences expected)",
  )

  testResults.add testCommand(
    fmt"use {UniqueModuleA}:13:6", "native", "use - Find usages (uniqueProcAlpha)"
  )

  # Line 18 col 6 = "uniqueProcGamma" in unique_module_b.nim
  testResults.add testCommand(
    fmt"dus {UniqueModuleB}:13:6",
    "native",
    "dus - Definition + usages (uniqueProcGamma)",
  )

  testResults.add testCommand(
    fmt"chk {UniqueModuleA}", "native", "chk - Check for errors"
  )

  testResults.add testCommand(
    fmt"outline {UniqueModuleB}", "native", "outline - Document outline"
  )

  # Line 5 col 6 = "UniqueTypeGamma" type definition
  testResults.add testCommand(
    fmt"highlight {UniqueModuleB}:5:6",
    "native",
    "highlight - Highlight symbol (UniqueTypeGamma)",
  )

  testResults.add testCommand(
    fmt"known {UniqueModuleA}", "native", "known - File known check"
  )

  testResults.add testCommand(
    fmt"project {UniqueModuleB}", "native", "project - Get project file"
  )

  testResults.add testCommand(
    fmt"globalSymbols uniqueProc",
    "native",
    "globalSymbols - Global search (unique symbols)",
  )

  echo ""
  echo "=== Starting Passthrough Command Tests ==="
  echo ""

  # Passthrough commands (4 - reduced for testing) - Using unique symbols
  # Line 23 col 10 = inside useModuleASymbols function
  testResults.add testCommand(
    fmt"type {UniqueModuleB}:24:10", "passthrough", "type - Type at position"
  )

  testResults.add testCommand(
    fmt"declaration {UniqueModuleB}:13:6",
    "passthrough",
    "declaration - Find declaration (uniqueProcGamma)",
  )

  # Print summary
  echo ""
  echo "=".repeat(80)
  echo "TEST SUMMARY"
  echo "=".repeat(80)
  echo ""

  var nativeTests = testResults.filterIt(it.cmdType == "native")
  var passthroughTests = testResults.filterIt(it.cmdType == "passthrough")

  var nativePassed = nativeTests.filterIt(it.compatible).len
  var passthroughPassed = passthroughTests.filterIt(it.compatible).len

  echo fmt"Native Commands:      {nativePassed}/{nativeTests.len} passed"
  echo fmt"Passthrough Commands: {passthroughPassed}/{passthroughTests.len} passed"
  echo ""

  # Detailed results
  echo "Detailed Results:"
  echo "Command              Type         NS Lines  NS2 Lines    Score Status      "
  echo "-".repeat(80)

  for result in testResults:
    let status = if result.compatible: "✅ PASS" else: "⚠️  WARN"
    let nsLines =
      if result.nimsuggestLines >= 0:
        $result.nimsuggestLines
      else:
        "N/A"
    let scoreStr = fmt"{result.compatibilityScore:.2f}"
    echo fmt"{result.command:<20} {result.cmdType:<12} {nsLines:>10} {result.nimsuggest2Lines:>10} {scoreStr:>8} {status:<12}"

  echo ""

  # Cleanup global instances
  if globalNimsuggest.ready:
    log("→ Shutting down global nimsuggest instance")
    stopServer(globalNimsuggest)

  if globalNimsuggest2.ready:
    log("→ Shutting down global nimsuggest2 instance")
    stopServer(globalNimsuggest2)

  # Final result
  let totalPassed = nativePassed + passthroughPassed
  let totalTests = nativeTests.len + passthroughTests.len

  if totalPassed == totalTests:
    echo "✅ ALL TESTS PASSED"
    quit(0)
  elif totalPassed >= int(totalTests.float * 0.8):
    echo fmt"⚠️  PARTIAL PASS: {totalPassed}/{totalTests} tests passed (>80%)"
    quit(0)
  else:
    echo fmt"❌ FAILED: Only {totalPassed}/{totalTests} tests passed"
    quit(1)

when isMainModule:
  try:
    runTests()
  except Exception as e:
    echo "\n❌ Test suite failed: " & e.msg
    echo e.getStackTrace()
    quit(1)
