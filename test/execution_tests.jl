using Base.Test
using BenchmarkTools

seteq(a, b) = length(a) == length(b) == length(intersect(a, b))

#########
# setup #
#########

groups = BenchmarkGroup()
groups["sum"] = BenchmarkGroup("arithmetic")
groups["sin"] = BenchmarkGroup("trig")
groups["special"] = BenchmarkGroup()

sizes = (5, 10, 20)

for s in sizes
    A = rand(s, s)
    groups["sum"][s] = @benchmarkable sum($A) seconds=3
    groups["sin"][s] = @benchmarkable sin($s) seconds=1 gctrial=false
end

groups["special"]["macro"] = @benchmarkable @test(1 == 1)
groups["special"]["kwargs"] = @benchmarkable svds(rand(2, 2), nsv = 1)
groups["special"]["nothing"] = @benchmarkable nothing
groups["special"]["block"] = @benchmarkable begin rand(3) end
groups["special"]["comprehension"] = @benchmarkable [s^2 for s in sizes]

function isexpected(received::BenchmarkGroup, expected::BenchmarkGroup)
    @test length(received) == length(expected)
    @test seteq(received.tags, expected.tags)
    @test seteq(keys(received), keys(expected))
    for (k, v) in received
        isexpected(v, expected[k])
    end
    return true
end

function isexpected(trial::BenchmarkTools.Trial, args...)
    @test length(trial) > 1
    return true
end

function isexpected(b::BenchmarkTools.Benchmark, args...)
    @test b.params != BenchmarkTools.Parameters()
    return true
end

#########
# tune! #
#########

oldgroups = copy(groups)

for id in keys(groups["special"])
    @test isexpected(tune!(groups["special"][id]))
end

@test isexpected(tune!(groups["sin"], verbose = true), groups["sin"])
@test isexpected(tune!(groups, verbose = true), groups)

loadparams!(oldgroups, parameters(groups))

@test oldgroups == groups

#######
# run #
#######

@test isexpected(run(groups; verbose = true), groups)
@test isexpected(run(groups; seconds = 1, verbose = true, gctrial = false), groups)
@test isexpected(run(groups; verbose = true, seconds = 1, gctrial = false, tolerance = 0.10, samples = 2, evals = 2, gcsample = false), groups)

@test isexpected(run(groups["sin"]; verbose = true), groups["sin"])
@test isexpected(run(groups["sin"]; seconds = 1, verbose = true, gctrial = false), groups["sin"])
@test isexpected(run(groups["sin"]; verbose = true, seconds = 1, gctrial = false, tolerance = 0.10, samples = 2, evals = 2, gcsample = false), groups["sin"])

@test isexpected(run(groups["sin"][first(sizes)]))
@test isexpected(run(groups["sin"][first(sizes)]; seconds = 1, gctrial = false))
@test isexpected(run(groups["sin"][first(sizes)]; seconds = 1, gctrial = false, tolerance = 0.10, samples = 2, evals = 2, gcsample = false))
