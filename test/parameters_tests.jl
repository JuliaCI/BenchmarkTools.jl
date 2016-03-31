using Base.Test
using BenchmarkTools.Parameters

default = Parameters()
default.seconds = 1
default.gctrial = false
@test default == Parameters(seconds = 1, gctrial = false)
@test Parameters(default; evals = 3, tolerance = .32) == Parameters(seconds = 1, gctrial = false, evals = 3, tolerance = .32)

default = Parameters()
default.seconds = 1
default.gctrial = false
default.tolerance = 0.10
default.samples = 2
default.evals = 2
default.gcsample = false
@test default == Parameters(seconds = 1, gctrial = false, tolerance = 0.10,
                            samples = 2, evals = 2, gcsample = false)
@test Parameters(default) == default
