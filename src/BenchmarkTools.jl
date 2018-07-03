__precompile__()

module BenchmarkTools

using Compat
using JSON
using Base.Iterators

if VERSION >= v"0.7.0-beta.85"
    import Statistics: mean, median
else
    import Base: mean, median
end

using Compat.Printf


const BENCHMARKTOOLS_VERSION = v"0.2.2"

##############
# Parameters #
##############

include("parameters.jl")

export loadparams!

##############
# Trial Data #
##############

include("trials.jl")

export gctime,
       memory,
       allocs,
       params,
       ratio,
       judge,
       isinvariant,
       isregression,
       isimprovement,
       rmskew!,
       rmskew,
       trim

##################
# Benchmark Data #
##################

include("groups.jl")

export BenchmarkGroup,
       invariants,
       regressions,
       improvements,
       @tagged,
       addgroup!,
       leaves

######################
# Execution Strategy #
######################

include("execution.jl")

export tune!,
       warmup,
       @benchmark,
       @benchmarkable,
       @belapsed,
       @btime

#################
# Serialization #
#################

include("serialization.jl")

end # module BenchmarkTools
