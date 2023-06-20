module TrialsTests

using BenchmarkTools
using Statistics
using Test

if !isdefined(@__MODULE__(), :contains)
    # added in Julia 1.5, defined here to make tests pass on 1.0
    contains(haystack::AbstractString, needle) = occursin(needle, haystack)
end

#########
# Trial #
#########

trial1 = BenchmarkTools.Trial(BenchmarkTools.Parameters(evals = 2))
push!(trial1, 2, 1, 4, 5)
push!(trial1, 21, 0, 41, 51)

trial2 = BenchmarkTools.Trial(BenchmarkTools.Parameters(time_tolerance = 0.15))
push!(trial2, 21, 0, 41, 51)
push!(trial2, 2, 1, 4, 5)

push!(trial2, 21, 0, 41, 51)
@test length(trial2) == 3
deleteat!(trial2, 3)
@test length(trial1) == length(trial2) == 2
sort!(trial2)

@test trial1.params == BenchmarkTools.Parameters(evals = trial1.params.evals)
@test trial2.params == BenchmarkTools.Parameters(time_tolerance = trial2.params.time_tolerance)
@test trial1.times == trial2.times == [2.0, 21.0]
@test trial1.gctimes == trial2.gctimes == [1.0, 0.0]
@test trial1.memory == trial2.memory ==  4
@test trial1.allocs == trial2.allocs == 5

trial2.params = trial1.params

@test trial1 == trial2

@test trial1[2] == push!(BenchmarkTools.Trial(BenchmarkTools.Parameters(evals = 2)), 21, 0, 4, 5)
@test trial1[1:end] == trial1

@test time(trial1) == time(trial2) == 2.0
@test gctime(trial1) == gctime(trial2) == 1.0
@test memory(trial1) == memory(trial2) == trial1.memory
@test allocs(trial1) == allocs(trial2) == trial1.allocs
@test params(trial1) == params(trial2) == trial1.params

# outlier trimming
trial3 = BenchmarkTools.Trial(BenchmarkTools.Parameters(), [1, 2, 3, 10, 11],
                              [1, 1, 1, 1, 1], 1, 1)

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
@test memory(tmin) == memory(tmed) == memory(tmean) == memory(tmax) == memory(tvar) == memory(tstd) == memory(randtrial)
@test allocs(tmin) == allocs(tmed) == allocs(tmean) == allocs(tmax) == allocs(tvar) == allocs(tstd) == allocs(randtrial)
@test params(tmin) == params(tmed) == params(tmean) == params(tmax) == params(tvar) == params(tstd) == params(randtrial)

@test tmin <= tmed
@test tmean <= tmed # this should be true since we called rmoutliers!(randtrial) earlier
@test tmed <= tmax

##############
# TrialRatio #
##############

randrange = 1.0:0.01:10.0
x, y = rand(randrange), rand(randrange)

@test (ratio(x, y) == x/y) && (ratio(y, x) == y/x)
@test (ratio(x, x) == 1.0) && (ratio(y, y) == 1.0)
@test ratio(0.0, 0.0) == 1.0

ta = BenchmarkTools.TrialEstimate(BenchmarkTools.Parameters(), rand(), rand(), rand(Int), rand(Int))
tb = BenchmarkTools.TrialEstimate(BenchmarkTools.Parameters(), rand(), rand(), rand(Int), rand(Int))
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

ta = BenchmarkTools.TrialEstimate(BenchmarkTools.Parameters(time_tolerance = 0.50, memory_tolerance = 0.50), 0.49, 0.0, 2, 1)
tb = BenchmarkTools.TrialEstimate(BenchmarkTools.Parameters(time_tolerance = 0.05, memory_tolerance = 0.05), 1.00, 0.0, 1, 1)
tr = ratio(ta, tb)
tj_ab = judge(ta, tb)
tj_r = judge(tr)

@test ratio(tj_ab) == ratio(tj_r) == tr
@test time(tj_ab) == time(tj_r) == :improvement
@test memory(tj_ab) == memory(tj_r) == :regression
@test tj_ab == tj_r

tj_ab_2 = judge(ta, tb; time_tolerance = 2.0, memory_tolerance = 2.0)
tj_r_2 = judge(tr; time_tolerance = 2.0, memory_tolerance = 2.0)

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

@test BenchmarkTools.prettypercent(.3120123) == "31.20%"

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

@test BenchmarkTools.prettycount(10) == "10"
@test BenchmarkTools.prettycount(1023) == "1_023"
@test BenchmarkTools.prettycount(40560789) == "40_560_789"

@test sprint(show, "text/plain", ta) == sprint(show, ta; context=:compact => false) == """
BenchmarkTools.TrialEstimate: 
  time:             0.490 ns
  gctime:           0.000 ns (0.00%)
  memory:           2 bytes
  allocs:           1"""

@test sprint(show, ta) == "TrialEstimate(0.490 ns)"
@test sprint(
    show, ta;
    context = IOContext(
        devnull, :compact => true, :typeinfo => BenchmarkTools.TrialEstimate)
) == "0.490 ns"

@test sprint(show, [ta, tb]) == "BenchmarkTools.TrialEstimate[0.490 ns, 1.000 ns]"

trial1sample = BenchmarkTools.Trial(BenchmarkTools.Parameters(), [1], [1], 1, 1)
@test try display(trial1sample); true catch e false end

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

# Trial with 0 samples
t0 = BenchmarkTools.Trial(BenchmarkTools.Parameters(), [], [], 0, 0)
@test sprint(show, "text/plain", t0) == "Trial: 0 samples"

