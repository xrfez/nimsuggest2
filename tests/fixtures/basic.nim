#[**********************************************************************
*                         Test Fixture: Basic                         *
*                                                                     *
*  Tests basic Nim language constructs for IDE functionality          *
**********************************************************************]#

## Basic test file for nimsuggest2 testing
## Contains common Nim constructs

import std/[strutils, tables, sequtils]

# Constants
const
  MAX_SIZE* = 100
  DEFAULT_NAME = "test"
  PI = 3.14159

# Type definitions
type
  Color* = enum
    Red
    Green
    Blue

  Person* = object
    name*: string
    age*: int
    favoriteColor*: Color

  Animal = ref object
    species: string
    weight: float

  GenericContainer*[T] = object
    items*: seq[T]
    count: int

# Variables
var
  globalCounter* = 0
  cache: Table[string, int]

let
  VERSION* = "1.0.0"
  AUTHORS = @["Alice", "Bob"]

# Procedures
proc add*(a, b: int): int =
  ## Add two integers
  ## 
  ## Returns the sum of a and b
  result = a + b

proc multiply(x, y: float): float =
  ## Multiply two floats
  x * y

func square*(n: int): int =
  ## Calculate square of a number
  n * n

proc createPerson*(name: string, age: int): Person =
  ## Factory function for Person
  result.name = name
  result.age = age
  result.favoriteColor = Blue

method speak*(a: Animal): string {.base.} =
  ## Virtual method for animals
  "Generic animal sound"

proc greet(p: Person): string =
  ## Generate greeting for person
  "Hello, " & p.name & "!"

# Iterators
iterator countUp*(start, stop: int): int =
  ## Count from start to stop
  var i = start
  while i <= stop:
    yield i
    inc i

iterator items*[T](container: GenericContainer[T]): T =
  ## Iterate over container items
  for item in container.items:
    yield item

# Templates
template max*(a, b: typed): untyped =
  ## Return maximum of two values
  if a > b: a else: b

template withLock*(lock: typed, body: untyped): untyped =
  ## Execute body with lock held
  acquire(lock)
  try:
    body
  finally:
    release(lock)

# Macros
import std/macros

macro debug*(n: varargs[typed]): untyped =
  ## Debug print macro
  result = newStmtList()
  for arg in n:
    result.add quote do:
      echo `arg`

# Generic procedures
proc contains*[T](container: GenericContainer[T], item: T): bool =
  ## Check if container contains item
  for x in container.items:
    if x == item:
      return true
  false

proc map*[T, U](items: seq[T], fn: proc(x: T): U): seq[U] =
  ## Map function over sequence
  result = newSeq[U](items.len)
  for i, item in items:
    result[i] = fn(item)

# Operators
proc `+`*(a, b: Person): string =
  ## Combine person names
  a.name & " and " & b.name

proc `[]`*[T](container: GenericContainer[T], index: int): T =
  ## Index into container
  container.items[index]

# Converters
converter toInt*(c: Color): int =
  ## Convert color to int
  ord(c)

# Main test procedure
proc runTests*() =
  ## Run basic tests
  let p1 = createPerson("Alice", 30)
  let p2 = createPerson("Bob", 25)

  echo greet(p1)
  echo p1 + p2

  assert add(2, 3) == 5
  assert square(4) == 16
  assert max(10, 20) == 20

  var container: GenericContainer[int]
  container.items = @[1, 2, 3, 4, 5]
  container.count = 5

  for i in countUp(1, 5):
    echo i

  for item in container:
    echo item

  let doubled = container.items.map(
    proc(x: int): int =
      x * 2
  )
  echo doubled

when isMainModule:
  runTests()
