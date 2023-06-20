# Manual
BenchmarkTools was created to facilitate the following tasks:

1. Organize collections of benchmarks into manageable benchmark suites
2. Configure, save, and reload benchmark parameters for convenience, accuracy, and consistency
3. Execute benchmarks in a manner that yields reasonable and consistent performance predictions
4. Analyze and compare results to determine whether a code change caused regressions or improvements

Before we get too far, let's define some of the terminology used in this document:

- "evaluation": a single execution of a benchmark expression.
- "sample": a single time/memory measurement obtained by running multiple evaluations.
- "trial": an experiment in which multiple samples are gathered (or the result of such an experiment).
- "benchmark parameters": the configuration settings that determine how a benchmark trial is performed

The reasoning behind our definition of "sample" may not be obvious to all readers. If the time to execute a benchmark is smaller than the resolution of your timing method, then a single evaluation of the benchmark will generally not produce a valid sample. In that case, one must approximate a valid sample by
recording the total time `t` it takes to record `n` evaluations, and estimating the sample's time per evaluation as `t/n`. For example, if a sample takes 1 second for 1 million evaluations, the approximate time per evaluation for that sample is 1 microsecond. It's not obvious what the right number of evaluations per sample should be for any given benchmark, so BenchmarkTools provides a mechanism (the `tune!` method) to automatically figure it out for you.

## Benchmarking basics

### Defining and executing benchmarks

To quickly benchmark a Julia expression, use `@benchmark`:

```julia
julia> @benchmark sum(sin, range(0, 2pi, length=17))
┌ Trial:
│  min 277.822 ns, median 278.523 ns, mean 282.786 ns, 99ᵗʰ 353.745 ns
│  0 allocations
│         ◑  *
│        █
│  ▁▁▁▁▁▁█▄▂▂▂▂▂▂▃▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▁▁▁▁▁ ▂
└  270 ns            10_000 samples, each 298 evaluations            360 ns +
```

The `@benchmark` macro is essentially shorthand for defining a benchmark, auto-tuning the benchmark's configuration parameters, and running the benchmark. These three steps can be done explicitly using `@benchmarkable`, `tune!` and `run`:

```julia
# define the benchmark with default parameters
julia> b = @benchmarkable sum(sin, range(0, 2pi, length=17));

# find the right evals/sample and number of samples to take for this benchmark
julia> tune!(b);

julia> run(b)
┌ Trial:
│  min 277.914 ns, median 278.465 ns, mean 281.920 ns, 99ᵗʰ 331.963 ns
│  0 allocations
│          ◔◑  *
│          █
│  ▁▁▁▁▁▁▁▁█▂▂▂▂▂▂▂▂▂▃▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▁▁▁▁▁▁▁▁ ▂
└  270 ns            10_000 samples, each 303 evaluations            340 ns +
```

Alternatively, you can use the `@btime` or `@belapsed` macros.
These take exactly the same arguments as `@benchmark`, but
behave like the `@time` or `@elapsed` macros included with
Julia: `@btime` prints the minimum time and memory allocation
before returning the value of the expression, while `@belapsed`
returns the minimum time in seconds.

```julia
julia> @btime sum(sin, range(0, 2pi, length=17))
  277.960 ns (0 allocations: 0 bytes)
-3.559516622919863e-16

julia> @belapsed sum(sin, range(0, 2pi, length=17))
2.7796013289036544e-7

julia> ans * 1e9  # convert to nanoseconds
277.96013289036546
```

### Benchmark `Parameters`

You can pass the following keyword arguments to `@benchmark`, `@benchmarkable`, and `run` to configure the execution process:

- `samples`: The number of samples to take. Execution will end if this many samples have been collected. Defaults to `BenchmarkTools.DEFAULT_PARAMETERS.samples = 10000`.
- `seconds`: The number of seconds budgeted for the benchmarking process. The trial will terminate if this time is exceeded (regardless of `samples`), but at least one sample will always be taken. In practice, actual runtime can overshoot the budget by the duration of a sample. Defaults to `BenchmarkTools.DEFAULT_PARAMETERS.seconds = 5`.
- `evals`: The number of evaluations per sample. For best results, this should be kept consistent between trials. A good guess for this value can be automatically set on a benchmark via `tune!`, but using `tune!` can be less consistent than setting `evals` manually (which bypasses tuning). Defaults to `BenchmarkTools.DEFAULT_PARAMETERS.evals = 1`. If the function you study mutates its input, it is probably a good idea to set `evals=1` manually.
- `overhead`: The estimated loop overhead per evaluation in nanoseconds, which is automatically subtracted from every sample time measurement. The default value is `BenchmarkTools.DEFAULT_PARAMETERS.overhead = 0`. `BenchmarkTools.estimate_overhead` can be called to determine this value empirically (which can then be set as the default value, if you want).
- `gctrial`: If `true`, run `gc()` before executing this benchmark's trial. Defaults to `BenchmarkTools.DEFAULT_PARAMETERS.gctrial = true`.
- `gcsample`: If `true`, run `gc()` before each sample. Defaults to `BenchmarkTools.DEFAULT_PARAMETERS.gcsample = false`.
- `time_tolerance`: The noise tolerance for the benchmark's time estimate, as a percentage. This is utilized after benchmark execution, when analyzing results. Defaults to `BenchmarkTools.DEFAULT_PARAMETERS.time_tolerance = 0.05`.
- `memory_tolerance`: The noise tolerance for the benchmark's memory estimate, as a percentage. This is utilized after benchmark execution, when analyzing results. Defaults to `BenchmarkTools.DEFAULT_PARAMETERS.memory_tolerance = 0.01`.

