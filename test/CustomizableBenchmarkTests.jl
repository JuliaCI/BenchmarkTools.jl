module CustomizableBenchmarkTests

using BenchmarkTools
using Test

x = Ref(0)
setup_prehook(_) = x[] += 1
prehook() = x[] += 1
posthook() = x[] += 1
function sample_result(_, setup_prehook_result, preehook_result, posthook_result)
    @test setup_prehook_result == 1
    @test preehook_result == 2
    @test posthook_result == 3
    @test x[] == 3
    return x[] += 1
end
function teardown_posthook(_, setup_prehook_result)
    @test setup_prehook_result == 1
    @test x[] == 4
    return x[] += 1
end

@testset "Disabled custom benchmarking" begin
    x[] = 0
    res = @benchmark nothing setup_prehook = setup_prehook prehook = prehook posthook =
        posthook sample_result = sample_result teardown_posthook = teardown_posthook run_customizable_func_only =
        false
    @test res.customizable_result === nothing
    @test !res.customizable_result_for_every_sample
end

@testset "custom benchmarking last" begin
    for run_customizable_func_only in (true, false)
        x[] = 0
        res = @benchmark nothing setup_prehook = setup_prehook prehook = prehook posthook =
            posthook sample_result = sample_result teardown_posthook = teardown_posthook enable_customizable_func =
            :LAST run_customizable_func_only = run_customizable_func_only
        if run_customizable_func_only
            @test isempty(res.times)
            @test isempty(res.gctimes)
            @test res.memory == typemax(Int)
            @test res.allocs == typemax(Int)
        end
        @test !res.customizable_result_for_every_sample
        @test res.customizable_result === 4
    end
end

@testset "custom benchmark every sample, independent of iterations" begin
    for run_customizable_func_only in (true, false)
        x[] = 0
        setup_prehook(_) = x[] = 1
        res = @benchmark nothing setup_prehook = setup_prehook prehook = prehook posthook =
            posthook sample_result = sample_result teardown_posthook = teardown_posthook enable_customizable_func =
            :ALL run_customizable_func_only = run_customizable_func_only samples = 1000
        if run_customizable_func_only
            @test isempty(res.times)
            @test isempty(res.gctimes)
            @test res.memory == typemax(Int)
            @test res.allocs == typemax(Int)
        end
        @test res.customizable_result_for_every_sample
        @test res.customizable_result == fill(4, 1000)
    end
end

@testset "custom benchmark every sample with iteration dependence" begin
    for run_customizable_func_only in (true, false)
        x[] = 0
        setup_prehook(_) = x[] += 1
        prehook() = x[] += 1
        posthook() = x[] += 1
        function sample_result(_, setup_prehook_result, preehook_result, posthook_result)
            return x[] += 1
        end
        function teardown_posthook(_, setup_prehook_result)
            return x[] += 1
        end
        res = @benchmark nothing setup_prehook = setup_prehook prehook = prehook posthook =
            posthook sample_result = sample_result teardown_posthook = teardown_posthook enable_customizable_func =
            :ALL run_customizable_func_only = run_customizable_func_only samples = 1000
        if run_customizable_func_only
            @test isempty(res.times)
            @test isempty(res.gctimes)
            @test res.memory == typemax(Int)
            @test res.allocs == typemax(Int)
        end
        @test res.customizable_result_for_every_sample
        @test res.customizable_result == collect(5 * (1:1000) .- 1)
    end
end

end # module
