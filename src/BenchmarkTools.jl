module BenchmarkTools

using Compat
import JLD

# `show` compatibility for pre-JuliaLang/julia#16354 builds
if VERSION < v"0.5.0-dev+4305"
    Base.get(io::IO, setting::Symbol, default::Bool) = default
end

if VERSION >= v"0.6.0-dev.1015"
  using Base.Iterators
end

const BENCHMARKTOOLS_VERSION = v"0.0.6"

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
       @benchmarkable

##########################################
# Plotting Facilities (loaded on demand) #
##########################################

loadplotting() = include(joinpath(dirname(@__FILE__), "plotting.jl"))

#################
# Serialization #
#################

# Adds a compatibility fix for deserializing JLD files written with older versions of
# BenchmarkTools. Unfortunately, this use of JLD.translate encounters a weird scoping bug
# (see JuliaCI/BenchmarkTools.jl#23.). Even though it's currently unused, I've decided to
# leave this code in the source tree for the time being, with the hope that a fix for
# the scoping bug is pushed sometime soon.

# include("serialization.jl")

end # module BenchmarkTools
