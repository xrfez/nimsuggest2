## Performance Benchmark comparing nimsuggest vs nimsuggest2
## Uses proper global instance pattern (like comprehensive test)

import std/[os, osproc, strformat, times, net, strutils, math]

const
  UniqueModuleA = "tests/fixtures/unique_module_a.nim"
  UniqueModuleB = "tests/fixtures/unique_module_b.nim"
  UniqueProject = "tests/fixtures/unique_project.nim"
  TimeoutSeconds = 15
  WarmupRuns = 3
  BenchmarkRuns = 20

type ServerInstance = object
  process: Process
  port: int
  ready: bool
  name: string

var
  globalNimsuggest: ServerInstance
  globalNimsuggest2: ServerInstance

proc log(msg: string) =
  echo "[BENCH] ", msg

proc startServer(
    port: int, binary: string, projectFile: string, name: string
): ServerInstance =
  result.process = startProcess(
    binary, args = @[fmt"--port:{port}", "--v4", projectFile], options = {}
  )
  result.port = port
  result.ready = false
  result.name = name

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

  if not result.ready:
    log("ERROR: " & name & " failed to start")

proc sendCommand(
    server: ServerInstance, cmd: string
): tuple[lines: seq[string], duration: float] =
  result.lines = @[]
  result.duration = 0.0

  if not server.ready:
    return

  let startTime = cpuTime()
  try:
    let sock = newSocket()
    sock.connect("127.0.0.1", Port(server.port), timeout = 2000)
    sock.send(cmd & "\r\n")

    let cmdStartTime = cpuTime()
    while cpuTime() - cmdStartTime < 5.0:
      try:
        var line: string
        sock.readLine(line, timeout = 500)
        if line.len == 0:
          break
        let trimmed = line.strip()
        if trimmed.len == 0:
          continue
        if trimmed.startsWith("!EOF!"):
          break
        result.lines.add(trimmed)
      except TimeoutError:
        if result.lines.len > 0 and cpuTime() - cmdStartTime > 2.0:
          break
        continue
      except:
        break

    result.duration = (cpuTime() - startTime) * 1000.0 # Convert to ms
    sock.close()
  except:
    result.duration = (cpuTime() - startTime) * 1000.0

proc stopServer(server: var ServerInstance) =
  if server.process != nil:
    try:
      let sock = newSocket()
      sock.connect("127.0.0.1", Port(server.port), timeout = 1000)
      sock.send("quit\r\n")
      sock.close()
    except:
      discard
    sleep(100)
    server.process.terminate()
    discard server.process.waitForExit()

proc benchmark(
    name: string, cmd: string, warmup: int = WarmupRuns, runs: int = BenchmarkRuns
) =
  log("Benchmarking: " & name)

  # Warmup runs
  for i in 1 .. warmup:
    discard globalNimsuggest.sendCommand(cmd)
    discard globalNimsuggest2.sendCommand(cmd)

  # Benchmark nimsuggest
  var nsTimes: seq[float] = @[]
  var nsLineCount = 0
  for i in 1 .. runs:
    let (lines, duration) = globalNimsuggest.sendCommand(cmd)
    nsTimes.add(duration)
    if i == 1:
      nsLineCount = lines.len

  # Benchmark nimsuggest2
  var ns2Times: seq[float] = @[]
  var ns2LineCount = 0
  for i in 1 .. runs:
    let (lines, duration) = globalNimsuggest2.sendCommand(cmd)
    ns2Times.add(duration)
    if i == 1:
      ns2LineCount = lines.len

  # Calculate statistics
  proc sumSeq(s: seq[float]): float =
    result = 0.0
    for v in s:
      result += v

  proc minSeq(s: seq[float]): float =
    result = s[0]
    for v in s:
      if v < result:
        result = v

  let nsAvg = sumSeq(nsTimes) / nsTimes.len.float
  let ns2Avg = sumSeq(ns2Times) / ns2Times.len.float
  let nsMin = minSeq(nsTimes)
  let ns2Min = minSeq(ns2Times)
  let speedup = nsAvg / ns2Avg

  echo fmt"  nimsuggest:  {nsAvg:>7.2f}ms (min: {nsMin:>6.2f}ms, {nsLineCount:>4} lines)"
  echo fmt"  nimsuggest2: {ns2Avg:>7.2f}ms (min: {ns2Min:>6.2f}ms, {ns2LineCount:>4} lines)"
  echo fmt"  Speedup:     {speedup:>6.2f}x"
  echo ""

proc main() =
  echo "=".repeat(80)
  echo "nimsuggest vs nimsuggest2 Performance Benchmark"
  echo "=".repeat(80)
  echo ""

  # Find nimsuggest
  let nimsuggestPath = findExe("nimsuggest")
  if nimsuggestPath.len == 0:
    log("ERROR: nimsuggest not found in PATH")
    quit(1)

  log("Starting global nimsuggest instance on port 6101...")
  globalNimsuggest = startServer(6101, nimsuggestPath, UniqueProject, "nimsuggest")
  if not globalNimsuggest.ready:
    quit(1)
  log("✓ nimsuggest ready")

  log("Starting global nimsuggest2 instance on port 6100...")
  globalNimsuggest2 = startServer(6100, "bin/nimsuggest2", UniqueProject, "nimsuggest2")
  if not globalNimsuggest2.ready:
    quit(1)
  log("✓ nimsuggest2 ready")

  # Let them stabilize and build indexes
  log("Warming up (building indexes)...")
  discard globalNimsuggest.sendCommand(fmt"outline {UniqueModuleA}")
  discard globalNimsuggest2.sendCommand(fmt"outline {UniqueModuleA}")
  sleep(1000)

  echo ""
  echo "=".repeat(80)
  echo "BENCHMARK RESULTS"
  echo "=".repeat(80)
  echo ""

  benchmark("def - Go to definition", fmt"def {UniqueModuleA}:13:6")
  benchmark("use - Find usages", fmt"use {UniqueModuleA}:13:6")
  benchmark("sug - Autocomplete", fmt"sug {UniqueModuleA}:13:10")
  benchmark("dus - Definition + usages", fmt"dus {UniqueModuleB}:13:6")
  benchmark("outline - Document outline", fmt"outline {UniqueModuleB}")
  benchmark("globalSymbols - Global search", "globalSymbols uniqueProc")
  benchmark("highlight - Highlight symbol", fmt"highlight {UniqueModuleB}:5:6")
  benchmark("chk - Check for errors", fmt"chk {UniqueModuleA}")

  echo "=".repeat(80)

  log("Shutting down servers...")
  stopServer(globalNimsuggest)
  stopServer(globalNimsuggest2)

  log("Benchmark complete!")

when isMainModule:
  main()
