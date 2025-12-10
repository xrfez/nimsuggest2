## Module A - Contains unique symbols for comprehensive testing

import std/strutils

type UniqueTypeAlpha* = object ## A unique type defined only in module A
  fieldAlpha*: string
  fieldBeta*: int

const
  UNIQUE_CONSTANT_ALPHA* = 42
  ## A unique constant only in module A

proc uniqueProcAlpha*(input: string): string =
  ## A unique procedure only in module A
  ## This should appear exactly once in the project
  result = "Alpha: " & input.toUpper()

proc uniqueProcBeta*(x: int): int =
  ## Another unique procedure in module A
  ## Used to test finding definitions across modules
  result = x * UNIQUE_CONSTANT_ALPHA

var uniqueVarAlpha* = "Module A Variable" ## A unique variable exported from module A
