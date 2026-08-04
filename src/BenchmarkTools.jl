module BenchmarkTools

using JSON
using Compat
using PrecompileTools: @compile_workload, @setup_workload

include("packagedef.jl")

end # module BenchmarkTools
