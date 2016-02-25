module BenchmarkTools

using Compat

export BenchmarkEnsemble,
       execute,
       ntrials,
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
       regressions,
       improvements

typealias Tag UTF8String

include("trials.jl")
include("benchmarkable.jl")
include("collections.jl")
include("execution.jl")
include("analysis.jl")

end # module BenchmarkTools
