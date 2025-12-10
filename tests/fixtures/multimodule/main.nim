#[**********************************************************************
*                    Test Fixture: Multi-Module Main                  *
**********************************************************************]#

## Main module for multi-module test project

import module_a, module_b
import std/strformat

proc main*() =
  ## Entry point for multi-module test
  echo "=== Multi-Module Test ==="

  # Use module_a functions
  let result1 = module_a.calculate(10, 20)
  echo fmt"Module A calculation: {result1}"

  let processor = module_a.createProcessor("test")
  echo fmt"Processor name: {processor.name}"

  # Use module_b functions
  let formatted = module_b.formatData("Hello, World!")
  echo fmt"Formatted: {formatted}"

  var storage = module_b.createStorage()
  storage.store("key1", "value1")
  echo fmt"Retrieved: {storage.retrieve('key1')}"

  # Cross-module usage
  let processed = processor.process(42)
  let final = formatData(processed)
  echo fmt"Final result: {final}"

when isMainModule:
  main()
