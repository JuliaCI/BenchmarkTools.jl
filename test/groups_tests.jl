using Base.Test
using BenchmarkTools
using BenchmarkTools: TrialEstimate

seteq(a, b) = length(a) == length(b) == length(intersect(a, b))

##################
# BenchmarkGroup #
##################

# setup #
#-------#

g1 = BenchmarkGroup("1", "2")

t1a = TrialEstimate(32, 1, 2, 3, .05)
t1b = TrialEstimate(4123, 123, 43, 9, .4)
tc = TrialEstimate(1, 1, 1, 1, 1)

g1["a"] = t1a
g1["b"] = t1b
g1["c"] = tc

g1copy = copy(g1)
g1similar = similar(g1)

g2 = BenchmarkGroup("2", "3")

t2a = TrialEstimate(323, 1, 2, 3, .05)
t2b = TrialEstimate(1002, 123, 43, 9, .4)

g2["a"] = t2a
g2["b"] = t2b
g2["c"] = tc

trial = BenchmarkTools.Trial(BenchmarkTools.Parameters(), [1, 2, 5], [0, 1, 1], 3, 56)

gtrial = BenchmarkGroup([], Dict("t" => trial))

# tests #
#-------#

@test BenchmarkGroup() == BenchmarkGroup([], Dict())
@test length(g1) == 3
@test g1["a"] == t1a
@test g1["b"] == t1b
@test g1["c"] == tc
@test haskey(g1, "a")
@test !(haskey(g1, "x"))
@test seteq(keys(g1), ["a", "b", "c"])
@test seteq(values(g1), [t1a, t1b, tc])
@test start(g1) == start(g1.data)
@test next(g1, start(g1)) == next(g1.data, start(g1))
@test done(g1, start(g1)) == done(g1.data, start(g1))
@test seteq([x for x in g1], Pair["a"=>t1a, "b"=>t1b, "c"=>tc])

@test g1 == g1copy
@test seteq(keys(delete!(g1copy, "a")), ["b", "c"])
@test isempty(delete!(delete!(g1copy, "b"), "c"))
@test isempty(g1similar)
@test g1similar.tags == g1.tags

@test time(g1).data == Dict("a" => time(t1a), "b" => time(t1b), "c" => time(tc))
@test gctime(g1).data == Dict("a" => gctime(t1a), "b" => gctime(t1b), "c" => gctime(tc))
@test memory(g1).data == Dict("a" => memory(t1a), "b" => memory(t1b), "c" => memory(tc))
@test allocs(g1).data == Dict("a" => allocs(t1a), "b" => allocs(t1b), "c" => allocs(tc))
@test tolerance(g1).data == Dict("a" => tolerance(t1a), "b" => tolerance(t1b), "c" => tolerance(tc))

@test max(g1, g2).data == Dict("a" => t2a, "b" => t1b, "c" => tc)
@test min(g1, g2).data == Dict("a" => t1a, "b" => t2b, "c" => tc)
@test ratio(g1, g2).data == Dict("a" => ratio(t1a, t2a), "b" => ratio(t1b, t2b), "c" => ratio(tc, tc))
@test judge(g1, g2, 0.1).data == Dict("a" => judge(t1a, t2a, 0.1), "b" => judge(t1b, t2b, 0.1), "c" => judge(tc, tc, 0.1))
@test judge(ratio(g1, g2), 0.1) == judge(g1, g2, 0.1)
@test ratio(g1, g2) == ratio(judge(g1, g2, 0.1))

@test isinvariant(judge(g1, g1))
@test !(isinvariant(judge(g1, g2)))
@test isregression(judge(g1, g2))
@test !(isregression(judge(g1, g1)))
@test isimprovement(judge(g1, g2))
@test !(isimprovement(judge(g1, g1)))
@test invariants(judge(g1, g2)).data == Dict("c" => judge(tc, tc))
@test regressions(judge(g1, g2)).data == Dict("b" => judge(t1b, t2b))
@test improvements(judge(g1, g2)).data == Dict("a" => judge(t1a, t2a))

@test minimum(gtrial)["t"] == minimum(gtrial["t"])
@test median(gtrial)["t"] == median(gtrial["t"])
@test mean(gtrial)["t"] == mean(gtrial["t"])
@test maximum(gtrial)["t"] == maximum(gtrial["t"])

######################################
# BenchmarkGroups of BenchmarkGroups #
######################################

# setup #
#-------#

