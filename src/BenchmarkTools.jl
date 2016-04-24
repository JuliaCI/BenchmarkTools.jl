module BenchmarkTools

using Compat

# Used to patch showcompact compatibility between v0.4 and v0.5.
# We can't just define something like
#
#   Base.showcompact(io, x) = show(IOContext(io, limit_output = true), x)
#
# because showcompact then gets used by default by the REPL display methods,
# which is pretty annoying.
if VERSION < v"0.5-"
    limit_output(io) = false
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

##########################################
# Plotting Facilities (loaded on demand) #
##########################################

loadplotting() = include(joinpath(Pkg.dir("BenchmarkTools"), "src", "plotting.jl"))

end # module BenchmarkTools
