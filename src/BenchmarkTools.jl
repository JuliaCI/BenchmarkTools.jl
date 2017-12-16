__precompile__()

module BenchmarkTools

using Compat
using JSON
using Base.Iterators

if VERSION >= v"0.7.0-DEV.3052"
    using Printf
end

const BENCHMARKTOOLS_VERSION = v"0.2.2"

##########
# Timers #
##########

include("timers/timers.jl")

##############
# Parameters #
##############

include("parameters.jl")

export loadparams!

##############
# Trial Data #
##############

include("trials.jl")

export realtime,
       cputime,
       gctime,
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
