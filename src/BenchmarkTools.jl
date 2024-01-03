module BenchmarkTools

using JSON
using Base.Iterators

using Logging: @logmsg, LogLevel
using Statistics
using UUIDs: uuid4
using Printf
using Profile

const BENCHMARKTOOLS_VERSION = if VERSION >= v"1.9"
    pkgversion(BenchmarkTools)
else
    v"1.4.0"
end

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
    std,
    var,
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
    @benchmarkset,
    @case,
    clear_empty!

######################
# Execution Strategy #
######################

include("execution.jl")

export tune!, warmup, @ballocated, @benchmark, @benchmarkable, @belapsed, @btime, @bprofile

#################
# Serialization #
#################

include("serialization.jl")

end # module BenchmarkTools
