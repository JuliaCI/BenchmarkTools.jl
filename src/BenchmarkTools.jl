module BenchmarkTools

import JSON

import Compat.String
using Compat

##############
# versioning #
##############

# keep this updated; it's necessary for versioned serialization
const BENCHMARKTOOLS_VERSION = v"0.0.3"

# `show` compatibility for pre-JuliaLang/julia#16354 builds
if VERSION < v"0.5.0-dev+4305"
    Base.get(io::IO, setting::Symbol, default::Bool) = default
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

#####################
# Save/Load Methods #
#####################

include("serialization.jl")

##########################################
# Plotting Facilities (loaded on demand) #
##########################################

loadplotting() = include(joinpath(dirname(@__FILE__), "plotting.jl"))

end # module BenchmarkTools
