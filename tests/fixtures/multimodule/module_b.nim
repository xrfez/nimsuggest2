#[**********************************************************************
*                  Test Fixture: Multi-Module Module B                *
**********************************************************************]#

## Module B - provides storage and formatting functions

import std/[tables, strformat, strutils]
export strformat # Re-export for testing export tracking

type
  Storage* = object
    data: Table[string, string]
    capacity: int

  FormatStyle* = enum
    fsPlain
    fsUpperCase
    fsLowerCase
    fsTitleCase

proc createStorage*(capacity: int = 100): Storage =
  ## Create new storage with capacity
  result.data = initTable[string, string]()
  result.capacity = capacity

proc store*(s: var Storage, key, value: string) =
  ## Store key-value pair
  if s.data.len < s.capacity:
    s.data[key] = value

proc retrieve*(s: Storage, key: string): string =
  ## Retrieve value by key
  if key in s.data:
    s.data[key]
  else:
    ""

proc formatData*(text: string, style: FormatStyle = fsPlain): string =
  ## Format text according to style
  case style
  of fsPlain:
    text
  of fsUpperCase:
    text.toUpperAscii()
  of fsLowerCase:
    text.toLowerAscii()
  of fsTitleCase:
    text.capitalizeAscii()

proc contains*(s: Storage, key: string): bool =
  ## Check if key exists in storage
  key in s.data

proc len*(s: Storage): int =
  ## Get number of items in storage
  s.data.len

# Template for common pattern
template withStorage*(s: var Storage, key: string, body: untyped) =
  ## Execute body with storage context
  if key notin s:
    s.store(key, "")
  body
