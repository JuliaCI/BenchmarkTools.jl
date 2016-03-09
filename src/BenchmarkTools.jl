module BenchmarkTools

using Compat

export execute,
       addgroup!,
       rmgroup!,
       @tagged,
       @benchmark,
       @benchmarkable,
       ideal,
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

loadplotting() = include(joinpath(Pkg.dir("BenchmarkTools"), "src", "plotting.jl"))

end # module BenchmarkTools
