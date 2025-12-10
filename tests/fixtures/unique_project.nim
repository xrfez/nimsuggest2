## Test project that imports unique modules for comprehensive testing

import unique_module_a
import unique_module_b

# Test usage of unique symbols from module A
let alpha = UniqueTypeAlpha(fieldAlpha: "test", fieldBeta: UNIQUE_CONSTANT_ALPHA)
let resultAlpha = uniqueProcAlpha("hello")
let resultBeta = uniqueProcBeta(10)
echo uniqueVarAlpha

# Test usage of unique symbols from module B
let gamma = UniqueTypeGamma(fieldGamma: 3.14, relatedAlpha: alpha)
let resultGamma = uniqueProcGamma(2.5)
let resultDelta = uniqueProcDelta("world")
useModuleASymbols()

echo "Unique project loaded successfully"
