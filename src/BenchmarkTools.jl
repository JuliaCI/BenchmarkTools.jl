module BenchmarkTools

using Compat

export execute,
       addgroup!,
       rmgroup!,
       @tagged,
       @benchmark,
       @benchmarkable,
       minimum,
       GroupCollection,
       time,
       gctime,
       memory,
       allocs,
       fitness,
       ratio,
       judge,
       isinvariant,
       hasregression,
       hasimprovement,
       invariants,
       regressions,
       improvements

typealias Tag UTF8String

include("trials.jl")
include("collections.jl")
include("execution.jl")

loadplotting() = include(joinpath(Pkg.dir("BenchmarkTools"), "src", "plotting.jl"))

end # module BenchmarkTools
