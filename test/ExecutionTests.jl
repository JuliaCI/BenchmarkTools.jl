module ExecutionTests

using BenchmarkTools
using Profile
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
    groups["sum"][s] = @benchmarkable sum($A) seconds = 3
    groups["sin"][s] = @benchmarkable(sin($s), seconds = 1, gctrial = false)
end

groups["special"]["macro"] = @benchmarkable @test(1 == 1)
groups["special"]["nothing"] = @benchmarkable nothing
groups["special"]["block"] = @benchmarkable begin
    rand(3)
end
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

testexpected(tune!(groups["sin"]; verbose=true), groups["sin"])
testexpected(tune!(groups; verbose=true), groups)

oldgroupscopy = copy(oldgroups)

loadparams!(oldgroups, params(groups), :evals, :samples)
loadparams!(oldgroups, params(groups))

@test oldgroups == oldgroupscopy == groups

# Explicitly set evals should not get tuned

b = @benchmarkable sin(1) evals = 1
tune!(b)
@test params(b).evals == 1

b = @benchmarkable sin(1) evals = 10
tune!(b)
@test params(b).evals == 10

function test_length_and_push!(x::AbstractVector)
    length(x) == 2 || error("setup not correctly executed")
    return push!(x, randn())
end

b_fail = @benchmarkable test_length_and_push!(y) setup = (y = randn(2))
@test_throws Exception tune!(b_fail)

b_pass = @benchmarkable test_length_and_push!(y) setup = (y = randn(2)) evals = 1
@test tune!(b_pass) isa BenchmarkTools.Benchmark

#######
# run #
#######

testexpected(run(groups; verbose=true), groups)
testexpected(run(groups; seconds=1, verbose=true, gctrial=false), groups)
testexpected(
    run(
        groups;
        verbose=true,
        seconds=1,
        gctrial=false,
        time_tolerance=0.10,
        samples=2,
        evals=2,
        gcsample=false,
    ),
    groups,
)

testexpected(run(groups["sin"]; verbose=true), groups["sin"])
testexpected(run(groups["sin"]; seconds=1, verbose=true, gctrial=false), groups["sin"])
testexpected(
    run(
        groups["sin"];
        verbose=true,
        seconds=1,
        gctrial=false,
        time_tolerance=0.10,
        samples=2,
        evals=2,
        gcsample=false,
    ),
    groups["sin"],
)

testexpected(run(groups["sin"][first(sizes)]))
testexpected(run(groups["sin"][first(sizes)]; seconds=1, gctrial=false))
testexpected(
    run(
        groups["sin"][first(sizes)];
        seconds=1,
        gctrial=false,
        time_tolerance=0.10,
        samples=2,
        evals=2,
        gcsample=false,
    ),
)

testexpected(run(groups["sum"][first(sizes)], BenchmarkTools.DEFAULT_PARAMETERS))

# Mutating benchmark

b_pass = @benchmarkable test_length_and_push!(y) setup = (y = randn(2)) evals = 1
tune!(b_pass)
@test run(b_pass) isa BenchmarkTools.Trial

###########
# warmup #
###########

@test_deprecated warmup(@benchmarkable sin(1))

is_warm = false
function needs_warm()
    global is_warm
    if is_warm
        sleep(0.1)
    else
        sleep(2)
        is_warm = true
    end
end

w = @benchmarkable needs_warm()
w.params.seconds = 1

#test that all measurements from lineartrial used in tune! are warm
is_warm = false
@test maximum(BenchmarkTools.lineartrial(w, w.params)) < 1e9

#test that run warms up the benchmark
tune!(w)
is_warm = false
@test minimum(run(w).times) < 1e9

#test that belapsed warms up the benchmark
is_warm = false
@test (@belapsed needs_warm() seconds = 1) < 1

#test that belapsed warms up the benchmark even when evals are set
is_warm = false
@test (@belapsed needs_warm() seconds = 1 evals = 1) < 1

##############
# @benchmark #
##############

mutable struct Foo
    x::Int
end

const foo = Foo(-1)

t = @benchmark sin(foo.x) evals = 3 samples = 10 setup = (foo.x = 0)

@test foo.x == 0
@test params(t).evals == 3
@test params(t).samples == 10

b = @benchmarkable sin(x) setup = (foo.x = -1; x = foo.x) teardown = (
    @assert(x == -1); foo.x = 1
)
tune!(b)

@test foo.x == 1
@test params(b).evals > 100

foo.x = 0
tune!(b)

@test foo.x == 1
@test params(b).evals > 100

# test variable assignment with `@benchmark args...` form
@benchmark local_var = "good" setup = (local_var = "bad") teardown = (@test local_var ==
    "good")
@test_throws UndefVarError local_var
@benchmark some_var = "whatever" teardown = (@test_throws UndefVarError some_var)
@benchmark foo, bar = "good", "good" setup = (foo = "bad"; bar = "bad") teardown = (@test foo ==
                                                                                          "good" &&
    bar ==
                                                                                          "good")

