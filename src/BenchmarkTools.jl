module BenchmarkTools

using Compat

typealias Tag UTF8String

##############
# Parameters #
##############

include("parameters.jl")

##############
# Trial Data #
##############

include("trials.jl")

export gctime,
       memory,
       allocs,
       tolerance,
       parameters,
       ratio,
       judge,
       isinvariant,
       isregression,
       isimprovement,
       rmskew!,
       rmskew

##################
# Benchmark Data #
##################

include("groups.jl")

export BenchmarkGroup,
       invariants,
       regressions,
       improvements,
       @tagged,
       loadparams!

######################
# Execution Strategy #
######################

include("execution.jl")

export tune!,
       @benchmark,
       @benchmarkable

##########################################
# Plotting Facilities (loaded on demand) #
##########################################

loadplotting() = include(joinpath(Pkg.dir("BenchmarkTools"), "src", "plotting.jl"))

end # module BenchmarkTools
