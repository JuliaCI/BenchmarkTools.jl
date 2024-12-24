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

f(x) = x
p = Parameters(;
    seconds=1,
    gctrial=false,
    samples=2,
    evals=2,
    overhead=42,
    gcsample=false,
    time_tolerance=0.043,
    memory_tolerance=0.15,
    # customizable Parameters
    run_customizable_func_only=true,
    enable_customizable_func=:ALL,
    customizable_gcsample=true,
    # customizable functions
    setup_prehook=f,
    teardown_posthook=f,
    sample_result=f,
)
oldseconds = BenchmarkTools.DEFAULT_PARAMETERS.seconds
oldgctrial = BenchmarkTools.DEFAULT_PARAMETERS.gctrial
old_time_tolerance = BenchmarkTools.DEFAULT_PARAMETERS.time_tolerance
old_memory_tolerance = BenchmarkTools.DEFAULT_PARAMETERS.memory_tolerance
oldsamples = BenchmarkTools.DEFAULT_PARAMETERS.samples
oldevals = BenchmarkTools.DEFAULT_PARAMETERS.evals
oldoverhead = BenchmarkTools.DEFAULT_PARAMETERS.overhead
oldgcsample = BenchmarkTools.DEFAULT_PARAMETERS.gcsample
old_run_customizable_func_only =
    BenchmarkTools.DEFAULT_PARAMETERS.run_customizable_func_only
old_enable_customizable_func = BenchmarkTools.DEFAULT_PARAMETERS.enable_customizable_func
old_customizable_gcsample = BenchmarkTools.DEFAULT_PARAMETERS.customizable_gcsample
old_setup_prehook = BenchmarkTools.DEFAULT_PARAMETERS.setup_prehook
old_teardown_posthook = BenchmarkTools.DEFAULT_PARAMETERS.teardown_posthook
old_sample_result = BenchmarkTools.DEFAULT_PARAMETERS.sample_result
old_prehook = BenchmarkTools.DEFAULT_PARAMETERS.prehook
old_posthook = BenchmarkTools.DEFAULT_PARAMETERS.posthook

BenchmarkTools.DEFAULT_PARAMETERS.seconds = p.seconds
BenchmarkTools.DEFAULT_PARAMETERS.gctrial = p.gctrial
BenchmarkTools.DEFAULT_PARAMETERS.time_tolerance = p.time_tolerance
BenchmarkTools.DEFAULT_PARAMETERS.memory_tolerance = p.memory_tolerance
BenchmarkTools.DEFAULT_PARAMETERS.samples = p.samples
BenchmarkTools.DEFAULT_PARAMETERS.evals = p.evals
BenchmarkTools.DEFAULT_PARAMETERS.overhead = p.overhead
BenchmarkTools.DEFAULT_PARAMETERS.gcsample = p.gcsample
BenchmarkTools.DEFAULT_PARAMETERS.run_customizable_func_only = p.run_customizable_func_only
BenchmarkTools.DEFAULT_PARAMETERS.enable_customizable_func = p.enable_customizable_func
BenchmarkTools.DEFAULT_PARAMETERS.customizable_gcsample = p.customizable_gcsample
BenchmarkTools.DEFAULT_PARAMETERS.setup_prehook = p.setup_prehook
BenchmarkTools.DEFAULT_PARAMETERS.teardown_posthook = p.teardown_posthook
BenchmarkTools.DEFAULT_PARAMETERS.sample_result = p.sample_result

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
BenchmarkTools.DEFAULT_PARAMETERS.run_customizable_func_only =
    old_run_customizable_func_only
BenchmarkTools.DEFAULT_PARAMETERS.enable_customizable_func = old_enable_customizable_func
BenchmarkTools.DEFAULT_PARAMETERS.customizable_gcsample = old_customizable_gcsample
BenchmarkTools.DEFAULT_PARAMETERS.setup_prehook = old_setup_prehook
BenchmarkTools.DEFAULT_PARAMETERS.teardown_posthook = old_teardown_posthook
BenchmarkTools.DEFAULT_PARAMETERS.sample_result = old_sample_result

for vals in (false, true, :ARST, :TRUE, :false, :ON)
    @test_throws ArgumentError Parameters(p; enable_customizable_func=vals)
    @test_throws ArgumentError Parameters(; enable_customizable_func=vals)
end

@test_throws ArgumentError Parameters(;
    enable_customizable_func=:FALSE, run_customizable_func_only=true
)
@test_nowarn Parameters(; enable_customizable_func=:FALSE, run_customizable_func_only=false)
for run_customizable_func_only in (false, true)
    @test_nowarn Parameters(;
        enable_customizable_func=:ALL, run_customizable_func_only=run_customizable_func_only
    )
    @test_nowarn Parameters(;
        enable_customizable_func=:LAST,
        run_customizable_func_only=run_customizable_func_only,
    )
end

end # module