# test variable assignment with `@benchmark(args...)` form
@benchmark(
    local_var = "good", setup = (local_var = "bad"), teardown = (@test local_var == "good")
)
@test_throws UndefVarError local_var
@benchmark(some_var = "whatever", teardown = (@test_throws UndefVarError some_var))
@benchmark(
    (foo, bar) = ("good", "good"),
    setup = (foo = "bad"; bar = "bad"),
    teardown = (@test foo == "good" && bar == "good")
)

# test kwargs separated by `,`
@benchmark(
    output = sin(x), setup = (x = 1.0; output = 0.0), teardown = (@test output == sin(x))
)

for (tf, rex1, rex2) in (
    (false, r"0.5 ns +Histogram: frequency by time +8 ns", r"Histogram: frequency"),
    (
        true,
        r"0.5 ns +Histogram: log\(frequency\) by time +8 ns",
        r"Histogram: log\(frequency\)",
    ),
)
    io = IOBuffer()
    ioctx = IOContext(io, :histmin => 0.5, :histmax => 8, :logbins => tf)
    @show tf
    b = @benchmark x^3 setup = (x = rand())
    show(ioctx, MIME("text/plain"), b)
    b = @benchmark x^3.0 setup = (x = rand())
    show(ioctx, MIME("text/plain"), b)
    str = String(take!(io))
    idx = findfirst(rex1, str)
    @test isa(idx, UnitRange)
    idx = findnext(rex1, str, idx[end] + 1)
    @test isa(idx, UnitRange)
    ioctx = IOContext(io, :logbins => tf)
    # A flat distribution won't trigger log by default
    b = BenchmarkTools.Trial(
        BenchmarkTools.DEFAULT_PARAMETERS, 0.001 * (1:100) * 1e9, zeros(100), 0, 0
    )
    show(ioctx, MIME("text/plain"), b)
    str = String(take!(io))
    idx = findfirst(rex2, str)
    @test isa(idx, UnitRange)
    # A peaked distribution will trigger log by default
    t = [fill(1, 21); 2]
    b = BenchmarkTools.Trial(
        BenchmarkTools.DEFAULT_PARAMETERS,
        t / sum(t) * 1e9 * BenchmarkTools.DEFAULT_PARAMETERS.seconds,
        zeros(100),
        0,
        0,
    )
    show(ioctx, MIME("text/plain"), b)
    str = String(take!(io))
    idx = findfirst(rex2, str)
    @test isa(idx, UnitRange)
end

#############
# @bprofile #
#############

function likegcd(a::T, b::T) where {T<:Base.BitInteger}
    za = trailing_zeros(a)
    zb = trailing_zeros(b)
    k = min(za, zb)
    u = unsigned(abs(a >> za))
    v = unsigned(abs(b >> zb))
    while u != v
        if u > v
            u, v = v, u
        end
        v -= u
        v >>= trailing_zeros(v)
    end
    r = u << k
    return r % T
end

b = @bprofile likegcd(x, y) setup = (x = rand(2:200); y = rand(2:200))
@test isa(b, BenchmarkTools.Trial)
io = IOBuffer()
Profile.print(IOContext(io, :displaysize => (24, 200)))
str = String(take!(io))
@test occursin(r"BenchmarkTools(\.jl)?(/|\\)src(/|\\)execution\.jl:\d+; #?_run", str)
@test !occursin(r"BenchmarkTools(\.jl)?(/|\\)src(/|\\)execution\.jl:\d+; #?tune!", str)
b = @bprofile 1 + 1
Profile.print(IOContext(io, :displaysize => (24, 200)))
str = String(take!(io))
@test !occursin("gcscrub", str)
b = @bprofile 1 + 1 gctrial = true
Profile.print(IOContext(io, :displaysize => (24, 200)))
str = String(take!(io))
@test occursin("gcscrub", str)

########
# misc #
########

# This test is volatile in nonquiescent environments (e.g. Travis)
# BenchmarkTools.DEFAULT_PARAMETERS.overhead = BenchmarkTools.estimate_overhead()
# @test time(minimum(@benchmark nothing)) == 1

@test [:x, :y, :z, :v, :w] == BenchmarkTools.collectvars(
    quote
        x = 1 + 3
        y = 1 + x
        z = (a = 4; y + a)
        v, w = 1, 2
        [u^2 for u in [1, 2, 3]]
    end,
)

# this should take < 1 s on any sane machine
@test @belapsed(sin($(foo.x)), evals = 3, samples = 10, setup = (foo.x = 0)) < 1
@test @belapsed(sin(0)) < 1

@test @ballocated(sin($(foo.x)), evals = 3, samples = 10, setup = (foo.x = 0)) == 0
@test @ballocated(sin(0)) == 0
@test @ballocated(Ref(1)) == 2 * sizeof(Int)  # 1 for the pointer, 1 for content

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

# Ensure that interpolated values are garbage-collectable
x = []
x_finalized = false
finalizer(x -> (global x_finalized = true), x)
b = @benchmarkable $x
b = x = nothing
GC.gc()
@test x_finalized

end # module
