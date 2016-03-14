using Base.Test
using BenchmarkTools
using BenchmarkTools: TrialEstimate, data

seteq(a, b) = sort!(collect(a)) == sort!(collect(b))

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

g2 = BenchmarkTools.BenchmarkGroup("g2", ["1", "3"])

te3 = TrialEstimate(323, 1, 2, 3, NaN)
te4 = TrialEstimate(1002, 123, 43, 9, 4)

g2["a"] = te3
g2["b"] = te4

t = BenchmarkTools.Trial([1, 2, 3],
                         [1.10, 2.03, 5.69],
                         [0.10, 0.03, 0.69],
                         [3, 12, 32],
                         [87, 76, 56])

gt = BenchmarkTools.BenchmarkGroup("g", ["1", "2"], Dict("t" => t))

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
@test data(judge(g, g2)) == Dict("a" => judge(te1, te3), "b" => judge(te2, te4))
@test ratio(g, g2) == ratio(judge(g, g2))
@test hasregression(judge(g, g2))
@test hasimprovement(judge(g, g2))
@test data(regressions(judge(g, g2))) == Dict("b" => judge(te2, te4))
@test data(improvements(judge(g, g2))) == Dict("a" => judge(te1, te3))

@test data(minimum(gt))["t"] == TrialEstimate(1.015, 0.015, 3, 18, NaN)
@test data(linreg(gt))["t"] == TrialEstimate(2.295, 0.295, 3, 18, 0.8945203036633209)
