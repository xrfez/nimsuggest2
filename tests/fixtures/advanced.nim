#[**********************************************************************
*                       Test Fixture: Advanced                        *
*                                                                     *
*  Tests advanced Nim features for IDE functionality                  *
**********************************************************************]#

## Advanced Nim features test file
## Includes generics, concepts, effects, async, etc.

import std/[asyncdispatch, json, options, strformat]

# Advanced type definitions
type
  NodeKind = enum
    nkInt
    nkFloat
    nkString
    nkList

  Node = ref object
    case kind: NodeKind
    of nkInt:
      intVal: int
    of nkFloat:
      floatVal: float
    of nkString:
      strVal: string
    of nkList:
      children: seq[Node]

  # Generic tree structure
  Tree*[T] = ref object
    value: T
    left: Tree[T]
    right: Tree[T]

  # Concept for comparable types
  Comparable =
    concept x, y
        (x < y) is bool
        (x == y) is bool

  # Distinct types
  UserId = distinct int
  Email = distinct string

  # Result type
  Result*[T, E] = object
    case success: bool
    of true:
      value: T
    of false:
      error: E

# Generic procedures with constraints
proc insert*[T: Comparable](tree: var Tree[T], item: T) =
  ## Insert item into binary search tree
  if tree.isNil:
    tree = Tree[T](value: item)
  elif item < tree.value:
    tree.left.insert(item)
  else:
    tree.right.insert(item)

proc find*[T: Comparable](tree: Tree[T], item: T): bool =
  ## Search for item in tree
  if tree.isNil:
    return false
  if item == tree.value:
    return true
  elif item < tree.value:
    return tree.left.find(item)
  else:
    return tree.right.find(item)

# Async procedures
proc fetchData*(url: string): Future[string] {.async.} =
  ## Async fetch data from URL
  await sleepAsync(100)
  result = "data from " & url

proc processAsync*(items: seq[string]): Future[seq[string]] {.async.} =
  ## Process items asynchronously
  result = @[]
  for item in items:
    let processed = await fetchData(item)
    result.add(processed)

# Effect system
proc pureFunc*(x: int): int {.noSideEffect.} =
  ## Pure function with no side effects
  x * 2

proc mayRaise*(x: int): int {.raises: [ValueError].} =
  ## Function that may raise ValueError
  if x < 0:
    raise newException(ValueError, "Negative value")
  x

# Operator overloading
proc `$`*(node: Node): string =
  ## Convert node to string
  case node.kind
  of nkInt:
    $node.intVal
  of nkFloat:
    $node.floatVal
  of nkString:
    node.strVal
  of nkList:
    $node.children

proc `==`*(a, b: UserId): bool {.borrow.}
proc `<`*(a, b: UserId): bool {.borrow.}
proc `$`*(id: UserId): string =
  $int(id)

# Generic Result type helpers
proc ok*[T, E](value: T): Result[T, E] =
  Result[T, E](success: true, value: value)

proc err*[T, E](error: E): Result[T, E] =
  Result[T, E](success: false, error: error)

proc map*[T, U, E](r: Result[T, E], fn: proc(x: T): U): Result[U, E] =
  ## Map over successful result
  if r.success:
    ok[U, E](fn(r.value))
  else:
    err[U, E](r.error)

# Macros and meta-programming
import std/macros

macro makeStruct(name: untyped, fields: varargs[untyped]): untyped =
  ## Generate struct with fields
  result = quote:
    type `name` = object

  var recList = newNimNode(nnkRecList)
  for field in fields:
    let fieldName = field[0]
    let fieldType = field[1]
    recList.add(newIdentDefs(fieldName, fieldType))

  result[0][0][2] = newNimNode(nnkObjectTy).add(newEmptyNode(), newEmptyNode(), recList)

# Usage of macro
makeStruct(Point3D, (x, float), (y, float), (z, float))

# Template with generic parameters
template withTiming*[T](name: string, body: typed): T =
  ## Execute body and time it
  let start = cpuTime()
  let result = body
  let elapsed = cpuTime() - start
  echo fmt"{name} took {elapsed:.3f}s"
  result

# Procedural type
type
  Callback*[T] = proc(x: T): void {.closure.}
  Predicate*[T] = proc(x: T): bool {.closure.}

proc filter*[T](items: seq[T], pred: Predicate[T]): seq[T] =
  ## Filter sequence by predicate
  result = @[]
  for item in items:
    if pred(item):
      result.add(item)

proc forEach*[T](items: seq[T], callback: Callback[T]) =
  ## Execute callback for each item
  for item in items:
    callback(item)

# Generic constraints with multiple parameters
proc zip*[T, U](a: seq[T], b: seq[U]): seq[tuple[x: T, y: U]] =
  ## Zip two sequences together
  result = @[]
  let minLen = min(a.len, b.len)
  for i in 0 ..< minLen:
    result.add((a[i], b[i]))

# Object-oriented features
type
  Shape* = ref object of RootObj
    x*, y*: float

  Circle* = ref object of Shape
    radius*: float

  Rectangle* = ref object of Shape
    width*, height*: float

method area*(s: Shape): float {.base.} =
  ## Calculate area - base method
  0.0

method area*(c: Circle): float =
  ## Calculate circle area
  3.14159 * c.radius * c.radius

method area*(r: Rectangle): float =
  ## Calculate rectangle area
  r.width * r.height

method draw*(s: Shape) {.base.} =
  ## Draw shape - base method
  echo "Drawing shape at (", s.x, ", ", s.y, ")"

method draw*(c: Circle) =
  ## Draw circle
  echo fmt"Drawing circle at ({c.x}, {c.y}) with radius {c.radius}"

# Exception hierarchy
type
  AppError* = object of CatchableError
  NetworkError* = object of AppError
  DatabaseError* = object of AppError
  ValidationError* = object of AppError

proc validateUser*(email: Email): Result[UserId, ValidationError] =
  ## Validate user email
  let emailStr = string(email)
  if '@' notin emailStr:
    return err[UserId, ValidationError](ValidationError.newException("Invalid email"))
  ok[UserId, ValidationError](UserId(12345))

# Test runner
proc runAdvancedTests*() =
  ## Run advanced feature tests
  var tree: Tree[int]
  tree.insert(5)
  tree.insert(3)
  tree.insert(7)

  assert tree.find(5)
  assert tree.find(3)
  assert not tree.find(10)

  let circle = Circle(x: 0, y: 0, radius: 5)
  echo "Circle area: ", circle.area()
  circle.draw()

  let nums = @[1, 2, 3, 4, 5]
  let evens = nums.filter(
    proc(x: int): bool =
      x mod 2 == 0
  )
  echo "Even numbers: ", evens

when isMainModule:
  runAdvancedTests()
