module BenchmarkTools

using Compat
import JLD

# `show` compatibility for pre-JuliaLang/julia#16354 builds
if VERSION < v"0.5.0-dev+4305"
    Base.get(io::IO, setting::Symbol, default::Bool) = default
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

include("serialization.jl")

end # module BenchmarkTools