# Trial with 1 sample
t001 = BenchmarkTools.Trial(BenchmarkTools.Parameters(), [pi * 10^6], [0], 0, 0)
s001 = sprint(show, "text/plain", t001)
@test contains(s001, "┌ Trial:")  # box starting at the type
@test contains(s001, "│  time 3.142 ms")
@test contains(s001, "│  0 allocations\n")  # doesn't print 0 bytes after this
@test contains(s001, "└  1 sample, with 1 evaluation")

# Histogram utils
@test BenchmarkTools.asciihist([1,2,3]) == ['▃' '▆' '█']
@test BenchmarkTools.asciihist([1,2,0,3], 2) == [' ' '▃' ' ' '█'; '▇' '█' '▁' '█']

@test BenchmarkTools.histogram_bindata([1.1, 3.1, 99], 1:3) == [1,0,2]
@test BenchmarkTools.histogram_bindata([1.1, -99, 3.1], 1:3.0) == [1,0,1]

# Trials with several samples
t003 = BenchmarkTools.Trial(BenchmarkTools.Parameters(), [0.01, 0.02, 0.04], [0,0,0], 0, 0)
s003 = sprint(show, "text/plain", t003)
@test contains(s003, " 1 ns +")  # right limit is 1ns
@test contains(s003, "min 0.010 ns, median 0.020 ns, mean 0.023 ns, 99ᵗʰ 0.040 ns")

t123 = BenchmarkTools.Trial(BenchmarkTools.Parameters(), [1,2,3.], [0,0,0.], 0, 0)
s123 = sprint(show, "text/plain", t123)
@test contains(s123, "min 1.000 ns, median 2.000 ns, mean 2.000 ns")
@test contains(s123, " 0 allocations\n")  # doesn't print 0 bytes after this
@test contains(s123, " ◑* ")  # median ◑ is shifted left
@test contains(s123, "▁▁█▁▁")  # has a histogram, mostly zero
@test contains(s123, "▁▁▁█ ▁\n")  # 3.0 fits in last bin, not the overflow
@test endswith(s123, "3 ns +")  # right endpoint rounded to 3, no decimals
@test contains(s123, "3 samples, each 1 evaluation")  # caption

t456 = BenchmarkTools.Trial(BenchmarkTools.Parameters(), 100 * [1,1,3,14,16.], [0,0,2,0,0.], 456, 7)
s456 = sprint(show, "text/plain", t456)
@test contains(s456, "7 allocations, total 456 bytes")
@test contains(s456, "GC time: mean 0.400 ns (0.06%), max 2.000 ns (0.67%)")
@test contains(s456, "┌ Trial:")  # box starting at the type
@test contains(s456, "│  ◔       ")  # 1st quartile lines up with bar
@test contains(s456, "│  █▁▁▁▁▁▁▁")
@test contains(s456, "└  100 ns ")  # box closing + left endpoint without decimals

# Compact show & arrays of Trials
@test sprint(show, t001) == "Trial(3.142 ms)"
@test sprint(show, t003) == "Trial(0.010 ns)"
if VERSION >= v"1.6"  # 1.5 prints Array{T,1}
    @test sprint(show, "text/plain", [t001, t003]) == "2-element Vector{BenchmarkTools.Trial}:\n 3.142 ms\n 0.010 ns"
    @test_skip sprint(show, "text/plain", [t0]) == "1-element Vector{BenchmarkTools.Trial}:\n ??"
    # this is an error on BenchmarkTools v1.2.1, and v0.4.3, probably long before:
    # MethodError: reducing over an empty collection is not allowed
end

#=

# Some visual histogram checks, in which mean/median should highlight a bar, or not:

using BenchmarkTools: Trial, Parameters
Trial(Parameters(), [pi * 10^9], [0], 0, 0)  # one sample

# mean == median, one bar. Symbol for median moves to the left.
Trial(Parameters(), [pi, pi], [0, 0], 0, 0)
Trial(Parameters(), fill(101, 33), vcat(zeros(32), 50), 0, 0)

# mean == median, three bars
Trial(Parameters(), [3,4,5], [0,0,0], 0, 0)

# three bars, including mean not median
Trial(Parameters(), pi * [1,3,4,4], [0,0,0,100], 1, 1)

# three bars, including median & both quartiles, but not mean
Trial(Parameters(), 99.9 * [1,1,3,14,16], [0,0,99,0,0], 222, 2)

# same, but smaller range. Note also max GC is not max time.
Trial(Parameters(), 999 .+ [1,1,3,14,16], [0,0,123,0,0], 45e6, 7)


# Check that auto-sizing stops on very small widths:
io = IOContext(stdout, :displaysize => (25,30))
show(io, MIME("text/plain"), Trial(Parameters(), [3,4,5], [0,0,0], 0, 0))
show(io, MIME("text/plain"), Trial(Parameters(), repeat(100 * [3,4,5], 10^6), zeros(3*10^6), 0, 0))

io = IOContext(stdout, :displaysize => (25,50), :logbins => true)  # this is wider
show(io, MIME("text/plain"), Trial(Parameters(), 100 * [3,4,5], [0,0,0], 0, 0))

# Check that data off the left is OK, and median still highlighted:
io = IOContext(stdout, :histmin => 200.123)
show(io, MIME("text/plain"), Trial(Parameters(), 99.9 * [1,1,3,14,16], [0,0,99,0,0], 222, 2))

=#

end # module
