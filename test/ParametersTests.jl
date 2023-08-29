module ParametersTests

using Test
using BenchmarkTools
using BenchmarkTools: Parameters

@test BenchmarkTools.DEFAULT_PARAMETERS == Parameters()

p = Parameters(; seconds=1, gctrial=false)
oldseconds = BenchmarkTools.DEFAULT_PARAMETERS.seconds
oldgctrial = BenchmarkTools.DEFAULT_PARAMETERS.gctrial
BenchmarkTools.DEFAULT_PARAMETERS.seconds = p.seconds
BenchmarkTools.DEFAULT_PARAMETERS.gctrial = p.gctrial
@test p == Parameters()
@test Parameters(p; evals=3, time_tolerance=0.32) ==
    Parameters(; evals=3, time_tolerance=0.32)
BenchmarkTools.DEFAULT_PARAMETERS.seconds = oldseconds
BenchmarkTools.DEFAULT_PARAMETERS.gctrial = oldgctrial

p = Parameters(;
    seconds=1,
    gctrial=false,
    samples=2,
    evals=2,
    overhead=42,
    gcsample=false,
    time_tolerance=0.043,
    memory_tolerance=0.15,
)
oldseconds = BenchmarkTools.DEFAULT_PARAMETERS.seconds
oldgctrial = BenchmarkTools.DEFAULT_PARAMETERS.gctrial
old_time_tolerance = BenchmarkTools.DEFAULT_PARAMETERS.time_tolerance
old_memory_tolerance = BenchmarkTools.DEFAULT_PARAMETERS.memory_tolerance
oldsamples = BenchmarkTools.DEFAULT_PARAMETERS.samples
oldevals = BenchmarkTools.DEFAULT_PARAMETERS.evals
oldoverhead = BenchmarkTools.DEFAULT_PARAMETERS.overhead
oldgcsample = BenchmarkTools.DEFAULT_PARAMETERS.gcsample
BenchmarkTools.DEFAULT_PARAMETERS.seconds = p.seconds
BenchmarkTools.DEFAULT_PARAMETERS.gctrial = p.gctrial
BenchmarkTools.DEFAULT_PARAMETERS.time_tolerance = p.time_tolerance
BenchmarkTools.DEFAULT_PARAMETERS.memory_tolerance = p.memory_tolerance
BenchmarkTools.DEFAULT_PARAMETERS.samples = p.samples
BenchmarkTools.DEFAULT_PARAMETERS.evals = p.evals
BenchmarkTools.DEFAULT_PARAMETERS.overhead = p.overhead
BenchmarkTools.DEFAULT_PARAMETERS.gcsample = p.gcsample
@test p == Parameters()
@test p == Parameters(p)
BenchmarkTools.DEFAULT_PARAMETERS.seconds = oldseconds
BenchmarkTools.DEFAULT_PARAMETERS.gctrial = oldgctrial
BenchmarkTools.DEFAULT_PARAMETERS.time_tolerance = old_time_tolerance
BenchmarkTools.DEFAULT_PARAMETERS.memory_tolerance = old_memory_tolerance
BenchmarkTools.DEFAULT_PARAMETERS.samples = oldsamples
BenchmarkTools.DEFAULT_PARAMETERS.evals = oldevals
BenchmarkTools.DEFAULT_PARAMETERS.overhead = oldoverhead
BenchmarkTools.DEFAULT_PARAMETERS.gcsample = oldgcsample

end # module
