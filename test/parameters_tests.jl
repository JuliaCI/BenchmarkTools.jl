using Base.Test
using BenchmarkTools.Parameters

@test BenchmarkTools.DEFAULT_PARAMETERS == Parameters()

params = Parameters(seconds = 1, gctrial = false)
oldseconds = BenchmarkTools.DEFAULT_PARAMETERS.seconds
oldgctrial = BenchmarkTools.DEFAULT_PARAMETERS.gctrial
BenchmarkTools.DEFAULT_PARAMETERS.seconds = params.seconds
BenchmarkTools.DEFAULT_PARAMETERS.gctrial = params.gctrial
@test params == Parameters()
@test Parameters(params; evals = 3, tolerance = .32) == Parameters(evals = 3, tolerance = .32)
BenchmarkTools.DEFAULT_PARAMETERS.seconds = oldseconds
BenchmarkTools.DEFAULT_PARAMETERS.gctrial = oldgctrial

params =  Parameters(seconds = 1, gctrial = false, tolerance = 0.10,
                     samples = 2, evals = 2, gcsample = false)
oldseconds = BenchmarkTools.DEFAULT_PARAMETERS.seconds
oldgctrial = BenchmarkTools.DEFAULT_PARAMETERS.gctrial
oldtolerance = BenchmarkTools.DEFAULT_PARAMETERS.tolerance
oldsamples = BenchmarkTools.DEFAULT_PARAMETERS.samples
oldevals = BenchmarkTools.DEFAULT_PARAMETERS.evals
oldgcsample = BenchmarkTools.DEFAULT_PARAMETERS.gcsample
BenchmarkTools.DEFAULT_PARAMETERS.seconds = params.seconds
BenchmarkTools.DEFAULT_PARAMETERS.gctrial = params.gctrial
BenchmarkTools.DEFAULT_PARAMETERS.tolerance = params.tolerance
BenchmarkTools.DEFAULT_PARAMETERS.samples = params.samples
BenchmarkTools.DEFAULT_PARAMETERS.evals = params.evals
BenchmarkTools.DEFAULT_PARAMETERS.gcsample = params.gcsample
@test params == Parameters()
@test params == Parameters(params)
BenchmarkTools.DEFAULT_PARAMETERS.seconds = oldseconds
BenchmarkTools.DEFAULT_PARAMETERS.gctrial = oldgctrial
BenchmarkTools.DEFAULT_PARAMETERS.tolerance = oldtolerance
BenchmarkTools.DEFAULT_PARAMETERS.samples = oldsamples
BenchmarkTools.DEFAULT_PARAMETERS.evals = oldevals
BenchmarkTools.DEFAULT_PARAMETERS.gcsample = oldgcsample
