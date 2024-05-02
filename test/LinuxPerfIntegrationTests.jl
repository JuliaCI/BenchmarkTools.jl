module LinuxPerfIntegrationTests

using BenchmarkTools
using Test
using LinuxPerf

### Serialization Test ###
b = @benchmarkable sin(1) enable_linux_perf = true
tune!(b)
bb = run(b)

withtempdir() do
    tmp = joinpath(pwd(), "tmp.json")

    BenchmarkTools.save(tmp, b.params, bb)
    @test isfile(tmp)

    results = BenchmarkTools.load(tmp)
    @test results isa Vector{Any}
    @test length(results) == 2
    @test eq(results[1], b.params)
    @test eq(results[2], bb)
end

##################################
# Linux Perf Integration #
##################################

b = @benchmarkable sin($(Ref(42.0))[])
results = run(b; seconds=1, enable_linux_perf=false)
@test results.linux_perf_stats === nothing

b = @benchmarkable sin($(Ref(42.0))[])
results = run(b; seconds=1)
@test results.linux_perf_stats === nothing

b = @benchmarkable sin($(Ref(42.0))[])
results = run(b; seconds=1, enable_linux_perf=true, evals=10^3)
@test results.linux_perf_stats !== nothing
@test any(results.linux_perf_stats.threads) do thread
    instructions = LinuxPerf.scaledcount(thread["instructions"])
    !isnan(instructions) && instructions > 10^4
end

tune!(groups)
results = run(groups; enable_linux_perf=true)
for (name, group_results) in BenchmarkTools.leaves(results)
    @test group_results.linux_perf_stats !== nothing
    @test any(group_results.linux_perf_stats.threads) do thread
        instructions = LinuxPerf.scaledcount(thread["instructions"])
        !isnan(instructions) && instructions > 10^3
    end
end

end
