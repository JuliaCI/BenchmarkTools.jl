using Base.Test
using BenchmarkTools
using BenchmarkTools: TrialEstimate, data

seteq(a, b) = length(a) == length(b) == length(intersect(a, b))

##################
# BenchmarkGroup #
##################

# setup #
#-------#

g = BenchmarkTools.BenchmarkGroup("g", ["1", "2"])

te1 = TrialEstimate(32, 1, 2, 3, NaN)
te2 = TrialEstimate(4123, 123, 43, 9, 4)

g["a"] = te1
g["b"] = te2

gcopy = copy(g)
gsimilar = similar(g)

g2 = BenchmarkTools.BenchmarkGroup("g2", ["2", "3"])

te3 = TrialEstimate(323, 1, 2, 3, NaN)
te4 = TrialEstimate(1002, 123, 43, 9, 4)

g2["a"] = te3
g2["b"] = te4

t = BenchmarkTools.Trial([1, 2, 3],
                         [1.10, 2.03, 5.69],
                         [0.10, 0.03, 0.69],
                         [3, 12, 32],
                         [87, 76, 56])

gt = BenchmarkTools.BenchmarkGroup("g", [], Dict("t" => t))

# tests #
#-------#

@test length(g) == 2
@test g["a"] == te1
@test g["b"] == te2
@test haskey(g, "a")
@test !(haskey(g, "x"))
@test seteq(keys(g), ["a", "b"])
@test seteq(values(g), [te1, te2])
@test start(g) == start(values(g))
@test next(g, start(g)) == next(values(g), start(g))
@test done(g, start(g)) == done(values(g), start(g))
@test seteq([x for x in g], [te2, te1])

@test g == gcopy
@test seteq(keys(delete!(gcopy, "a")), ["b"])
@test isempty(delete!(gcopy, "b"))
@test isempty(gsimilar)
@test gsimilar.id == g.id && gsimilar.tags == g.tags

@test data(time(g)) == Dict("a" => time(te1), "b" => time(te2))
@test data(gctime(g)) == Dict("a" => gctime(te1), "b" => gctime(te2))
@test data(memory(g)) == Dict("a" => memory(te1), "b" => memory(te2))
@test data(allocs(g)) == Dict("a" => allocs(te1), "b" => allocs(te2))
@test data(ratio(g, g2)) == Dict("a" => ratio(te1, te3), "b" => ratio(te2, te4))
@test data(judge(g, g2, 0.1)) == Dict("a" => judge(te1, te3, 0.1), "b" => judge(te2, te4, 0.1))
@test judge(ratio(g, g2), 0.1) == judge(g, g2, 0.1)
@test ratio(g, g2) == ratio(judge(g, g2, 0.1))
@test hasregression(judge(g, g2))
@test hasimprovement(judge(g, g2))
@test data(regressions(judge(g, g2))) == Dict("b" => judge(te2, te4))
@test data(improvements(judge(g, g2))) == Dict("a" => judge(te1, te3))

@test minimum(gt)["t"] == TrialEstimate(1.015, 0.015, 3, 18, NaN)
@test linreg(gt)["t"] == TrialEstimate(2.295, 0.295, 3, 18, 0.8945203036633209)

###################
# GroupCollection #
###################

# setup #
#-------#

groups = GroupCollection()
addgroup!(groups, g)
addgroup!(groups, g2)
g31 = addgroup!(groups, "g3", ["3", "4"])
g31["c"] = TrialEstimate(6341, 23, 41, 536, .99)
g31["d"] = TrialEstimate(12341, 3013, 2, 150, NaN)

groups_copy = copy(groups)
groups_similar = similar(groups)

groups2 = GroupCollection()
addgroup!(groups2, g)
addgroup!(groups2, g2)
g32 = addgroup!(groups2, "g3", ["3", "4"])
g32["c"] = TrialEstimate(1003, 23, 41, 536, .99)
g32["d"] = TrialEstimate(25341, 3013, 2, 150, NaN)

groupst = GroupCollection()
addgroup!(groupst, gt)

# tests #
#-------#

@test length(groups) == 3
@test groups["g"] == g
@test groups["g3"] == g31
@test haskey(groups, "g")
@test !(haskey(groups, "x"))
@test seteq(keys(groups), ["g", "g2", "g3"])
@test seteq(values(groups), [g, g2, g31])

@test start(groups) == start(values(groups))
@test next(groups, start(groups)) == next(values(groups), start(groups))
@test done(groups, start(groups)) == done(values(groups), start(groups))
@test seteq([x for x in groups], [g, g2, g31])

@test groups == groups_copy
@test seteq(keys(delete!(groups_copy, "g")), ["g2", "g3"])
@test isempty(delete!(delete!(groups_copy, "g2"), "g3"))
@test isempty(groups_similar)

@test time(groups) == GroupCollection("g" => time(g), "g2" => time(g2), "g3" => time(g31))
@test gctime(groups) == GroupCollection("g" => gctime(g), "g2" => gctime(g2), "g3" => gctime(g31))
@test memory(groups) == GroupCollection("g" => memory(g), "g2" => memory(g2), "g3" => memory(g31))
@test allocs(groups) == GroupCollection("g" => allocs(g), "g2" => allocs(g2), "g3" => allocs(g31))
@test ratio(groups, groups2) == GroupCollection("g" => ratio(g, g), "g2" => ratio(g2, g2), "g3" => ratio(g31, g32))
@test judge(groups, groups2, 0.1) == GroupCollection("g" => judge(g, g, 0.1), "g2" => judge(g2, g2, 0.1), "g3" => judge(g31, g32, 0.1))
@test judge(ratio(groups, groups2), 0.1) == judge(groups, groups2, 0.1)
@test ratio(groups, groups2) == ratio(judge(groups, groups2, 0.1))
@test hasregression(judge(groups, groups2))
@test hasimprovement(judge(groups, groups2))
@test data(regressions(judge(groups, groups2))) == Dict("g3" => regressions(judge(g31, g32)))
@test data(improvements(judge(groups, groups2))) == Dict("g3" => improvements(judge(g31, g32)))

@test minimum(groupst)["g"]["t"] == minimum(groupst["g"]["t"])
@test linreg(groupst)["g"]["t"] == linreg(groupst["g"]["t"])

#################
# Tag Filtering #
#################

@test groups[@tagged "1"] == GroupCollection("g" => g)
@test groups[@tagged "2"] == GroupCollection("g" => g, "g2" => g2)
@test groups[@tagged "3"] == GroupCollection("g2" => g2, "g3" => g31)
@test groups[@tagged "4"] == GroupCollection("g3" => g31)
@test groups[@tagged "3" && "4"] == groups[@tagged "4"]
@test groups[@tagged ALL && !("2")] == groups[@tagged !("2")]
@test groups[@tagged "1" || "4"] == GroupCollection("g" => g, "g3" => g31)
@test groups[@tagged ("1" || "4") && !("2")] == groups[@tagged "4"]
@test groups[@tagged !("1" || "4") && "2"] == GroupCollection("g2" => g2)
@test groups[@tagged ALL] == groups
@test groups[@tagged !("1" || "3") && !("4")] == similar(groups)
