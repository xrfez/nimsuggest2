#[**********************************************************************
*                  Test Fixture: Multi-Module Module A                *
**********************************************************************]#

## Module A - provides data processing functions

import std/[tables, strutils]

type DataProcessor* = object
  name*: string
  multiplier: int
  cache: Table[int, int]

proc createProcessor*(name: string): DataProcessor =
  ## Create a new data processor
  result.name = name
  result.multiplier = 2
  result.cache = initTable[int, int]()

proc calculate*(a, b: int): int =
  ## Calculate sum and multiply
  (a + b) * 2

proc process*(dp: var DataProcessor, value: int): int =
  ## Process value through data processor
  if value in dp.cache:
    return dp.cache[value]

  let result = value * dp.multiplier
  dp.cache[value] = result
  result

proc getStats*(dp: DataProcessor): tuple[cacheSize: int, multiplier: int] =
  ## Get processor statistics
  result.cacheSize = dp.cache.len
  result.multiplier = dp.multiplier

# Internal helper (not exported)
proc validateInput(value: int): bool =
  value >= 0 and value < 1000

# Generic helper
proc transform*[T, U](items: seq[T], fn: proc(x: T): U): seq[U] =
  ## Transform sequence using function
  result = newSeq[U](items.len)
  for i, item in items:
    result[i] = fn(item)
