module BenchmarkTools

using Compat

export execute,
       warmup,
       addgroup!,
       rmgroup!,
       @tagged,
       @benchmark,
       @benchmarkable,
       time,
       gctime,
       memory,
       allocs,
       ratio,
       judge,
       hasregression,
       hasimprovement,
       changes

typealias Tag UTF8String

include("trials.jl")
include("collections.jl")
include("execution.jl")
include("analysis.jl")

end # module BenchmarkTools