groupsa = BenchmarkGroup()
groupsa["g1"] = g1
groupsa["g2"] = g2
g3a = BenchmarkGroup("3", "4")
groupsa["g3"] = g3a
g3a["c"] = TrialEstimate(6341, 23, 41, 536, .05)
g3a["d"] = TrialEstimate(12341, 3013, 2, 150, .13)

groups_copy = copy(groupsa)
groups_similar = similar(groupsa)

groupsb = BenchmarkGroup()
groupsb["g1"] = g1
groupsb["g2"] = g2
g3b = BenchmarkGroup("3", "4")
groupsb["g3"] = g3b
g3b["c"] = TrialEstimate(1003, 23, 41, 536, .05)
g3b["d"] = TrialEstimate(25341, 3013, 2, 150, .23)

groupstrial = BenchmarkGroup()
groupstrial["g"] = gtrial

# tests #
#-------#

@test time(groupsa).data == Dict("g1" => time(g1), "g2" => time(g2), "g3" => time(g3a))
@test gctime(groupsa).data == Dict("g1" => gctime(g1), "g2" => gctime(g2), "g3" => gctime(g3a))
@test memory(groupsa).data == Dict("g1" => memory(g1), "g2" => memory(g2), "g3" => memory(g3a))
@test allocs(groupsa).data == Dict("g1" => allocs(g1), "g2" => allocs(g2), "g3" => allocs(g3a))
@test tolerance(groupsa).data == Dict("g1" => tolerance(g1), "g2" => tolerance(g2), "g3" => tolerance(g3a))

@test max(groupsa, groupsb).data == Dict("g1" => max(g1, g1), "g2" => max(g2, g2), "g3" => max(g3a, g3b))
@test min(groupsa, groupsb).data == Dict("g1" => min(g1, g1), "g2" => min(g2, g2), "g3" => min(g3a, g3b))
@test ratio(groupsa, groupsb).data == Dict("g1" => ratio(g1, g1), "g2" => ratio(g2, g2), "g3" => ratio(g3a, g3b))
@test judge(groupsa, groupsb, 0.1).data == Dict("g1" => judge(g1, g1, 0.1), "g2" => judge(g2, g2, 0.1), "g3" => judge(g3a, g3b, 0.1))
@test judge(ratio(groupsa, groupsb), 0.1) == judge(groupsa, groupsb, 0.1)
@test ratio(groupsa, groupsb) == ratio(judge(groupsa, groupsb, 0.1))

@test isinvariant(judge(groupsa, groupsa))
@test !(isinvariant(judge(groupsa, groupsb)))
@test isregression(judge(groupsa, groupsb))
@test !(isregression(judge(groupsa, groupsa)))
@test isimprovement(judge(groupsa, groupsb))
@test !(isimprovement(judge(groupsa, groupsa)))
@test invariants(judge(groupsa, groupsb)).data == Dict("g1" => judge(g1, g1), "g2" => judge(g2, g2))
@test regressions(judge(groupsa, groupsb)).data == Dict("g3" => regressions(judge(g3a, g3b)))
@test improvements(judge(groupsa, groupsb)).data == Dict("g3" => improvements(judge(g3a, g3b)))

@test minimum(groupstrial)["g"]["t"] == minimum(groupstrial["g"]["t"])
@test maximum(groupstrial)["g"]["t"] == maximum(groupstrial["g"]["t"])
@test median(groupstrial)["g"]["t"] == median(groupstrial["g"]["t"])
@test mean(groupstrial)["g"]["t"] == mean(groupstrial["g"]["t"])

# tagging #
#---------#

@test groupsa[@tagged "1"] == BenchmarkGroup([], Dict("g1" => g1))
@test groupsa[@tagged "2"] == BenchmarkGroup([], Dict("g1" => g1, "g2" => g2))
@test groupsa[@tagged "3"] == BenchmarkGroup([], Dict("g2" => g2, "g3" => g3a))
@test groupsa[@tagged "4"] == BenchmarkGroup([], Dict("g3" => g3a))
@test groupsa[@tagged "3" && "4"] == groupsa[@tagged "4"]
@test groupsa[@tagged ALL && !("2")] == groupsa[@tagged !("2")]
@test groupsa[@tagged "1" || "4"] == BenchmarkGroup([], Dict("g1" => g1, "g3" => g3a))
@test groupsa[@tagged ("1" || "4") && !("2")] == groupsa[@tagged "4"]
@test groupsa[@tagged !("1" || "4") && "2"] == BenchmarkGroup([], Dict("g2" => g2))
@test groupsa[@tagged ALL] == groupsa
@test groupsa[@tagged !("1" || "3") && !("4")] == similar(groupsa)
