module ExecutionTests

using BenchmarkTools
using Test

seteq(a, b) = length(a) == length(b) == length(intersect(a, b))

#########
# setup #
#########

groups = BenchmarkGroup()
groups["sum"] = BenchmarkGroup(["arithmetic"])
groups["sin"] = BenchmarkGroup(["trig"])
groups["special"] = BenchmarkGroup()

sizes = (5, 10, 20)

for s in sizes
    A = rand(s, s)
    groups["sum"][s] = @benchmarkable sum($A) seconds=3
    groups["sin"][s] = @benchmarkable(sin($s), seconds=1, gctrial=false)
end

groups["special"]["macro"] = @benchmarkable @test(1 == 1)
groups["special"]["nothing"] = @benchmarkable nothing
groups["special"]["block"] = @benchmarkable begin rand(3) end
groups["special"]["comprehension"] = @benchmarkable [s^2 for s in sizes]

function testexpected(received::BenchmarkGroup, expected::BenchmarkGroup)
    @test length(received) == length(expected)
    @test seteq(received.tags, expected.tags)
    @test seteq(keys(received), keys(expected))
    for (k, v) in received
        testexpected(v, expected[k])
    end
end

function testexpected(trial::BenchmarkTools.Trial, args...)
    @test length(trial) > 1
end

testexpected(b::BenchmarkTools.Benchmark, args...) = true

#########
# tune! #
#########

oldgroups = copy(groups)

for id in keys(groups["special"])
    testexpected(tune!(groups["special"][id]))
end

testexpected(tune!(groups["sin"], verbose = true), groups["sin"])
testexpected(tune!(groups, verbose = true), groups)

oldgroupscopy = copy(oldgroups)

loadparams!(oldgroups, params(groups), :evals, :samples)
loadparams!(oldgroups, params(groups))

@test oldgroups == oldgroupscopy == groups

#######
# run #
#######

testexpected(run(groups; verbose = true), groups)
testexpected(run(groups; seconds = 1, verbose = true, gctrial = false), groups)
testexpected(run(groups; verbose = true, seconds = 1, gctrial = false, time_tolerance = 0.10, samples = 2, evals = 2, gcsample = false), groups)

testexpected(run(groups["sin"]; verbose = true), groups["sin"])
testexpected(run(groups["sin"]; seconds = 1, verbose = true, gctrial = false), groups["sin"])
testexpected(run(groups["sin"]; verbose = true, seconds = 1, gctrial = false, time_tolerance = 0.10, samples = 2, evals = 2, gcsample = false), groups["sin"])

testexpected(run(groups["sin"][first(sizes)]))
testexpected(run(groups["sin"][first(sizes)]; seconds = 1, gctrial = false))
testexpected(run(groups["sin"][first(sizes)]; seconds = 1, gctrial = false, time_tolerance = 0.10, samples = 2, evals = 2, gcsample = false))

testexpected(run(groups["sum"][first(sizes)], BenchmarkTools.DEFAULT_PARAMETERS))

###########
# warmup #
###########

p = params(warmup(@benchmarkable sin(1)))

@test p.samples == 1
@test p.evals == 1
@test p.gctrial == false
@test p.gcsample == false

##############
# @benchmark #
##############

mutable struct Foo
    x::Int
end

const foo = Foo(-1)

t = @benchmark sin(foo.x) evals=3 samples=10 setup=(foo.x = 0)

@test foo.x == 0
@test params(t).evals == 3
@test params(t).samples == 10

b = @benchmarkable sin(x) setup=(foo.x = -1; x = foo.x) teardown=(@assert(x == -1); foo.x = 1)
tune!(b)

@test foo.x == 1
@test params(b).evals > 100

foo.x = 0
tune!(b)

@test foo.x == 1
@test params(b).evals > 100

# test variable assignment with `@benchmark args...` form
@benchmark local_var="good" setup=(local_var="bad") teardown=(@test local_var=="good")
@test_throws UndefVarError local_var
@benchmark some_var="whatever" teardown=(@test_throws UndefVarError some_var)
@benchmark foo,bar="good","good" setup=(foo="bad"; bar="bad") teardown=(@test foo=="good" && bar=="good")

# test variable assignment with `@benchmark(args...)` form
@benchmark(local_var="good", setup=(local_var="bad"), teardown=(@test local_var=="good"))
@test_throws UndefVarError local_var
@benchmark(some_var="whatever", teardown=(@test_throws UndefVarError some_var))
@benchmark((foo,bar) = ("good","good"), setup=(foo = "bad"; bar = "bad"), teardown=(@test foo == "good" && bar == "good"))

# test kwargs separated by `,`
@benchmark(output=sin(x), setup=(x=1.0; output=0.0), teardown=(@test output == sin(x)))

########
# misc #
########

# This test is volatile in nonquiescent environments (e.g. Travis)
# BenchmarkTools.DEFAULT_PARAMETERS.overhead = BenchmarkTools.estimate_overhead()
# @test time(minimum(@benchmark nothing)) == 1

@test [:x, :y, :z, :v, :w] == BenchmarkTools.collectvars(quote
           x = 1 + 3
           y = 1 + x
           z = (a = 4; y + a)
           v,w = 1,2
           [u^2 for u in [1,2,3]]
       end)

# this should take < 1 s on any sane machine
@test @belapsed(sin($(foo.x)), evals=3, samples=10, setup=(foo.x = 0)) < 1
@test @belapsed(sin(0)) < 1

let fname = tempname()
    try
        ret = open(fname, "w") do f
            redirect_stdout(f) do
                x = 1
                a = nothing
                y = @btime(sin($x))
                @test y == sin(1)
                @test a === nothing
            end
        end
        s = read(fname, String)
        try
            @test occursin(r"[0-9.]+ \w*s \([0-9]* allocations?: [0-9]+ bytes\)", s)
        catch
            println(stderr, "@btime output didn't match ", repr(s))
            rethrow()
        end
    finally
        isfile(fname) && rm(fname)
    end
end

# issue #107
let time = 2
    @benchmark identity(time)
end

end # module
