module TrialsTests

using BenchmarkTools
using Test

#########
# Trial #
#########

trial1 = BenchmarkTools.Trial(BenchmarkTools.Parameters(; evals=2))
push!(trial1, 2, 1, 4, 5)
push!(trial1, 21, 0, 41, 51)

trial2 = BenchmarkTools.Trial(BenchmarkTools.Parameters(; time_tolerance=0.15))
push!(trial2, 21, 0, 41, 51)
push!(trial2, 2, 1, 4, 5)

push!(trial2, 21, 0, 41, 51)
@test length(trial2) == 3
deleteat!(trial2, 3)
@test length(trial1) == length(trial2) == 2
sort!(trial2)

@test trial1.params == BenchmarkTools.Parameters(; evals=trial1.params.evals)
@test trial2.params ==
    BenchmarkTools.Parameters(; time_tolerance=trial2.params.time_tolerance)
@test trial1.times == trial2.times == [2.0, 21.0]
@test trial1.gctimes == trial2.gctimes == [1.0, 0.0]
@test trial1.memory == trial2.memory == 4
@test trial1.allocs == trial2.allocs == 5

trial2.params = trial1.params

@test trial1 == trial2

@test trial1[2] ==
    push!(BenchmarkTools.Trial(BenchmarkTools.Parameters(; evals=2)), 21, 0, 4, 5)
@test trial1[1:end] == trial1

@test time(trial1) == time(trial2) == 2.0
@test gctime(trial1) == gctime(trial2) == 1.0
@test memory(trial1) == memory(trial2) == trial1.memory
@test allocs(trial1) == allocs(trial2) == trial1.allocs
@test params(trial1) == params(trial2) == trial1.params

# outlier trimming
trial3 = BenchmarkTools.Trial(
    BenchmarkTools.Parameters(), [1, 2, 3, 10, 11], [1, 1, 1, 1, 1], 1, 1
)

trimtrial3 = rmskew(trial3)
rmskew!(trial3)

@test mean(trimtrial3) <= median(trimtrial3)
@test trimtrial3 == trial3

#################
# TrialEstimate #
#################

randtrial = BenchmarkTools.Trial(BenchmarkTools.Parameters())

for _ in 1:40
    push!(randtrial, rand(1:20), 1, 1, 1)
end

while mean(randtrial) <= median(randtrial)
    push!(randtrial, rand(10:20), 1, 1, 1)
end

rmskew!(randtrial)

tmin = minimum(randtrial)
tmed = median(randtrial)
tmean = mean(randtrial)
tvar = var(randtrial)
tstd = std(randtrial)
tmax = maximum(randtrial)

@test time(tmin) == time(randtrial)
@test gctime(tmin) == gctime(randtrial)
@test memory(tmin) ==
    memory(tmed) ==
    memory(tmean) ==
    memory(tmax) ==
    memory(tvar) ==
    memory(tstd) ==
    memory(randtrial)
@test allocs(tmin) ==
    allocs(tmed) ==
    allocs(tmean) ==
    allocs(tmax) ==
    allocs(tvar) ==
    allocs(tstd) ==
    allocs(randtrial)
@test params(tmin) ==
    params(tmed) ==
    params(tmean) ==
    params(tmax) ==
    params(tvar) ==
    params(tstd) ==
    params(randtrial)

@test tmin <= tmed
@test tmean <= tmed # this should be true since we called rmoutliers!(randtrial) earlier
@test tmed <= tmax

##############
# TrialRatio #
##############

randrange = 1.0:0.01:10.0
x, y = rand(randrange), rand(randrange)

@test (ratio(x, y) == x / y) && (ratio(y, x) == y / x)
@test (ratio(x, x) == 1.0) && (ratio(y, y) == 1.0)
@test ratio(0.0, 0.0) == 1.0

ta = BenchmarkTools.TrialEstimate(
    BenchmarkTools.Parameters(), rand(), rand(), rand(Int), rand(Int)
)
tb = BenchmarkTools.TrialEstimate(
    BenchmarkTools.Parameters(), rand(), rand(), rand(Int), rand(Int)
)
tr = ratio(ta, tb)

@test time(tr) == ratio(time(ta), time(tb))
@test gctime(tr) == ratio(gctime(ta), gctime(tb))
@test memory(tr) == ratio(memory(ta), memory(tb))
@test allocs(tr) == ratio(allocs(ta), allocs(tb))
@test params(tr) == params(ta) == params(tb)

@test BenchmarkTools.gcratio(ta) == ratio(gctime(ta), time(ta))
@test BenchmarkTools.gcratio(tb) == ratio(gctime(tb), time(tb))

##################
# TrialJudgement #
##################

ta = BenchmarkTools.TrialEstimate(
    BenchmarkTools.Parameters(; time_tolerance=0.50, memory_tolerance=0.50), 0.49, 0.0, 2, 1
)
tb = BenchmarkTools.TrialEstimate(
    BenchmarkTools.Parameters(; time_tolerance=0.05, memory_tolerance=0.05), 1.00, 0.0, 1, 1
)
tr = ratio(ta, tb)
tj_ab = judge(ta, tb)
tj_r = judge(tr)

@test ratio(tj_ab) == ratio(tj_r) == tr
@test time(tj_ab) == time(tj_r) == :improvement
@test memory(tj_ab) == memory(tj_r) == :regression
@test tj_ab == tj_r