To change the default values of the above fields, one can mutate the fields of `BenchmarkTools.DEFAULT_PARAMETERS`, for example:

```julia
# change default for `seconds` to 2.5
BenchmarkTools.DEFAULT_PARAMETERS.seconds = 2.50
# change default for `time_tolerance` to 0.20
BenchmarkTools.DEFAULT_PARAMETERS.time_tolerance = 0.20
```

Here's an example that demonstrates how to pass these parameters to benchmark definitions:

```julia
b = @benchmarkable sin(1) seconds=1 time_tolerance=0.01
run(b) # equivalent to run(b, seconds = 1, time_tolerance = 0.01)
```

### Interpolating values into benchmark expressions

You can interpolate values into `@benchmark` and `@benchmarkable` expressions:

```julia
# rand(1000) is executed for each evaluation
julia> @benchmark sum(sqrt, rand(1000))
┌ Trial:
│  min 1.629 μs, median 2.021 μs, mean 2.464 μs, 99ᵗʰ 4.063 μs
│  1 allocation, 7.94 KiB
│  GC time: mean 385.130 ns (15.63%), max 266.488 μs (98.02%)
│           ◔  ◑ ◕          *
│   ▆        ▂█▇▅
│  ▃█▄▄▃▃▃▃▅██████▆▅▄▄▄▃▃▃▂▃▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▁ ▃
└  1.6 μs             10_000 samples, each 10 evaluations            4.1 μs +

# rand(1000) is evaluated at definition time, and the resulting
# value is interpolated into the benchmark expression
julia> @benchmark sum(sqrt, $(rand(1000)))
┌ Trial:
│  min 900.786 ns, median 904.762 ns, mean 916.071 ns, 99ᵗʰ 1.161 μs
│  0 allocations
│       ◑◕ *
│       █
│  ▁▁▁▁▂█▄▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▁▂▂▂▂▂▂▂▁▁▁▁▁▁▁▁ ▂
└  880 ns             10_000 samples, each 42 evaluations            1.2 μs +
```

A good rule of thumb is that **external variables should be explicitly interpolated into the benchmark expression**:

```julia
julia> A = rand(1000);

# BAD: A is a global variable in the benchmarking context
julia> @benchmark [i*i for i in A]
┌ Trial:
│  min 550.043 ns, median 1.011 μs, mean 1.385 μs, 99ᵗʰ 13.571 μs
│  2 allocations, total 7.95 KiB
│  GC time: mean 396.300 ns (28.61%), max 15.675 μs (89.99%)
│    ◑◕*
│    █
│  ▅▅█▇▂▂▂▂▂▂▂▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▂▁▂▂▂▂▂▂▂▂▂▂▂▂▂▂▁▁ ▂
└  550 ns             7_811 samples, each 184 evaluations             14 μs +

# GOOD: A is a constant value in the benchmarking context
julia> @benchmark [i*i for i in $A]
┌ Trial:
│  min 490.885 ns, median 944.875 ns, mean 1.288 μs, 99ᵗʰ 12.160 μs
│  1 allocation, 7.94 KiB
│  GC time: mean 367.793 ns (28.54%), max 14.558 μs (94.32%)
│    ◔◑ *
│    █
│  ▅▃██▃▂▂▁▁▁▂▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▂▂▂▂▂▂▂▂▂▂▂▁▁▁▁ ▂
└  490 ns             8_049 samples, each 192 evaluations             13 μs +
```

