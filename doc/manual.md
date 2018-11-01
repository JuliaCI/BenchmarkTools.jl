This document provides in-depth on the design and use of BenchmarkTools. If you're looking for an overview of the API, try [reading the API reference document instead](reference.md).

# Table of Contents

Bold links indicate sections that should be read carefully in order to avoid common benchmarking pitfalls.

- [Introduction](#introduction)
- [Benchmarking basics](#defining-and-executing-benchmarks)
    * [Defining and executing benchmarks](#defining-and-executing-benchmarks)
    * [Benchmark `Parameters`](#benchmark-parameters)
    * **[Interpolating values into benchmark expressions](#interpolating-values-into-benchmark-expressions)**
    * [Setup and teardown phases](#setup-and-teardown-phases)
    * [Understanding compiler optimizations](#understanding-compiler-optimizations)
- [Handling benchmark results](#handling-benchmark-results)
    * [`Trial` and `TrialEstimate`](#trial-and-trialestimate)
    * **[Which estimator should I use?](#which-estimator-should-i-use)**
    * [`TrialRatio` and `TrialJudgement`](#trialratio-and-trialjudgement)
- [The `BenchmarkGroup` type](#the-benchmarkgroup-type)
    * [Defining benchmark suites](#defining-benchmark-suites)
    * [Tuning and running a `BenchmarkGroup`](#tuning-and-running-a-benchmarkgroup)
    * [Working with trial data in a `BenchmarkGroup`](#working-with-trial-data-in-a-benchmarkgroup)
    * [Indexing into a `BenchmarkGroup` using `@tagged`](#indexing-into-a-benchmarkgroup-using-tagged)
    * [Indexing into a `BenchmarkGroup` using another `BenchmarkGroup`](#indexing-into-a-benchmarkgroup-using-another-benchmarkgroup)
    * [Indexing into a `BenchmarkGroup` using a `Vector`](#indexing-into-a-benchmarkgroup-using-a-vector)
- **[Caching `Parameters`](#caching-parameters)**
- [Miscellaneous tips and info](#miscellaneous-tips-and-info)

# Introduction

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

# Benchmarking basics

### Defining and executing benchmarks

To quickly benchmark a Julia expression, use `@benchmark`:

```julia
julia> @benchmark sin(1)
BenchmarkTools.Trial:
  memory estimate:  0 bytes
  allocs estimate:  0
  --------------
  minimum time:     13.610 ns (0.00% GC)
  median time:      13.622 ns (0.00% GC)
  mean time:        13.638 ns (0.00% GC)
  maximum time:     21.084 ns (0.00% GC)
  --------------
  samples:          10000
  evals/sample:     998
```

The `@benchmark` macro is essentially shorthand for defining a benchmark, auto-tuning the benchmark's configuration parameters, and running the benchmark. These three steps can be done explicitly using `@benchmarkable`, `tune!` and `run`:

```julia
julia> b = @benchmarkable sin(1); # define the benchmark with default parameters

# find the right evals/sample and number of samples to take for this benchmark
julia> tune!(b);

julia> run(b)
BenchmarkTools.Trial:
  memory estimate:  0 bytes
  allocs estimate:  0
  --------------
  minimum time:     13.605 ns (0.00% GC)
  median time:      13.618 ns (0.00% GC)
  mean time:        13.631 ns (0.00% GC)
  maximum time:     22.383 ns (0.00% GC)
  --------------
  samples:          10000
  evals/sample:     998
```

Alternatively, you can use the `@btime` or `@belapsed` macros.
These take exactly the same arguments as `@benchmark`, but
behave like the `@time` or `@elapsed` macros included with
Julia: `@btime` prints the minimum time and memory allocation
before returning the value of the expression, while `@elapsed`
returns the minimum time in seconds.

```julia
julia> @btime sin(1)
  13.612 ns (0 allocations: 0 bytes)
0.8414709848078965

julia> @belapsed sin(1)
1.3614228456913828e-8
```

### Benchmark `Parameters`

You can pass the following keyword arguments to `@benchmark`, `@benchmarkable`, and `run` to configure the execution process:

- `samples`: The number of samples to take. Execution will end if this many samples have been collected. Defaults to `BenchmarkTools.DEFAULT_PARAMETERS.samples = 10000`.
- `seconds`: The number of seconds budgeted for the benchmarking process. The trial will terminate if this time is exceeded (regardless of `samples`), but at least one sample will always be taken. In practice, actual runtime can overshoot the budget by the duration of a sample. Defaults to `BenchmarkTools.DEFAULT_PARAMETERS.seconds = 5`.
- `evals`: The number of evaluations per sample. For best results, this should be kept consistent between trials. A good guess for this value can be automatically set on a benchmark via `tune!`, but using `tune!` can be less consistent than setting `evals` manually. Defaults to `BenchmarkTools.DEFAULT_PARAMETERS.evals = 1`.
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
julia> @benchmark sum(rand(1000))
BenchmarkTools.Trial:
  memory estimate:  7.94 KiB
  allocs estimate:  1
  --------------
  minimum time:     1.566 μs (0.00% GC)
  median time:      2.135 μs (0.00% GC)
  mean time:        3.071 μs (25.06% GC)
  maximum time:     296.818 μs (95.91% GC)
  --------------
  samples:          10000
  evals/sample:     10

# rand(1000) is evaluated at definition time, and the resulting
# value is interpolated into the benchmark expression
julia> @benchmark sum($(rand(1000)))
BenchmarkTools.Trial:
  memory estimate:  0 bytes
  allocs estimate:  0
  --------------
  minimum time:     101.627 ns (0.00% GC)
  median time:      101.909 ns (0.00% GC)
  mean time:        103.834 ns (0.00% GC)
  maximum time:     276.033 ns (0.00% GC)
  --------------
  samples:          10000
  evals/sample:     935
```

A good rule of thumb is that **external variables should be explicitly interpolated into the benchmark expression**:

```julia
julia> A = rand(1000);

# BAD: A is a global variable in the benchmarking context
julia> @benchmark [i*i for i in A]
BenchmarkTools.Trial:
  memory estimate:  7.95 KiB
  allocs estimate:  2
  --------------
  minimum time:     13.154 μs (0.00% GC)
  median time:      13.806 μs (0.00% GC)
  mean time:        14.071 μs (0.00% GC)
  maximum time:     337.462 μs (0.00% GC)
  --------------
  samples:          10000
  evals/sample:     1

# GOOD: A is a constant value in the benchmarking context
julia> @benchmark [i*i for i in $A]
BenchmarkTools.Trial:
  memory estimate:  7.95 KiB
  allocs estimate:  2
  --------------
  minimum time:     929.375 ns (0.00% GC)
  median time:      1.348 μs (0.00% GC)
  mean time:        2.405 μs (36.64% GC)
  maximum time:     91.481 μs (95.46% GC)
  --------------
  samples:          10000
  evals/sample:     32
```

(Note that "KiB" is the SI prefix for a [kibibyte](https://en.wikipedia.org/wiki/Kibibyte): 1024 bytes.)

Keep in mind that you can mutate external state from within a benchmark:

```julia
julia> A = zeros(3);

 # each evaluation will modify A
julia> b = @benchmarkable fill!($A, rand());

julia> run(b, samples = 1);

julia> A
3-element Array{Float64,1}:
 0.837789
 0.837789
 0.837789

julia> run(b, samples = 1);

julia> A
3-element Array{Float64,1}:
 0.647885
 0.647885
 0.647885
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
julia> x = rand(100000);

# For each sample, bind a variable `y` to a fresh copy of `x`. As you
# can see, `y` is accessible within the scope of the core expression.
julia> b = @benchmarkable sort!(y) setup=(y = copy($x))
Benchmark(evals=1, seconds=5.0, samples=10000)

julia> run(b)
BenchmarkTools.Trial:
  memory estimate:  0 bytes
  allocs estimate:  0
  --------------
  minimum time:     5.739 ms (0.00% GC)
  median time:      5.757 ms (0.00% GC)
  mean time:        5.871 ms (0.00% GC)
  maximum time:     62.138 ms (0.00% GC)
  --------------
  samples:          805
  evals/sample:     1
```

In the above example, we wish to benchmark Julia's in-place sorting method. Without a setup phase, we'd have to either allocate a new input vector for each sample (such that the allocation time would pollute our results) or use the same input vector every sample (such that all samples but the first would benchmark the wrong thing - sorting an already sorted vector). The setup phase solves the problem by allowing us to do some work that can be utilized by the core expression, without that work being erroneously included in our performance results.

Note that the `setup` and `teardown` phases are **executed for each sample, not each evaluation**. Thus, the sorting example above wouldn't produce the intended results if `evals/sample > 1` (it'd suffer from the same problem of benchmarking against an already sorted vector).

### Understanding compiler optimizations

It's possible for LLVM and Julia's compiler to perform optimizations on `@benchmarkable` expressions. In some cases, these optimizations can elide a computation altogether, resulting in unexpectedly "fast" benchmarks. For example, the following expression is non-allocating:

```julia
julia> @benchmark (view(a, 1:2, 1:2); 1) setup=(a = rand(3, 3))
BenchmarkTools.Trial:
  memory estimate:  0 bytes
  allocs estimate:  0
  --------------
  minimum time:     2.293 ns (0.00% GC)
  median time:      2.302 ns (0.00% GC)
  mean time:        2.330 ns (0.00% GC)
  maximum time:     6.441 ns (0.00% GC)
  --------------
  samples:          10000
  evals/sample:     1000

```

Note, however, that this does not mean that `view(a, 1:2, 1:2)` is non-allocating:

```julia
julia> @benchmark view(a, 1:2, 1:2) setup=(a = rand(3, 3))
BenchmarkTools.Trial:
  memory estimate:  64 bytes
  allocs estimate:  1
  --------------
  minimum time:     15.613 ns (0.00% GC)
  median time:      17.825 ns (0.00% GC)
  mean time:        23.358 ns (17.46% GC)
  maximum time:     1.725 μs (95.12% GC)
  --------------
  samples:          10000
  evals/sample:     998
```

The key point here is that these two benchmarks measure different things, even though their code is similar. In the first example, Julia was able to optimize away `view(a, 1:2, 1:2)` because it could prove that the value wasn't being returned and `a` wasn't being mutated. In the second example, the optimization is not performed because `view(a, 1:2, 1:2)` is a return value of the benchmark expression.

In conclusion, BenchmarkTools will faithfully report the performance of the exact code that you provide to it, including any compiler optimizations that might happen to elide the code completely. It's up to you to design benchmarks which actually exercise the code you intend to exercise.

# Handling benchmark results

BenchmarkTools provides four types related to benchmark results:

- `Trial`: stores all samples collected during a benchmark trial, as well as the trial's parameters
- `TrialEstimate`: a single estimate used to summarize a `Trial`
- `TrialRatio`: a comparison between two `TrialEstimate`
- `TrialJudgement`: a classification of the fields of a `TrialRatio` as `invariant`, `regression`, or `improvement`

This section provides a limited number of examples demonstrating these types. For a thorough list of supported functionality, see [the reference document](reference.md).

### `Trial` and `TrialEstimate`

Running a benchmark produces an instance of the `Trial` type:

```julia
julia> t = @benchmark eig(rand(10, 10))
BenchmarkTools.Trial:
  memory estimate:  9.30 KiB
  allocs estimate:  28
  --------------
  minimum time:     33.262 μs (0.00% GC)
  median time:      38.618 μs (0.00% GC)
  mean time:        39.981 μs (2.65% GC)
  maximum time:     2.814 ms (95.07% GC)
  --------------
  samples:          10000
  evals/sample:     1

julia> dump(t) # here's what's actually stored in a Trial
  BenchmarkTools.Trial
    params: BenchmarkTools.Parameters # Trials store the parameters of their parent process
      seconds: Float64 5.0
      samples: Int64 10000
      evals: Int64 1
      overhead: Float64 0.0
      gctrial: Bool true
      gcsample: Bool false
      time_tolerance: Float64 0.05
      memory_tolerance: Float64 0.01
    times: Array{Float64}((10000,)) [33262.0, 33793.0, … 2.77342e6, 2.81368e6] # every sample is stored in the Trial
    gctimes: Array{Float64}((10000,)) [0.0, 0.0, … 2.66614e6, 2.67486e6]
    memory: Int64 9520
    allocs: Int64 28
```

As you can see from the above, a couple of different timing estimates are pretty-printed with the `Trial`. You can calculate these estimates yourself using the `minimum`, `median`, `mean`, and `maximum` functions:

```julia
julia> minimum(t)
BenchmarkTools.TrialEstimate:
  time:             33.262 μs
  gctime:           0.000 ns (0.00%)
  memory:           9.30 KiB
  allocs:           28

julia> median(t)
BenchmarkTools.TrialEstimate:
  time:             38.618 μs
  gctime:           0.000 ns (0.00%)
  memory:           9.30 KiB
  allocs:           28

julia> mean(t)
BenchmarkTools.TrialEstimate:
  time:             39.981 μs
  gctime:           1.058 μs (2.65%)
  memory:           9.30 KiB
  allocs:           28

julia> maximum(t)
BenchmarkTools.TrialEstimate:
  time:             2.814 ms
  gctime:           2.675 ms (95.07%)
  memory:           9.30 KiB
  allocs:           28
```

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

julia> b = @benchmarkable eig(rand(10, 10));

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

Use the `judge` function to decide if one estimate represents a regression versus another estimate:

```julia
julia> m1 = median(@benchmark eig(rand(10, 10)))
BenchmarkTools.TrialEstimate:
  time:             38.745 μs
  gctime:           0.000 ns (0.00%)
  memory:           9.30 KiB
  allocs:           28

julia> m2 = median(@benchmark eig(rand(10, 10)))
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

# The `BenchmarkGroup` type

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
teststr = join(rand(MersenneTwister(1), 'a':'d', 10^4));
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

# Caching `Parameters`

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

# Miscellaneous tips and info

- BenchmarkTools restricts the minimum measurable benchmark execution time to one picosecond.
- If you use `rand` or something similar to generate the values that are used in your benchmarks, you should seed the RNG (or provide a seeded RNG) so that the values are consistent between trials/samples/evaluations.
- BenchmarkTools attempts to be robust against machine noise occurring between *samples*, but BenchmarkTools can't do very much about machine noise occurring between *trials*. To cut down on the latter kind of noise, it is advised that you dedicate CPUs and memory to the benchmarking Julia process by using a shielding tool such as [cset](http://manpages.ubuntu.com/manpages/precise/man1/cset.1.html).
- On some machines, for some versions of BLAS and Julia, the number of BLAS worker threads can exceed the number of available cores. This can occasionally result in scheduling issues and inconsistent performance for BLAS-heavy benchmarks. To fix this issue, you can use `BLAS.set_num_threads(i::Int)` in the Julia REPL to ensure that the number of BLAS threads is equal to or less than the number of available cores.
