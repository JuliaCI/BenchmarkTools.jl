using Base.Test
using BenchmarkTools
using BenchmarkTools: BenchmarkGroup

seteq(a, b) = length(a) == length(b) == length(intersect(a, b))

groups = BenchmarkTools.GroupCollection()

addgroup!(groups, "sum", ["arithmetic"])
addgroup!(groups, "sin", ["trig"])
addgroup!(groups, "special", [])

ns = (5, 10, 20)

for n in ns
    A = rand(n, n)
    groups["sum"][n] = @benchmarkable sum($A) 3
    groups["sin"][n] = @benchmarkable sin($n) 1 false
end

groups["special"]["macro"] = @benchmarkable @test(1 == 1) 1
groups["special"]["kwargs"] = @benchmarkable svds(rand(2, 2), nsv = 1) 2
groups["special"]["nothing"] = @benchmarkable nothing
groups["special"]["comprehension"] = @benchmarkable [n^2 for n in ns] 0.5

###########
# execute #
###########

function is_expected_output(out::GroupCollection, groups::GroupCollection)
    @test length(out) == length(groups)
    @test seteq(keys(out), keys(groups))
    for g in out
        @test is_expected_output(g, groups[g.id])
    end
    return true
end

function is_expected_output(out::BenchmarkGroup, group::BenchmarkGroup)
    @test out.id == group.id
    @test seteq(out.tags, group.tags)
    @test seteq(keys(out), keys(group))
    for k in keys(out)
        try
            t = out[k]
            @test typeof(t) == BenchmarkTools.Trial
            @test is_expected_output(t)
        catch err
            println("ERROR IN GROUP ", repr(group.id), " WITH KEY ", repr(k), ":")
            throw(err)
        end
    end
    return true
end

function is_expected_output(out::BenchmarkTools.Trial)
    @test length(out) > 1
    @test time(judge(linreg(out), minimum(out), 0.3)) == :invariant
    @test all([(out.evals[i] - out.evals[i-1]) > 0 for i in 2:length(out.evals)])
    return true
end

execute(groups, 1e-3, false; verbose = true) # warmup

@test is_expected_output(execute(groups; verbose = true), groups)
@test is_expected_output(execute(groups, 1; verbose = true), groups)
@test is_expected_output(execute(groups, 1, false; verbose = true), groups)

@test is_expected_output(execute(groups["sin"]; verbose = true), groups["sin"])
@test is_expected_output(execute(groups["sin"], 1; verbose = true), groups["sin"])
@test is_expected_output(execute(groups["sin"], 1, false; verbose = true), groups["sin"])

@test is_expected_output(execute(groups["sin"][first(ns)]))
@test is_expected_output(execute(groups["sin"][first(ns)], 1))
@test is_expected_output(execute(groups["sin"][first(ns)], 1, false))

#####################
# consistency check #
#####################

t = execute(groups["sin"][first(ns)], 0.5, true)
t2 = @benchmark sin($(first(ns))) 0.5

jmin = judge(minimum(t), minimum(t2), 0.1)
jlr = judge(linreg(t), linreg(t2), 0.1)

@test all(rsqr -> rsqr >= 0.85, fitness(linreg(t)))
@test isinvariant(jmin)
@test isinvariant(jlr)