(Note that "KiB" is the SI prefix for a [kibibyte](https://en.wikipedia.org/wiki/Kibibyte): 1024 bytes.)

Keep in mind that you can mutate external state from within a benchmark:

```julia
julia> A = zeros(3);

 # each evaluation will modify A
julia> b = @benchmarkable fill!($A, rand());

julia> run(b, samples = 1);

julia> A
3-element Vector{Float64}:
 0.4615582142515109
 0.4615582142515109
 0.4615582142515109

julia> run(b, samples = 1);

julia> A
3-element Vector{Float64}:
 0.06373849439691504
 0.06373849439691504
 0.06373849439691504
```

Normally, you can't use locally scoped variables in `@benchmark` or `@benchmarkable`, since all benchmarks are defined at the top-level scope by design. However, you can work around this by interpolating local variables into the benchmark expression:

```julia
# will throw UndefVar error for `x`
julia> let x = 1
           @benchmark sin(x)
       end

# will work fine
julia> let x = 1
           @benchmark sin($x)
       end
```

### Setup and teardown phases

BenchmarkTools allows you to pass `setup` and `teardown` expressions to `@benchmark` and `@benchmarkable`. The `setup` expression is evaluated just before sample execution, while the `teardown` expression is evaluated just after sample execution. Here's an example where this kind of thing is useful:

```julia
julia> x = rand(100_000);

# For each sample, bind a variable `y` to a fresh copy of `x`. As you
# can see, `y` is accessible within the scope of the core expression.
julia> b = @benchmarkable sort!(y) setup=(y = copy($x))
Benchmark(evals=1, seconds=5.0, samples=10000)

julia> run(b)
┌ Trial:
│  min 4.595 ms, median 4.647 ms, mean 4.658 ms, 99ᵗʰ 4.826 ms
│  0 allocations
│                     ◔      ◑ *     ◕
│                   ▁█
│  ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁██▇▆▆▅▄▅▆▄▅▆▅▃▆▆▅▆▄▄▅▅▄▄▄▃▂▁▂▂▃▂▃▁▂▁▂▂▂▁▂▂▁▁▁▁▁▁▁▁▁▁▁▁▁ ▃
└  4.5 ms               419 samples, each 1 evaluation               4.9 ms +
```

In the above example, we wish to benchmark Julia's in-place sorting method. Without a setup phase, we'd have to either allocate a new input vector for each sample (such that the allocation time would pollute our results) or use the same input vector every sample (such that all samples but the first would benchmark the wrong thing - sorting an already sorted vector). The setup phase solves the problem by allowing us to do some work that can be utilized by the core expression, without that work being erroneously included in our performance results.

Note that the `setup` and `teardown` phases are **executed for each sample, not each evaluation**. Thus, the sorting example above wouldn't produce the intended results if `evals/sample > 1` (it'd suffer from the same problem of benchmarking against an already sorted vector).

If your setup involves several objects, you need to separate the assignments with semicolons, as follows:

```julia
julia> @btime x + y setup = (x=1; y=2)  # works
  1.238 ns (0 allocations: 0 bytes)
3

julia> @btime x + y setup = (x=1, y=2)  # errors
ERROR: UndefVarError: `x` not defined
```

This also explains the error you get if you accidentally put a comma in the setup for a single argument:

```julia
julia> @btime exp(x) setup = (x=1,)  # errors
ERROR: UndefVarError: `x` not defined
```

### Understanding compiler optimizations

It's possible for LLVM and Julia's compiler to perform optimizations on `@benchmarkable` expressions. In some cases, these optimizations can elide a computation altogether, resulting in unexpectedly "fast" benchmarks. For example, the following expression is non-allocating:
```julia
# TODO: This needs a new example!! View is in fact non-allocating.

julia> @benchmark (view(a, 1:2, 1:2); 1) setup=(a = rand(3, 3))
┌ Trial:
│  min 1.292 ns, median 1.417 ns, mean 1.417 ns, 99ᵗʰ 1.500 ns
│  0 allocations
│                                                     *◑
│                                                     ▁█
│  ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▂▁▁▁▁▁▁▁▁▂▂▁▁▁▁▁▁▁▁▆▁▁▁▁▁▁▁▁▁██▁▁▁▁▁▁▁▁▂▂▁▁▁▁▁▁▁▁▂ ▂
└  1.2 ns           10_000 samples, each 1_000 evaluations           1.5 ns +
```

Note, however, that this does not mean that `view(a, 1:2, 1:2)` is non-allocating:

```julia
julia> @benchmark view(a, 1:2, 1:2) setup=(a = rand(3, 3))
┌ Trial:
│  min 1.666 ns, median 1.750 ns, mean 1.739 ns, 99ᵗʰ 1.792 ns
│  0 allocations
│                                         ◔         *   ◑ 
│                                                       █
│  ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▂▂▁▁▁▁▁▁▁▁▁▁▁▁▁▆▄▁▁▁▁▁▁▁▁▁▁▁▁▁█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▂▂▁▁ ▂
└  1.6 ns           10_000 samples, each 1_000 evaluations           1.8 ns +
```

The key point here is that these two benchmarks measure different things, even though their code is similar. In the first example, Julia was able to optimize away `view(a, 1:2, 1:2)` because it could prove that the value wasn't being returned and `a` wasn't being mutated. In the second example, the optimization is not performed because `view(a, 1:2, 1:2)` is a return value of the benchmark expression.

BenchmarkTools will faithfully report the performance of the exact code that you provide to it, including any compiler optimizations that might happen to elide the code completely. It's up to you to design benchmarks which actually exercise the code you intend to exercise. 

A common place julia's optimizer may cause a benchmark to not measure what a user thought it was measuring is simple operations where all values are known at compile time. Suppose you wanted to measure the time it takes to add together two integers:
```julia
julia> a = 1; b = 2
2

julia> @btime $a + $b
  0.024 ns (0 allocations: 0 bytes)
3
```
in this case julia was able to use the properties of `+(::Int, ::Int)` to know that it could safely replace `$a + $b` with `3` at compile time. We can stop the optimizer from doing this by referencing and dereferencing the interpolated variables  
```julia
julia> @btime $(Ref(a))[] + $(Ref(b))[]
  1.277 ns (0 allocations: 0 bytes)
3
```

## Handling benchmark results

BenchmarkTools provides four types related to benchmark results:

- `Trial`: stores all samples collected during a benchmark trial, as well as the trial's parameters
- `TrialEstimate`: a single estimate used to summarize a `Trial`
- `TrialRatio`: a comparison between two `TrialEstimate`
- `TrialJudgement`: a classification of the fields of a `TrialRatio` as `invariant`, `regression`, or `improvement`

This section provides a limited number of examples demonstrating these types. For a thorough list of supported functionality, see [the reference document](reference.md).

### `Trial` and `TrialEstimate`

Running a benchmark produces an instance of the `Trial` type:

```julia
julia> using LinearAlgebra

julia> t = @benchmark eigen(rand(10, 10))
┌ Trial:
│  min 12.708 μs, median 15.125 μs, mean 16.126 μs, 99ᵗʰ 28.626 μs
│  19 allocations, total 16.16 KiB
│  GC time: mean 519.554 ns (3.22%), max 1.787 ms (98.16%)
│             ◔ ◑  ◕*
│          ▂▃▇▇▇█▆▄▃
│  ▁▁▂▂▂▃▅▇██████████▆▅▄▄▃▃▃▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▁ ▃
└  12 μs               10_000 samples, each 1 evaluation              29 μs +

julia> dump(t) # here's what's actually stored in a Trial
BenchmarkTools.Trial
  params: BenchmarkTools.Parameters
    seconds: Float64 2.0
    samples: Int64 10000
    evals: Int64 1
    overhead: Float64 0.0
    gctrial: Bool true
    gcsample: Bool false
    time_tolerance: Float64 0.05
    memory_tolerance: Float64 0.01
  times: Array{Float64}((10000,)) [35084.0, 16708.0, 16542.0, 15750.0, 14917.0, 15500.0, 16459.0, 15917.0, 14667.0, 16875.0  …  15750.0, 15667.0, 17000.0, 14167.0, 16000.0, 15583.0, 15500.0, 15167.0, 16125.0, 15250.0]
  gctimes: Array{Float64}((10000,)) [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
  memory: Int64 16544
  allocs: Int64 19
```

As you can see from the above, a couple of different timing estimates are pretty-printed with the `Trial`. You can calculate these estimates yourself using the `minimum`, `median`, `mean`, `maximum`,, `quantile` and `std` functions:

```julia
julia> using Statistics

julia> minimum(t)
BenchmarkTools.TrialEstimate: 
  time:             12.708 μs
  gctime:           0.000 ns (0.00%)
  memory:           16.16 KiB
  allocs:           19

julia> median(t)  # The same as quantile(t, 0.5)
BenchmarkTools.TrialEstimate: 
  time:             15.125 μs
  gctime:           0.000 ns (0.00%)
  memory:           16.16 KiB
  allocs:           19

julia> mean(t)
BenchmarkTools.TrialEstimate: 
  time:             16.126 μs
  gctime:           519.554 ns (3.22%)
  memory:           16.16 KiB
  allocs:           19

julia> quantile(t, 0.99)
BenchmarkTools.TrialEstimate: 
  time:             28.626 μs
  gctime:           0.000 ns (0.00%)
  memory:           16.16 KiB
  allocs:           19

julia> maximum(t)
BenchmarkTools.TrialEstimate: 
  time:             1.821 ms
  gctime:           1.787 ms (98.16%)
  memory:           16.16 KiB
  allocs:           19

julia> std(t)
BenchmarkTools.TrialEstimate: 
  time:             30.401 μs
  gctime:           30.002 μs (98.69%)
  memory:           16.16 KiB
  allocs:           19
```

Note that `maximum(t)` finds the run with maximum time, and displays its `gctime`.
This will often be the longest `gctime`, since garbage collection is often what makes
the slowest run take so long, but this is not guaranteed. The display of `@benchmark`
uses instead `maximum(t.gctimes)`.

### Which estimator should I use?

Time distributions are always right-skewed for the benchmarks we've tested. This phenomena can be justified by considering that the machine noise affecting the benchmarking process is, in some sense, inherently positive - there aren't really sources of noise that would regularly cause your machine to execute a series of instructions *faster* than the theoretical "ideal" time prescribed by your hardware. Following this characterization of benchmark noise, we can describe the behavior of our estimators:

- The minimum is a robust estimator for the location parameter of the time distribution, and should not be considered an outlier
- The median, as a robust measure of central tendency, should be relatively unaffected by outliers
- The mean, as a non-robust measure of central tendency, will usually be positively skewed by outliers
- The maximum should be considered a primarily noise-driven outlier, and can change drastically between benchmark trials.

### `TrialRatio` and `TrialJudgement`

BenchmarkTools supplies a `ratio` function for comparing two values:

```julia
julia> ratio(3, 2)
1.5

julia> ratio(1, 0)
Inf

julia> ratio(0, 1)
0.0

# a == b is special-cased to 1.0 to prevent NaNs in this case
julia> ratio(0, 0)
1.0
```

Calling the `ratio` function on two `TrialEstimate` instances compares their fields:

```julia
julia> using BenchmarkTools

julia> b = @benchmarkable eigen(rand(10, 10));

julia> tune!(b);

julia> m1 = median(run(b))
BenchmarkTools.TrialEstimate:
  time:             38.638 μs
  gctime:           0.000 ns (0.00%)
  memory:           9.30 KiB
  allocs:           28

julia> m2 = median(run(b))
BenchmarkTools.TrialEstimate:
  time:             38.723 μs
  gctime:           0.000 ns (0.00%)
  memory:           9.30 KiB
  allocs:           28

julia> ratio(m1, m2)
BenchmarkTools.TrialRatio:
  time:             0.997792009916587
  gctime:           1.0
  memory:           1.0
  allocs:           1.0
```

Use the `judge` function to decide if the estimate passed as first argument represents a regression versus the second estimate:

```julia
julia> m1 = median(@benchmark eigen(rand(10, 10)))
BenchmarkTools.TrialEstimate:
  time:             38.745 μs
  gctime:           0.000 ns (0.00%)
  memory:           9.30 KiB
  allocs:           28

julia> m2 = median(@benchmark eigen(rand(10, 10)))
BenchmarkTools.TrialEstimate:
  time:             38.611 μs
  gctime:           0.000 ns (0.00%)
  memory:           9.30 KiB
  allocs:           28

# percent change falls within noise tolerance for all fields
julia> judge(m1, m2)
BenchmarkTools.TrialJudgement:
  time:   +0.35% => invariant (5.00% tolerance)
  memory: +0.00% => invariant (1.00% tolerance)

# changing time_tolerance causes it to be marked as a regression
julia> judge(m1, m2; time_tolerance = 0.0001)
BenchmarkTools.TrialJudgement:
  time:   +0.35% => regression (0.01% tolerance)
  memory: +0.00% => invariant (1.00% tolerance)

# switch m1 & m2; from this perspective, the difference is an improvement
julia> judge(m2, m1; time_tolerance = 0.0001)
BenchmarkTools.TrialJudgement:
  time:   -0.35% => improvement (0.01% tolerance)
  memory: +0.00% => invariant (1.00% tolerance)

# you can pass in TrialRatios as well
julia> judge(ratio(m1, m2)) == judge(m1, m2)
true
```

Note that changes in GC time and allocation count aren't classified by `judge`. This is because GC time and allocation count, while sometimes useful for answering *why* a regression occurred, are not generally useful for answering *if* a regression occurred. Instead, it's usually only differences in time and memory usage that determine whether or not a code change is an improvement or a regression. For example, in the unlikely event that a code change decreased time and memory usage, but increased GC time and allocation count, most people would consider that code change to be an improvement. The opposite is also true: an increase in time and memory usage would be considered a regression no matter how much GC time or allocation count decreased.

## The `BenchmarkGroup` type

In the real world, one often deals with whole suites of benchmarks rather than just individual benchmarks. The `BenchmarkGroup` type serves as the "organizational unit" of such suites, and can be used to store and structure benchmark definitions, raw `Trial` data, estimation results, and even other `BenchmarkGroup` instances.

### Defining benchmark suites

A `BenchmarkGroup` stores a `Dict` that maps benchmark IDs to values, as well as descriptive "tags" that can be used to filter the group by topic. To get started, let's demonstrate how one might use the `BenchmarkGroup` type to define a simple benchmark suite:

```julia
# Define a parent BenchmarkGroup to contain our suite
suite = BenchmarkGroup()

# Add some child groups to our benchmark suite. The most relevant BenchmarkGroup constructor
# for this case is BenchmarkGroup(tags::Vector). These tags are useful for
# filtering benchmarks by topic, which we'll cover in a later section.
suite["utf8"] = BenchmarkGroup(["string", "unicode"])
suite["trig"] = BenchmarkGroup(["math", "triangles"])

# Add some benchmarks to the "utf8" group
teststr = join(rand('a':'d', 10^4));
suite["utf8"]["replace"] = @benchmarkable replace($teststr, "a" => "b")
suite["utf8"]["join"] = @benchmarkable join($teststr, $teststr)

# Add some benchmarks to the "trig" group
for f in (sin, cos, tan)
    for x in (0.0, pi)
        suite["trig"][string(f), x] = @benchmarkable $(f)($x)
    end
end
```

Let's look at our newly defined suite in the REPL:

```julia
julia> suite
2-element BenchmarkTools.BenchmarkGroup:
  tags: []
  "utf8" => 2-element BenchmarkTools.BenchmarkGroup:
	  tags: ["string", "unicode"]
	  "join" => Benchmark(evals=1, seconds=5.0, samples=10000)
	  "replace" => Benchmark(evals=1, seconds=5.0, samples=10000)
  "trig" => 6-element BenchmarkTools.BenchmarkGroup:
	  tags: ["math", "triangles"]
	  ("cos", 0.0) => Benchmark(evals=1, seconds=5.0, samples=10000)
	  ("sin", π = 3.1415926535897...) => Benchmark(evals=1, seconds=5.0, samples=10000)
	  ("tan", π = 3.1415926535897...) => Benchmark(evals=1, seconds=5.0, samples=10000)
	  ("cos", π = 3.1415926535897...) => Benchmark(evals=1, seconds=5.0, samples=10000)
	  ("sin", 0.0) => Benchmark(evals=1, seconds=5.0, samples=10000)
	  ("tan", 0.0) => Benchmark(evals=1, seconds=5.0, samples=10000)
```

As you might imagine, `BenchmarkGroup` supports a subset of Julia's `Associative` interface. A full list of
these supported functions can be found [in the reference document](reference.md#benchmarkgrouptagsvector-datadict).

One can also create a nested `BenchmarkGroup` simply by indexing the keys:

```julia
suite2 = BenchmarkGroup()

suite2["my"]["nested"]["benchmark"] = @benchmarkable sum(randn(32))
```

which will result in a hierarchical benchmark without us needing to create the `BenchmarkGroup` at each level ourselves.

Note that keys are automatically created upon access, even if a key does not exist. Thus, if you wish
to empty the unused keys, you can use `clear_empty!(suite)` to do so.

### Tuning and running a `BenchmarkGroup`

Similarly to individual benchmarks, you can `tune!` and `run` whole `BenchmarkGroup` instances (following from the previous section):

```julia
# execute `tune!` on every benchmark in `suite`
julia> tune!(suite);

# run with a time limit of ~1 second per benchmark
julia> results = run(suite, verbose = true, seconds = 1)
(1/2) benchmarking "utf8"...
  (1/2) benchmarking "join"...
  done (took 1.15406904 seconds)
  (2/2) benchmarking "replace"...
  done (took 0.47660775 seconds)
done (took 1.697970114 seconds)
(2/2) benchmarking "trig"...
  (1/6) benchmarking ("tan",π = 3.1415926535897...)...
  done (took 0.371586549 seconds)
  (2/6) benchmarking ("cos",0.0)...
  done (took 0.284178292 seconds)
  (3/6) benchmarking ("cos",π = 3.1415926535897...)...
  done (took 0.338527685 seconds)
  (4/6) benchmarking ("sin",π = 3.1415926535897...)...
  done (took 0.345329397 seconds)
  (5/6) benchmarking ("sin",0.0)...
  done (took 0.309887335 seconds)
  (6/6) benchmarking ("tan",0.0)...
  done (took 0.320894744 seconds)
done (took 2.022673065 seconds)
BenchmarkTools.BenchmarkGroup:
  tags: []
  "utf8" => BenchmarkGroup(["string", "unicode"])
  "trig" => BenchmarkGroup(["math", "triangles"])
```

### Working with trial data in a `BenchmarkGroup`

Following from the previous section, we see that running our benchmark suite returns a
`BenchmarkGroup` that stores `Trial` data instead of benchmarks:

```julia
julia> results["utf8"]
BenchmarkTools.BenchmarkGroup:
  tags: ["string", "unicode"]
  "join" => Trial(133.84 ms) # summary(::Trial) displays the minimum time estimate
  "replace" => Trial(202.3 μs)

julia> results["trig"]
BenchmarkTools.BenchmarkGroup:
  tags: ["math", "triangles"]
  ("tan",π = 3.1415926535897...) => Trial(28.0 ns)
  ("cos",0.0) => Trial(6.0 ns)
  ("cos",π = 3.1415926535897...) => Trial(22.0 ns)
  ("sin",π = 3.1415926535897...) => Trial(21.0 ns)
  ("sin",0.0) => Trial(6.0 ns)
  ("tan",0.0) => Trial(6.0 ns)
```

Most of the functions on result-related types (`Trial`, `TrialEstimate`, `TrialRatio`, and `TrialJudgement`) work on `BenchmarkGroup`s as well. Usually, these functions simply map onto the groups' values:

```julia
julia> m1 = median(results["utf8"]) # == median(results["utf8"])
BenchmarkTools.BenchmarkGroup:
  tags: ["string", "unicode"]
  "join" => TrialEstimate(143.68 ms)
  "replace" => TrialEstimate(203.24 μs)

julia> m2 = median(run(suite["utf8"]))
BenchmarkTools.BenchmarkGroup:
  tags: ["string", "unicode"]
  "join" => TrialEstimate(144.79 ms)
  "replace" => TrialEstimate(202.49 μs)

julia> judge(m1, m2; time_tolerance = 0.001) # use 0.1 % time tolerance
BenchmarkTools.BenchmarkGroup:
  tags: ["string", "unicode"]
  "join" => TrialJudgement(-0.76% => improvement)
  "replace" => TrialJudgement(+0.37% => regression)
```

### Indexing into a `BenchmarkGroup` using `@tagged`

Sometimes, especially in large benchmark suites, you'd like to filter benchmarks by topic without necessarily worrying about the key-value structure of the suite. For example, you might want to run all string-related benchmarks, even though they might be spread out among many different groups or subgroups. To solve this problem, the `BenchmarkGroup` type incorporates a tagging system.

Consider the following `BenchmarkGroup`, which contains several nested child groups that are all individually tagged:

```julia
julia> g = BenchmarkGroup([], # no tags in the parent
                          "c" => BenchmarkGroup(["5", "6", "7"]), # tagged "5", "6", "7"
                          "b" => BenchmarkGroup(["3", "4", "5"]), # tagged "3", "4", "5"
                          "a" => BenchmarkGroup(["1", "2", "3"],  # contains tags and child groups
                                                "d" => BenchmarkGroup(["8"], 1 => 1),
                                                "e" => BenchmarkGroup(["9"], 2 => 2)));
julia> g
BenchmarkTools.BenchmarkGroup:
  tags: []
  "c" => BenchmarkTools.BenchmarkGroup:
	  tags: ["5", "6", "7"]
  "b" => BenchmarkTools.BenchmarkGroup:
	  tags: ["3", "4", "5"]
  "a" => BenchmarkTools.BenchmarkGroup:
	  tags: ["1", "2", "3"]
	  "e" => BenchmarkTools.BenchmarkGroup:
		  tags: ["9"]
		  2 => 2
	  "d" => BenchmarkTools.BenchmarkGroup:
		  tags: ["8"]
		  1 => 1
```

We can filter this group by tag using the `@tagged` macro. This macro takes in a special predicate, and returns an object that can be used to index into a `BenchmarkGroup`. For example, we can select all groups marked `"3"` or `"7"` and not `"1"`:

```julia
julia> g[@tagged ("3" || "7") && !("1")]
BenchmarkTools.BenchmarkGroup:
  tags: []
  "c" => BenchmarkGroup(["5", "6", "7"])
  "b" => BenchmarkGroup(["3", "4", "5"])
```

As you can see, the allowable syntax for the `@tagged` predicate includes `!`, `()`, `||`, `&&`, in addition to the tags themselves. The `@tagged` macro replaces each tag in the predicate expression with a check to see if the group has the
given tag, returning `true` if so and `false` otherwise. A group `g` is considered to have a given tag `t` if:

- `t` is attached explicitly to `g` by construction (e.g. `g = BenchmarkGroup([t])`)
- `t` is a key that points to `g` in `g`'s parent group (e.g. `BenchmarkGroup([], t => g)`)
- `t` is a tag of one of `g`'s parent groups (all the way up to the root group)

To demonstrate the last two points:

```julia
# also could've used `@tagged "1"`, `@tagged "a"`, `@tagged "e" || "d"`
julia> g[@tagged "8" || "9"]
BenchmarkTools.BenchmarkGroup:
  tags: []
  "a" => BenchmarkTools.BenchmarkGroup:
	  tags: ["1", "2", "3"]
	  "e" => BenchmarkTools.BenchmarkGroup:
		  tags: ["9"]
		  2 => 2
	  "d" => BenchmarkTools.BenchmarkGroup:
		  tags: ["8"]
		  1 => 1

julia> g[@tagged "d"]
BenchmarkTools.BenchmarkGroup:
    tags: []
    "a" => BenchmarkTools.BenchmarkGroup:
	  tags: ["1", "2", "3"]
	  "d" => BenchmarkTools.BenchmarkGroup:
		  tags: ["8"]
		  1 => 1

julia> g[@tagged "9"]
BenchmarkTools.BenchmarkGroup:
  tags: []
  "a" => BenchmarkTools.BenchmarkGroup:
	  tags: ["1", "2", "3"]
	  "e" => BenchmarkTools.BenchmarkGroup:
		  tags: ["9"]
		  2 => 2
```

### Indexing into a `BenchmarkGroup` using another `BenchmarkGroup`

It's sometimes useful to create `BenchmarkGroup` where the keys are drawn from one `BenchmarkGroup`, but the values are drawn from another. You can accomplish this by indexing into the latter `BenchmarkGroup` with the former:

```julia
julia> g # leaf values are integers
BenchmarkTools.BenchmarkGroup:
  tags: []
  "c" => BenchmarkTools.BenchmarkGroup:
	  tags: []
	  "1" => 1
	  "2" => 2
	  "3" => 3
  "b" => BenchmarkTools.BenchmarkGroup:
	  tags: []
	  "1" => 1
	  "2" => 2
	  "3" => 3
  "a" => BenchmarkTools.BenchmarkGroup:
	  tags: []
	  "1" => 1
	  "2" => 2
	  "3" => 3
  "d" => BenchmarkTools.BenchmarkGroup:
	  tags: []
	  "1" => 1
	  "2" => 2
	  "3" => 3

julia> x # note that leaf values are characters
BenchmarkTools.BenchmarkGroup:
  tags: []
  "c" => BenchmarkTools.BenchmarkGroup:
	  tags: []
	  "2" => '2'
  "a" => BenchmarkTools.BenchmarkGroup:
	  tags: []
	  "1" => '1'
	  "3" => '3'
  "d" => BenchmarkTools.BenchmarkGroup:
	  tags: []
	  "1" => '1'
	  "2" => '2'
	  "3" => '3'

julia> g[x] # index into `g` with the keys of `x`
BenchmarkTools.BenchmarkGroup:
  tags: []
  "c" => BenchmarkTools.BenchmarkGroup:
	  tags: []
	  "2" => 2
  "a" => BenchmarkTools.BenchmarkGroup:
	  tags: []
	  "1" => 1
	  "3" => 3
  "d" => BenchmarkTools.BenchmarkGroup:
	  tags: []
	  "1" => 1
	  "2" => 2
	  "3" => 3
```

An example scenario where this would be useful: You have a suite of benchmarks, and a corresponding group of `TrialJudgement`s, and you want to rerun the benchmarks in your suite that are considered regressions in the judgement group. You can easily do this with the following code:

```julia
run(suite[regressions(judgements)])
```

### Indexing into a `BenchmarkGroup` using a `Vector`

You may have noticed that nested `BenchmarkGroup` instances form a tree-like structure, where the root node is the parent group, intermediate nodes are child groups, and the leaves take values like trial data and benchmark definitions.

Since these trees can be arbitrarily asymmetric, it can be cumbersome to write certain `BenchmarkGroup` transformations using only the indexing facilities previously discussed.

To solve this problem, BenchmarkTools allows you to uniquely index group nodes using a `Vector` of the node's parents' keys. For example:

```julia
julia> g = BenchmarkGroup([], 1 => BenchmarkGroup([], "a" => BenchmarkGroup([], :b => 1234)));

julia> g
BenchmarkTools.BenchmarkGroup:
  tags: []
  1 => BenchmarkTools.BenchmarkGroup:
	  tags: []
	  "a" => BenchmarkTools.BenchmarkGroup:
		  tags: []
		  :b => 1234

julia> g[[1]] # == g[1]
BenchmarkTools.BenchmarkGroup:
  tags: []
  "a" => BenchmarkTools.BenchmarkGroup:
	  tags: []
	  :b => 1234
julia> g[[1, "a"]] # == g[1]["a"]
BenchmarkTools.BenchmarkGroup:
  tags: []
  :b => 1234
julia> g[[1, "a", :b]] # == g[1]["a"][:b]
1234
```

Keep in mind that this indexing scheme also works with `setindex!`:

```julia
julia> g[[1, "a", :b]] = "hello"
"hello"

julia> g
BenchmarkTools.BenchmarkGroup:
  tags: []
  1 => BenchmarkTools.BenchmarkGroup:
	  tags: []
	  "a" => BenchmarkTools.BenchmarkGroup:
		  tags: []
		  :b => "hello"
```

Assigning into a `BenchmarkGroup` with a `Vector` creates sub-groups as necessary:

```julia
julia>  g[[2, "a", :b]] = "hello again"
"hello again"

julia> g
2-element BenchmarkTools.BenchmarkGroup:
  tags: []
  2 => 1-element BenchmarkTools.BenchmarkGroup:
          tags: []
          "a" => 1-element BenchmarkTools.BenchmarkGroup:
                  tags: []
                  :b => "hello again"
  1 => 1-element BenchmarkTools.BenchmarkGroup:
          tags: []
          "a" => 1-element BenchmarkTools.BenchmarkGroup:
                  tags: []
                  :b => "hello"
```

You can use the `leaves` function to construct an iterator over a group's leaf index/value pairs:

```julia
julia> g = BenchmarkGroup(["1"],
                          "2" => BenchmarkGroup(["3"], 1 => 1),
                          4 => BenchmarkGroup(["3"], 5 => 6),
                          7 => 8,
                          9 => BenchmarkGroup(["2"],
                                              10 => BenchmarkGroup(["3"]),
                                              11 => BenchmarkGroup()));

julia> collect(leaves(g))
3-element Array{Any,1}:
 ([7],8)
 ([4,5],6)
 (["2",1],1)
```

Note that terminal child group nodes are not considered "leaves" by the `leaves` function.

## Caching `Parameters`

A common workflow used in BenchmarkTools is the following:

1. Start a Julia session
2. Execute a benchmark suite using an old version of your package
3. Save the results somehow (e.g. in a JSON file)
4. Start a new Julia session
5. Execute a benchmark suite using a new version of your package
6. Compare the new results with the results saved in step 3 to determine regression status

There are a couple of problems with this workflow, and all of which revolve around parameter tuning (which would occur during steps 2 and 5):

- Consistency: Given enough time, successive calls to `tune!` will usually yield reasonably consistent values for the "evaluations per sample" parameter, even in spite of noise. However, some benchmarks are highly sensitive to slight changes in this parameter. Thus, it would be best to have some guarantee that all experiments are configured equally (i.e., a guarantee that step 2 will use the exact same parameters as step 5).
- Turnaround time: For most benchmarks, `tune!` needs to perform many evaluations to determine the proper parameters for any given benchmark - often more evaluations than are performed when running a trial. In fact, the majority of total benchmarking time is usually spent tuning parameters, rather than actually running trials.

BenchmarkTools solves these problems by allowing you to pre-tune your benchmark suite, save the "evaluations per sample" parameters, and load them on demand:

```julia
# untuned example suite
julia> suite
BenchmarkTools.BenchmarkGroup:
  tags: []
  "utf8" => BenchmarkGroup(["string", "unicode"])
  "trig" => BenchmarkGroup(["math", "triangles"])

# tune the suite to configure benchmark parameters
julia> tune!(suite);

# save the suite's parameters using a thin wrapper
# over JSON (this wrapper maintains compatibility
# across BenchmarkTools versions)
julia> BenchmarkTools.save("params.json", params(suite));
```

Now, instead of tuning `suite` every time we load the benchmarks in a new Julia session, we can simply load the parameters in the JSON file using the `loadparams!` function. The `[1]` on the `load` call gets the first value that was serialized into the JSON file, which in this case is the parameters.

```julia
# syntax is loadparams!(group, paramsgroup, fields...)
julia> loadparams!(suite, BenchmarkTools.load("params.json")[1], :evals, :samples);
```

Caching parameters in this manner leads to a far shorter turnaround time, and more importantly, much more consistent results.

## Visualizing benchmark results

For comparing two or more benchmarks against one another, you can manually specify the range of the histogram using an
`IOContext` to set `:histmin` and `:histmax`:

```julia
julia> io = IOContext(stdout, :histmin=>0.5, :histmax=>10, :logbins=>true)
IOContext(Base.TTY(RawFD(13) open, 0 bytes waiting))

julia> b1 = @benchmark x^3   setup=(x = rand()); show(io, MIME("text/plain"), b1)
┌ Trial:
│  min 0.875 ns, median 0.958 ns, mean 0.958 ns, 99ᵗʰ 1.042 ns
│  0 allocations
│    ◑* 
│     █▁                                                                    ▁
│  ▁▁▇██▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁ █
└  0.5 ns   log(counts) from 10_000 samples, each 1_000 evaluations   10 ns +

julia> b2 = @benchmark x^3.0 setup=(x = rand()); show(io, MIME("text/plain"), b2)
┌ Trial:
│  min 8.258 ns, median 8.342 ns, mean 8.440 ns, 99ᵗʰ 8.718 ns
│  0 allocations
│                                                            ◑* 
│                                                             █▅▄           ▁
│  ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▇████▁▁▁▁▁▁▁▁▁ █
└  0.5 ns    log(counts) from 10_000 samples, each 999 evaluations    10 ns +
```

Setting `:logbins` to `true` plots a graph with the log of the number of samples on
its vertical axis, instead of an ordinary histogram with the linear count of samples.
The lowest bar `▁` (drawn in grey when the terminal supports color) still indicates
zero counts.

The `Trial` object can be visualized using the `BenchmarkPlots` package:

```julia
using BenchmarkPlots, StatsPlots
b = @benchmarkable lu(rand(1000, 1000))
t = run(b)

plot(t)

# TODO -- yaxis=:log10 leads to Warning: No strict ticks found
# and  st=:box  leads to Warning: Keyword argument hover not supported with Plots.GRBackend
```

This will show the timing results of the trial as a violin plot. You can use
all the keyword arguments from `Plots.jl`, for instance `st=:box` or
`yaxis=:log10`.

If a `BenchmarkGroup` contains (only) `Trial`s, its results can be visualized
simply by

```julia
using BenchmarkPlots, StatsPlots
t = run(g)
plot(t)
```

This will display each `Trial` as a violin plot.

## Miscellaneous tips and info

- BenchmarkTools restricts the minimum measurable benchmark execution time to one picosecond.
- If you use `rand` or something similar to generate the values that are used in your benchmarks, you should seed the RNG (or provide a seeded RNG) so that the values are consistent between trials/samples/evaluations.
- BenchmarkTools attempts to be robust against machine noise occurring between *samples*, but BenchmarkTools can't do very much about machine noise occurring between *trials*. To cut down on the latter kind of noise, it is advised that you dedicate CPUs and memory to the benchmarking Julia process by using a shielding tool such as [cset](http://manpages.ubuntu.com/manpages/precise/man1/cset.1.html).
- On some machines, for some versions of BLAS and Julia, the number of BLAS worker threads can exceed the number of available cores. This can occasionally result in scheduling issues and inconsistent performance for BLAS-heavy benchmarks. To fix this issue, you can use `BLAS.set_num_threads(i::Int)` in the Julia REPL to ensure that the number of BLAS threads is equal to or less than the number of available cores.
- `@benchmark` is evaluated in global scope, even if called from local scope.
