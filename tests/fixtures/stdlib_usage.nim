#[**********************************************************************
*                   Test Fixture: Standard Library Usage             *
**********************************************************************]#

## Test file demonstrating stdlib imports and usage
## Tests import resolution for std/ modules

import
  std/
    [
      os, strutils, sequtils, algorithm, tables, sets, json, options, times, math,
      random,
    ]

type
  FileProcessor* = object
    basePath*: string
    extensions*: HashSet[string]
    cache: Table[string, string]

  Config* = object
    name*: string
    version*: string
    debug*: bool
    maxFiles*: int

proc createFileProcessor*(path: string): FileProcessor =
  ## Create file processor for given path
  result.basePath = path.expandTilde().normalizedPath()
  result.extensions = toHashSet([".nim", ".nims", ".nimble"])
  result.cache = initTable[string, string]()

proc findFiles*(fp: FileProcessor, pattern: string): seq[string] =
  ## Find files matching pattern in base path
  result = @[]
  if not dirExists(fp.basePath):
    return

  for file in walkDirRec(fp.basePath):
    let (_, name, ext) = splitFile(file)
    if ext in fp.extensions and pattern in name:
      result.add(file)

proc processFile*(fp: var FileProcessor, path: string): Option[string] =
  ## Process a single file
  if not fileExists(path):
    return none(string)

  # Check cache
  if path in fp.cache:
    return some(fp.cache[path])

  try:
    let content = readFile(path)
    let processed = content.strip().replace("\r\n", "\n")
    fp.cache[path] = processed
    return some(processed)
  except IOError:
    return none(string)

proc parseConfig*(jsonStr: string): Option[Config] =
  ## Parse configuration from JSON
  try:
    let j = parseJson(jsonStr)
    var config: Config
    config.name = j["name"].getStr()
    config.version = j["version"].getStr()
    config.debug = j{"debug"}.getBool(false)
    config.maxFiles = j{"maxFiles"}.getInt(100)
    return some(config)
  except JsonParsingError, KeyError:
    return none(Config)

proc sortFiles*(files: seq[string], descending: bool = false): seq[string] =
  ## Sort files by name
  result = files
  if descending:
    result.sort(order = SortOrder.Descending)
  else:
    result.sort()

proc filterByExtension*(files: seq[string], ext: string): seq[string] =
  ## Filter files by extension
  files.filter(
    proc(f: string): bool =
      f.endsWith(ext)
  )

proc mapToBasenames*(files: seq[string]): seq[string] =
  ## Map files to basenames
  files.map(
    proc(f: string): string =
      extractFilename(f)
  )

proc calculateHash*(data: string): string =
  ## Simple hash calculation
  result = ""
  var h = 0
  for c in data:
    h = (h * 31 + ord(c)) and 0x7FFFFFFF
  result = $h

proc generateStats*(files: seq[string]): Table[string, int] =
  ## Generate statistics about files
  result = initTable[string, int]()
  result["total"] = files.len

  var extCounts = initTable[string, int]()
  for file in files:
    let ext = file.splitFile().ext
    extCounts.mgetOrPut(ext, 0) += 1

  for ext, count in extCounts:
    result[ext] = count

proc measureTime*[T](fn: proc(): T): tuple[result: T, elapsed: float] =
  ## Measure execution time of function
  let start = cpuTime()
  result.result = fn()
  result.elapsed = cpuTime() - start

proc randomSample*[T](items: seq[T], count: int): seq[T] =
  ## Get random sample from sequence
  if items.len <= count:
    return items

  var indices = toSeq(0 ..< items.len)
  shuffle(indices)

  result = newSeq[T](count)
  for i in 0 ..< count:
    result[i] = items[indices[i]]

# Test mathematical operations
proc calculateStatistics*(values: seq[float]): tuple[mean, stddev, min, max: float] =
  ## Calculate basic statistics
  if values.len == 0:
    return (0.0, 0.0, 0.0, 0.0)

  result.min = values.min()
  result.max = values.max()
  result.mean = values.sum() / values.len.float

  var variance = 0.0
  for v in values:
    variance += pow(v - result.mean, 2)
  variance = variance / values.len.float
  result.stddev = sqrt(variance)

# Date/time operations
proc formatTimestamp*(t: Time): string =
  ## Format time as ISO 8601
  format(t, "yyyy-MM-dd'T'HH:mm:ss")

proc getElapsed*(start: Time): float =
  ## Get elapsed seconds since start
  (getTime() - start).inSeconds().float

when isMainModule:
  echo "Testing stdlib usage..."

  let fp = createFileProcessor(getCurrentDir())
  let files = fp.findFiles("test")
  echo "Found ", files.len, " files"

  let stats = generateStats(files)
  echo "Stats: ", stats