tj_ab_2 = judge(ta, tb; time_tolerance=2.0, memory_tolerance=2.0)
tj_r_2 = judge(tr; time_tolerance=2.0, memory_tolerance=2.0)

@test tj_ab_2 == tj_r_2
@test ratio(tj_ab_2) == ratio(tj_r_2)
@test time(tj_ab_2) == time(tj_r_2) == :invariant
@test memory(tj_ab_2) == memory(tj_r_2) == :invariant

@test !(isinvariant(tj_ab))
@test !(isinvariant(tj_r))
@test isinvariant(tj_ab_2)
@test isinvariant(tj_r_2)

@test !(isinvariant(time, tj_ab))
@test !(isinvariant(time, tj_r))
@test isinvariant(time, tj_ab_2)
@test isinvariant(time, tj_r_2)

@test !(isinvariant(memory, tj_ab))
@test !(isinvariant(memory, tj_r))
@test isinvariant(memory, tj_ab_2)
@test isinvariant(memory, tj_r_2)

@test isregression(tj_ab)
@test isregression(tj_r)
@test !(isregression(tj_ab_2))
@test !(isregression(tj_r_2))

@test !(isregression(time, tj_ab))
@test !(isregression(time, tj_r))
@test !(isregression(time, tj_ab_2))
@test !(isregression(time, tj_r_2))

@test isregression(memory, tj_ab)
@test isregression(memory, tj_r)
@test !(isregression(memory, tj_ab_2))
@test !(isregression(memory, tj_r_2))

@test isimprovement(tj_ab)
@test isimprovement(tj_r)
@test !(isimprovement(tj_ab_2))
@test !(isimprovement(tj_r_2))

@test isimprovement(time, tj_ab)
@test isimprovement(time, tj_r)
@test !(isimprovement(time, tj_ab_2))
@test !(isimprovement(time, tj_r_2))

@test !(isimprovement(memory, tj_ab))
@test !(isimprovement(memory, tj_r))
@test !(isimprovement(memory, tj_ab_2))
@test !(isimprovement(memory, tj_r_2))

###################
# pretty printing #
###################

@test BenchmarkTools.prettypercent(0.3120123) == "31.20%"

@test BenchmarkTools.prettydiff(0.0) == "-100.00%"
@test BenchmarkTools.prettydiff(1.0) == "+0.00%"
@test BenchmarkTools.prettydiff(2.0) == "+100.00%"

@test BenchmarkTools.prettytime(999) == "999.000 ns"
@test BenchmarkTools.prettytime(1000) == "1.000 μs"
@test BenchmarkTools.prettytime(999_999) == "999.999 μs"
@test BenchmarkTools.prettytime(1_000_000) == "1.000 ms"
@test BenchmarkTools.prettytime(999_999_999) == "1000.000 ms"
@test BenchmarkTools.prettytime(1_000_000_000) == "1.000 s"

@test BenchmarkTools.prettymemory(1023) == "1023 bytes"
@test BenchmarkTools.prettymemory(1024) == "1.00 KiB"
@test BenchmarkTools.prettymemory(1048575) == "1024.00 KiB"
@test BenchmarkTools.prettymemory(1048576) == "1.00 MiB"
@test BenchmarkTools.prettymemory(1073741823) == "1024.00 MiB"
@test BenchmarkTools.prettymemory(1073741824) == "1.00 GiB"

@test sprint(show, "text/plain", ta) == sprint(show, ta; context=:compact => false) == """
BenchmarkTools.TrialEstimate: 
  time:             0.490 ns
  gctime:           0.000 ns (0.00%)
  memory:           2 bytes
  allocs:           1"""

@test sprint(show, ta) == "TrialEstimate(0.490 ns)"
@test sprint(
    show,
    ta;
    context=IOContext(devnull, :compact => true, :typeinfo => BenchmarkTools.TrialEstimate),
) == "0.490 ns"

@test sprint(show, [ta, tb]) == "BenchmarkTools.TrialEstimate[0.490 ns, 1.000 ns]"

trial1sample = BenchmarkTools.Trial(BenchmarkTools.Parameters(), [1], [1], 1, 1)
@test try
    display(trial1sample)
    true
catch e
    false
end

@static if VERSION < v"1.6-"
    @test sprint(show, "text/plain", [ta, tb]) == """
    2-element Array{BenchmarkTools.TrialEstimate,1}:
     0.490 ns
     1.000 ns"""

else
    @test sprint(show, "text/plain", [ta, tb]) == """
    2-element Vector{BenchmarkTools.TrialEstimate}:
     0.490 ns
     1.000 ns"""
end

trial = BenchmarkTools.Trial(BenchmarkTools.Parameters(), [1.0, 1.01], [0.0, 0.0], 0, 0)
@test sprint(show, "text/plain", trial) == """
BenchmarkTools.Trial: 2 samples with 1 evaluation.
 Range (min … max):  1.000 ns … 1.010 ns  ┊ GC (min … max): 0.00% … 0.00%
 Time  (median):     1.005 ns             ┊ GC (median):    0.00%
 Time  (mean ± σ):   1.005 ns ± 0.007 ns  ┊ GC (mean ± σ):  0.00% ± 0.00%

  █                                                       █  
  █▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█ ▁
  1 ns           Histogram: frequency by time       1.01 ns <

 Memory estimate: 0 bytes, allocs estimate: 0."""

end # module
