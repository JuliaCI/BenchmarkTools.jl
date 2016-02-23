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

# It seems that overloading showcompact for a new type on Julia v0.5 causes the default
# REPL representation to be the compact representation. This isn't really ideal, so instead,
# we overload and use the `compactshow` method where compact representation is needed.
compactshow(io::IO, x) = showcompact(io, x)

include("trials.jl")
include("collections.jl")
include("benchmarkable.jl")

end # module BenchmarkTools
