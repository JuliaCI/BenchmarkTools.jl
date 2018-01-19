# This file is a part of BenchmarkTools.jl. License is MIT

__precompile__()

module BenchmarkTools

using Compat
using JSON
using Base.Iterators

if VERSION >= v"0.7.0-DEV.3052"
    using Printf
end

const BENCHMARKTOOLS_VERSION = v"0.3.0"

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

#################
# Deprecations  #
#################
import Base: time
@deprecate time(t::Trial) realtime(t)
@deprecate time(t::TrialJudgement) realtime(t)
@deprecate time(t::TrialEstimate) realtime(t)
@deprecate time(t::TrialRatio) realtime(t)
@deprecate time(group::BenchmarkGroup) realtime(group)

end # module BenchmarkTools
