## Module B - Contains unique symbols and imports from module A

import unique_module_a

type UniqueTypeGamma* = object ## A unique type defined only in module B
  fieldGamma*: float
  relatedAlpha*: UniqueTypeAlpha # References type from module A

const
  UNIQUE_CONSTANT_GAMMA* = 99
  ## A unique constant only in module B

proc uniqueProcGamma*(value: float): float =
  ## A unique procedure only in module B
  ## References module A's constant
  result = value + float(UNIQUE_CONSTANT_ALPHA)

proc uniqueProcDelta*(text: string): string =
  ## Another unique procedure in module B
  ## Calls procedure from module A
  result = uniqueProcAlpha(text) & " + Delta"

proc useModuleASymbols*(): void =
  ## Tests cross-module symbol usage
  let alpha = UniqueTypeAlpha(fieldAlpha: "test", fieldBeta: 10)
  let processed = uniqueProcBeta(5)
  echo uniqueVarAlpha
