using Base.Test
using BenchmarkTools

#########
# Trial #
#########

trial1 = BenchmarkTools.Trial(1, 2, 3, 4, 5)
push!(trial1, 11, 21, 31, 41, 51)

trial2 = BenchmarkTools.Trial()
push!(trial2, 1, 2, 3, 4, 5)
push!(trial2, 11, 21, 31, 41, 51)

@test trial1.evals == trial2.evals == [1.0, 11.0]
@test trial1.times == trial2.times == [2.0, 21.0]
@test trial1.gctimes == trial2.gctimes == [3.0, 31.0]
@test trial1.memory == trial2.memory == [4.0, 41.0]
@test trial1.allocs == trial2.allocs == [5.0, 51.0]

@test trial1 == trial2

@test length(trial1) == 2

@test trial1[2] == BenchmarkTools.Trial(11, 21, 31, 41, 51)
@test trial1[1:end] == trial1

@test_approx_eq time(trial1) [2.0, 1.9090909090909092]
@test_approx_eq gctime(trial1) [3.0, 2.8181818181818183]
@test_approx_eq memory(trial1) [4.0, 3.0]
@test_approx_eq allocs(trial1) [5.0, 4.0]

#################
# TrialEstimate #
#################

t = BenchmarkTools.Trial([1, 2, 3],
                         [1.10, 2.03, 5.69],
                         [0.10, 0.03, 0.69],
                         [3, 12, 32],
                         [87, 76, 56])

l = linreg(t)

@test time(l) == 2.295
@test gctime(l) == 0.295
@test memory(l) == 3
@test allocs(l) == 18
@test fitness(l) == 0.8945203036633209

m = minimum(t)

@test time(m) == 1.015
@test gctime(m) == 0.015
@test memory(m) == 3
@test allocs(m) == 18
@test isnan(fitness(m))

@test m < l

##############
# TrialRatio #
##############

randrange = 1.0:0.01:10.0
x, y = rand(randrange), rand(randrange)

@test (ratio(x, y) == x/y) && (ratio(y, x) == y/x)
@test (ratio(x, x) == 1.0) && (ratio(y, y) == 1.0)
@test ratio(0.0, 0.0) == 1.0

t1 = BenchmarkTools.TrialEstimate(rand(), rand(), rand(Int), rand(Int), NaN)
t2 = BenchmarkTools.TrialEstimate(rand(), rand(), rand(Int), rand(Int), NaN)
tr = ratio(t1, t2)

@test time(tr) == ratio(time(t1), time(t2))
@test gctime(tr) == ratio(gctime(t1), gctime(t2))
@test memory(tr) == ratio(memory(t1), memory(t2))
@test allocs(tr) == ratio(allocs(t1), allocs(t2))

##################
# TrialJudgement #
##################

t1 = BenchmarkTools.TrialEstimate(1.0, 0.0, 2, 1, NaN)
t2 = BenchmarkTools.TrialEstimate(1.0 + BenchmarkTools.DEFAULT_TOLERANCE*2, 0.0, 1, 1, NaN)
tr = ratio(t1, t2)
tj1 = judge(t1, t2)
tj2 = judge(tr)

@test tj1 == tj2
@test ratio(tj1) == ratio(tj2) == tr
@test time(tj1) == time(tj2) == :improvement
@test memory(tj1) == memory(tj2) == :regression
@test allocs(tj1) == allocs(tj2) == :invariant

tj3 = judge(t1, t2, 2.0)
tj4 = judge(tr, 2.0)

@test tj3 == tj4
@test ratio(tj3) == ratio(tj4) == tr
@test time(tj3) == time(tj4) == :invariant
@test memory(tj3) == memory(tj4) == :invariant
@test allocs(tj3) == allocs(tj4) == :invariant

@test !(isinvariant(tj1))
@test !(isinvariant(tj2))
@test isinvariant(tj3)
@test isinvariant(tj4)

@test hasregression(tj1)
@test hasregression(tj2)
@test !(hasregression(tj3))
@test !(hasregression(tj4))

@test hasimprovement(tj1)
@test hasimprovement(tj2)
@test !(hasimprovement(tj3))
@test !(hasimprovement(tj4))

###################
# pretty printing #
###################

@test BenchmarkTools.prettypercent(.3120123) == "31.2%"

@test BenchmarkTools.prettydiff(0.0) == "-100.0%"
@test BenchmarkTools.prettydiff(1.0) == "+0.0%"
@test BenchmarkTools.prettydiff(2.0) == "+100.0%"

@test BenchmarkTools.prettytime(999) == "999.0 ns"
@test BenchmarkTools.prettytime(1000) == "1.0 μs"
@test BenchmarkTools.prettytime(999_999) == "1000.0 μs"
@test BenchmarkTools.prettytime(1_000_000) == "1.0 ms"
@test BenchmarkTools.prettytime(999_999_999) == "1000.0 ms"
@test BenchmarkTools.prettytime(1_000_000_000) == "1.0 s"

@test BenchmarkTools.prettymemory(1023) == "1023.0 bytes"
@test BenchmarkTools.prettymemory(1024) == "1.0 kb"
@test BenchmarkTools.prettymemory(1048575) == "1024.0 kb"
@test BenchmarkTools.prettymemory(1048576) == "1.0 mb"
@test BenchmarkTools.prettymemory(1073741823) == "1024.0 mb"
@test BenchmarkTools.prettymemory(1073741824) == "1.0 gb"
