module BenchmarkTools

using JSON
using Base.Iterators

using Logging: @logmsg, LogLevel
using Statistics
using UUIDs: uuid4
using Printf


const BENCHMARKTOOLS_VERSION = v"0.4.3"

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
       median,
       mean,
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
       @ballocated,
       @benchmark,
       @benchmarkable,
       @belapsed,
       @btime

#################
# Serialization #
#################

include("serialization.jl")

end # module BenchmarkTools
