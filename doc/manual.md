This document provides in-depth on the design and use of BenchmarkTools. If you're looking for an overview of the API, try [reading the API reference document instead](reference.md).

# Table of Contents

Bold links indicate sections that should be read carefully in order to avoid common benchmarking pitfalls.

- [Introduction](#introduction)
- [Benchmarking basics](#defining-and-executing-benchmarks)
    * [Defining and executing benchmarks](#defining-and-executing-benchmarks)
    * [Tunable benchmark parameters](#tunable-benchmark-parameters)
    * **[Interpolating values into benchmark expressions](#interpolating-values-into-benchmark-expressions)**
    * [Setup and teardown phases](#setup-and-teardown-phases)
- [Handling benchmark results](#handling-benchmark-results)
    * [`Trial` and `TrialEstimate`](#trial-and-trialestimate)
    * **[Which estimator should I use?](#which-estimator-should-i-use)**
    * [`TrialRatio` and `TrialJudgement`](#trialratio-and-trialjudgement)
- [Using `BenchmarkGroup`s](#using-benchmarkgroups)
    * [Defining benchmark suites](#defining-benchmark-suites)
    * [Tuning and running a `BenchmarkGroup`](#tuning-and-running-a-benchmarkgroup)
    * [Working with `BenchmarkGroup` results](#working-with-benchmarkgroup-results)
    * [Filtering a `BenchmarkGroup` by tag](#filtering-a-benchmarkgroup-by-tag)
    * [Indexing into a `BenchmarkGroup` with another `BenchmarkGroup`](#indexing-into-a-benchmarkgroup-with-another-benchmarkgroup)
- **[Increase consistency and decrease execution time by caching benchmark parameters](#increase-consistency-and-decrease-execution-time-by-caching-benchmark-parameters)**
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

The reasoning behind our definition of "sample" may not be obvious to all readers. If the time to execute a benchmark is smaller than the resolution of your timing method, than a single evaluation of the benchmark will generally not produce a valid sample. In that case, one must approximate a valid sample by
recording the total time `t` it takes to record `n` evaluations, and estimating the sample's time per evaluation as `t/n`. For example, if a sample takes 1 second for 1 million evaluations, the approximate time per evaluation for that sample is 1 microsecond. It's not obvious what the right number of evaluations per sample should be for any given benchmark, so BenchmarkTools provides a mechanism (the `tune!` method) to automatically figure it out for you.

# Benchmarking basics

### Defining and executing benchmarks

To quickly benchmark a Julia expression, use `@benchmark`:

```julia
julia> @benchmark sin(1)
BenchmarkTools.Trial:
  samples:          300
  evals/sample:     76924
  time tolerance:   5.0%
  memory tolerance: 5.0%
  memory estimate:  0.0 bytes
  allocs estimate:  0
  minimum time:     13.0 ns (0.0% GC)
  median time:      13.0 ns (0.0% GC)
  mean time:        13.0 ns (0.0% GC)
  maximum time:     14.0 ns (0.0% GC)
```

The `@benchmark` macro is essentially shorthand for defining a benchmark, auto-tuning the benchmark's configuration parameters, and running the benchmark. These three steps can be done explicitly using `@benchmarkable`, `tune!` and `run`:

```julia
julia> b = @benchmarkable sin(1); # define the benchmark with default parameters

julia> tune!(b); # find the right evals/sample for this benchmark

julia> run(b)
BenchmarkTools.Trial:
  samples:          300
  evals/sample:     76924
  time tolerance:   5.0%
  memory tolerance: 5.0%
  memory:           0.0 bytes
  allocs:           0
  minimum time:     13.0 ns (0.0% GC)
  median time:      13.0 ns (0.0% GC)
  mean time:        13.0 ns (0.0% GC)
  maximum time:     14.0 ns (0.0% GC)
```

### Tunable benchmark parameters

You can pass the following keyword arguments to `@benchmark`, `@benchmarkable`, and `run` to configure the execution process:

- `samples`: The number of samples to take. Execution will end if this many samples have been collected. Defaults to `300`.
- `seconds`: The number of seconds budgeted for the benchmarking process. The trial will terminate if this time is exceeded (regardless of `samples`), but at least one sample will always be taken. In practice, actual runtime can overshoot the budget by the duration of a sample. Defaults to `5.0`.
- `evals`: The number of evaluations per sample. For best results, this should be kept consistent between trials. A good guess for this value can be automatically set on a benchmark via `tune!`, but using `tune!` can be less consistent than setting `evals` manually. Defaults to `1`.
- `gctrial`: If `true`, run `gc()` before executing this benchmark's trial. Defaults to `true`.
- `gcsample`: If `true`, run `gc()` before each sample. Defaults to `false`.
- `time_tolerance`: The noise tolerance for the benchmark's time estimate, as a percentage. Defaults to `0.05` (5%).
- `memory_tolerance`: The noise tolerance for the benchmark's memory estimate, as a percentage. Defaults to `0.05` (5%).

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
  samples:          300
  evals/sample:     575
  time tolerance:   5.0%
  memory tolerance: 5.0%
  memory:           7.92 kb
  allocs:           3
  minimum time:     1.9 μs (0.0% GC)
  median time:      2.73 μs (0.0% GC)
  mean time:        3.61 μs (29.72% GC)
  maximum time:     8.77 μs (66.07% GC)

# rand(1000) is evaluated at definition time, and the resulting
# value is interpolated into the benchmark expression
julia> @benchmark sum($(rand(1000)))
BenchmarkTools.Trial:
  samples:          300
  evals/sample:     5209
  time tolerance:   5.0%
  memory tolerance: 5.0%
  memory:           0.0 bytes
  allocs:           0
  minimum time:     192.0 ns (0.0% GC)
  median time:      192.0 ns (0.0% GC)
  mean time:        192.84 ns (0.0% GC)
  maximum time:     196.0 ns (0.0% GC)
```

A good rule of thumb is that **external variables should be explicitly interpolated into the benchmark expression**:

```julia
julia> A = rand(1000);

# BAD: A is a global variable in the benchmarking context
julia> @benchmark [i*i for i in A]
BenchmarkTools.Trial:
  samples:          300
  evals/sample:     2
  time tolerance:   5.0%
  memory tolerance: 5.0%
  memory:           241.62 kb
  allocs:           9960
  minimum time:     887.97 μs (0.0% GC)
  median time:      894.81 μs (0.0% GC)
  mean time:        930.63 μs (3.47% GC)
  maximum time:     2.61 ms (64.13% GC)

# GOOD: A is a constant value in the benchmarking context
julia> @benchmark [i*i for i in $A]
BenchmarkTools.Trial:
  samples:          300
  evals/sample:     807
  time tolerance:   5.0%
  memory tolerance: 5.0%
  memory:           7.89 kb
  allocs:           1
  minimum time:     1.23 μs (0.0% GC)
  median time:      2.04 μs (0.0% GC)
  mean time:        2.92 μs (35.49% GC)
  maximum time:     5.9 μs (67.99% GC)
```

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
### Setup and teardown phases

BenchmarkTools allows you to pass `setup` and `teardown` expressions to `@benchmark` and `@benchmarkable`. The `setup` expression is evaluated just before sample execution, while the `teardown` expression is evaluated just after sample execution. Here's an example where this kind of thing is useful:

```julia
julia> x = rand(100000);

# For each sample, bind a variable `y` to a fresh copy of `x`. As you
# can see, `y` is accessible within the scope of the core expression.
julia> b = @benchmarkable sort!(y) setup=(y = copy($x))
BenchmarkTools.Benchmark{symbol("##benchmark#7556")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05,0.05))

julia> run(b)
BenchmarkTools.Trial:
  samples:          300
  evals/sample:     1
  time tolerance:   5.0%
  memory tolerance: 5.0%
  memory estimate:  0.0 bytes
  allocs estimate:  0
  minimum time:     6.76 ms (0.0% GC)
  median time:      6.81 ms (0.0% GC)
  mean time:        6.82 ms (0.0% GC)
  maximum time:     6.96 ms (0.0% GC)
```

In the above example, we wish to benchmark Julia's in-place sorting method. Without a setup phase, we'd have to either allocate a new input vector for each sample (such that the allocation time would pollute our results) or use the same input vector every sample (such that all samples but the first would benchmark the wrong thing - sorting an already sorted vector). The setup phase solves the problem by allowing us to do some work that can be utilized by the core expression, without that work being erroneously included in our performance results.

Note that the `setup` and `teardown` phases are **executed for each sample, not each evaluation**. Thus, the sorting example above wouldn't produce the intended results if `evals/sample > 1` (it'd suffer from the same problem of benchmarking against an already sorted vector).

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
  samples:          300
  evals/sample:     6
  time tolerance:   5.0%
  memory tolerance: 5.0%
  memory:           20.47 kb
  allocs:           83
  minimum time:     181.82 μs (0.0% GC)
  median time:      187.0 μs (0.0% GC)
  mean time:        203.16 μs (0.7% GC)
  maximum time:     776.57 μs (54.66% GC)

julia> dump(t) # here's what's actually stored in a Trial
BenchmarkTools.Trial
params: BenchmarkTools.Parameters # Trials store the parameters of their parent process
  seconds: Float64 5.0
  samples: Int64 300
  evals: Int64 6
  gctrial: Bool true
  gcsample: Bool false
  time_tolerance: Float64 0.05
  memory_tolerance: Float64 0.05
times: Array(Int64,(300,)) [181825,182299,  …  331774,776574] # every sample is stored in the Trial
gctimes: Array(Int64,(300,)) [0,0,  …  0,0,424460]
memory: Int64 20960
allocs: Int64 83
```

As you can see from the above, a couple of different timing estimates are pretty-printed with the `Trial`. You can calculate these estimates yourself using the `minimum`, `median`, `mean`, and `maximum` functions:

```julia
julia> minimum(t)
BenchmarkTools.TrialEstimate:
  time:             181.82 μs
  gctime:           0.0 ns (0.0%)
  memory:           20.47 kb
  allocs:           83
  time tolerance:   5.0%
  memory tolerance: 5.0%

julia> median(t)
BenchmarkTools.TrialEstimate:
  time:             187.0 μs
  gctime:           0.0 ns (0.0%)
  memory:           20.47 kb
  allocs:           83
  time tolerance:   5.0%
  memory tolerance: 5.0%

julia> mean(t)
BenchmarkTools.TrialEstimate:
  time:             203.16 μs
  gctime:           1.41 μs (0.7%)
  memory:           20.47 kb
  allocs:           83
  time tolerance:   5.0%
  memory tolerance: 5.0%

julia> maximum(t)
BenchmarkTools.TrialEstimate:
  time:             776.57 μs
  gctime:           424.46 μs (54.66%)
  memory:           20.47 kb
  allocs:           83
  time tolerance:   5.0%
  memory tolerance: 5.0%
```

### Which estimator should I use?

We've found that, for most benchmarks that we've tested, the time distribution is almost always right-skewed. This phenomena can be justified by considering that the machine noise affecting the benchmarking process is, in some sense, inherently positive. In other words, there aren't really sources of noise that would regularly cause your machine to execute a series of instructions *faster* than the theoretical "ideal" time prescribed by your hardware. Following this characterization of benchmark noise, we can describe the behavior of our estimators:

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
  time:             180.61 μs
  gctime:           0.0 ns (0.0%)
  memory:           20.47 kb
  allocs:           83
  time tolerance:   5.0%
  memory tolerance: 5.0%

julia> m2 = median(run(b))
BenchmarkTools.TrialEstimate:
  time:             180.38 μs
  gctime:           0.0 ns (0.0%)
  memory:           20.47 kb
  allocs:           83
  time tolerance:   5.0%
  memory tolerance: 5.0%

julia> ratio(m1, m2)
  BenchmarkTools.TrialRatio:
    time:             1.0012751106712903
    gctime:           1.0
    memory:           1.0
    allocs:           1.0
    time tolerance:   5.0%
    memory tolerance: 5.0%
```

Use the `judge` function to decide if one estimate represents a regression versus another estimate:

```julia
julia> m1 = median(@benchmark eig(rand(10, 10)))
BenchmarkTools.TrialEstimate:
  time:             182.28 μs
  gctime:           0.0 ns (0.0%)
  memory:           20.27 kb
  allocs:           81
  time tolerance:   5.0%
  memory tolerance: 5.0%

julia> m2 = median(@benchmark eig(rand(10, 10)))
BenchmarkTools.TrialEstimate:
  time:             182.36 μs
  gctime:           0.0 ns (0.0%)
  memory:           20.67 kb
  allocs:           85
  time tolerance:   5.0%
  memory tolerance: 5.0%

# percent change falls within noise tolerance for all fields
julia> judge(m1, m2)
BenchmarkTools.TrialJudgement:
  time:   -0.04% => invariant (5.0% tolerance)
  memory: -1.97% => invariant (5.0% tolerance)

# change our noise tolerances
julia> judge(m1, m2; time_tolerance = 0.0001, memory_tolerance = 0.01)
BenchmarkTools.TrialJudgement:
  time:   -0.04% => improvement (0.01% tolerance)
  memory: -1.97% => improvement (1.0% tolerance)

# switch m1 & m2
julia> judge(m2, m1; memory_tolerance = 0.01)
BenchmarkTools.TrialJudgement:
  time:   +0.04% => invariant (5.0% tolerance)
  memory: +2.0% => regression (1.0% tolerance)

# you can pass in TrialRatios as well
julia> judge(ratio(m1, m2)) == judge(m1, m2)
true
```

Note that changes in GC time and allocation count aren't classified by `judge`. This is because GC time and allocation count, while sometimes useful for answering *why* a regression occurred, are not generally useful for answering *if* a regression occurred. Instead, it's usually only differences in time and memory usage that determine whether or not a code change is an improvement or a regression. For example, in the unlikely event that a code change decreased time and memory usage, but increased GC time and allocation count, most people would consider that code change to be an improvement. The opposite is also true: an increase in time and memory usage would be considered a regression no matter how much GC time or allocation count decreased.

# Using `BenchmarkGroup`s

### Defining benchmark suites

In the real world, one often deals with whole suites of benchmarks rather than just individual benchmarks. BenchmarkTools provides the `BenchmarkGroup` type for this purpose.

A `BenchmarkGroup` stores a `Dict` that maps benchmark IDs to values, as well as "tags" that describe the group. The IDs and values can be of any type, so a `BenchmarkGroup` can store benchmark definitions, benchmark results, or even other `BenchmarkGroup` instances.

Here's an example where we organize multiple benchmarks using the `BenchmarkGroup` type:

```julia
# Define a parent BenchmarkGroup to contain our suite
suite = BenchmarkGroup()

# Add some child groups to our benchmark suite. The most relevant BenchmarkGroup constructor
# for this case is BenchmarkGroup(tags::AbstractString...). These tags are useful for
# filtering benchmarks by topic, which we'll cover in a later section.
suite["utf8"] = BenchmarkGroup("string", "unicode")
suite["trigonometry"] = BenchmarkGroup("math", "triangles")

# Add some benchmarks to the "utf8" group
teststr = UTF8String(join(rand(MersenneTwister(1), 'a':'d', 10^4)))
suite["utf8"]["replace"] = @benchmarkable replace($teststr, "a", "b")
suite["utf8"]["join"] = @benchmarkable join($teststr, $teststr)

# Add some benchmarks to the "trigonometry" group
for f in (sin, cos, tan)
    for x in (0.0, pi)
        suite["trigonometry"][string(f), x] = @benchmarkable $(f)($x)
    end
end
```

Let's look at our newly defined suite in the REPL:

```julia
julia> suite
BenchmarkTools.BenchmarkGroup:
  tags: []
  "utf8" => BenchmarkGroup(["string", "unicode"])
  "trigonometry" => BenchmarkGroup(["math", "triangles"])

julia> suite["utf8"]
BenchmarkTools.BenchmarkGroup:
  tags: ["string", "unicode"]
  "join" => BenchmarkTools.Benchmark{symbol("##benchmark#7184")}(...)
  "replace" => BenchmarkTools.Benchmark{symbol("##benchmark#7165")}(...)

julia> suite["trigonometry"]
BenchmarkTools.BenchmarkGroup:
  tags: ["math", "triangles"]
  ("tan",π = 3.1415926535897...) => BenchmarkTools.Benchmark{symbol("##benchmark#7233")}(...)
  ("cos",0.0) => BenchmarkTools.Benchmark{symbol("##benchmark#7218")}(...)
  ("cos",π = 3.1415926535897...) => BenchmarkTools.Benchmark{symbol("##benchmark#7223")}(...)
  ("sin",π = 3.1415926535897...) => BenchmarkTools.Benchmark{symbol("##benchmark#7209")}(...)
  ("sin",0.0) => BenchmarkTools.Benchmark{symbol("##benchmark#7201")}(...)
  ("tan",0.0) => BenchmarkTools.Benchmark{symbol("##benchmark#7228")}(...)
```

Now, we have a benchmark suite that can be tuned, run, and analyzed in aggregate!

### Tuning and running a `BenchmarkGroup`

Similarly to individual benchmarks, you can `tune!` and `run` whole `BenchmarkGroup` instances (following from the previous section):

```julia
julia> tune!(suite);

# run with a time limit of ~1 second per benchmark
julia> results = run(suite, verbose = true, seconds = 1)
(1/2) benchmarking "utf8"...
  (1/2) benchmarking "join"...
  done (took 1.15406904 seconds)
  (2/2) benchmarking "replace"...
  done (took 0.47660775 seconds)
done (took 1.697970114 seconds)
(2/2) benchmarking "trigonometry"...
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
  "trigonometry" => BenchmarkGroup(["math", "triangles"])
```

### Working with `BenchmarkGroup` results

Following from the previous section:

```julia
julia> results["utf8"]
BenchmarkTools.BenchmarkGroup:
  tags: ["string", "unicode"]
  "join" => Trial(133.84 ms) # showcompact for Trial displays the minimum time estimate
  "replace" => Trial(202.3 μs)

julia> results["trigonometry"]
BenchmarkTools.BenchmarkGroup:
  tags: ["math", "triangles"]
  ("tan",π = 3.1415926535897...) => Trial(28.0 ns)
  ("cos",0.0) => Trial(6.0 ns)
  ("cos",π = 3.1415926535897...) => Trial(22.0 ns)
  ("sin",π = 3.1415926535897...) => Trial(21.0 ns)
  ("sin",0.0) => Trial(6.0 ns)
  ("tan",0.0) => Trial(6.0 ns)
```

Most of the functions on result-related types (`Trial`, `TrialEstimate`, `TrialRatio`, and `TrialJudgement`) work on `BenchmarkGroup`s as well by mapping the functions to the group's values:

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

`BenchmarkGroup` also supports a subset of Julia's `Associative` interface (e.g. `filter`, `keys`, `values`, etc.). A full list of supported functions can be found [in the reference document](reference.md).

### Filtering a `BenchmarkGroup` by tag

Sometimes, especially in large benchmark suites, you'd like to filter benchmarks by topic (e.g. string benchmarks, linear algebra benchmarks) without necessarily worrying about how the suite is actually organized. BenchmarkTools supports a tagging system for this purpose.

A `BenchmarkGroup` that contain child `BenchmarkGroups` can be filtered by the child groups' tags using the `@tagged` macro. Consider the following `BenchmarkGroup`:

```julia
julia> g
BenchmarkTools.BenchmarkGroup:
  tags: []
  "c" => BenchmarkGroup(["5", "6", "7"])
  "b" => BenchmarkGroup(["3", "4", "5"])
  "a" => BenchmarkGroup(["1", "2", "3"])

julia> g[@tagged "3"] # selects groups tagged "3"
BenchmarkTools.BenchmarkGroup:
  tags: []
  "b" => BenchmarkGroup(["3", "4", "5"])
  "a" => BenchmarkGroup(["1", "2", "3"])

julia> g[@tagged "1" || "7"] # selects groups tagged "1" or "7"
BenchmarkTools.BenchmarkGroup:
  tags: []
  "c" => BenchmarkGroup(["5", "6", "7"])
  "a" => BenchmarkGroup(["1", "2", "3"])

julia> g[@tagged "3" && "4"] # selects groups tagged "3" and "4"
  BenchmarkTools.BenchmarkGroup:
    tags: []
    "b" => BenchmarkGroup(["3", "4", "5"])

julia> g[@tagged !("4")] # selects groups without the tag "4"
BenchmarkTools.BenchmarkGroup:
  tags: []
  "c" => BenchmarkGroup(["5", "6", "7"])
  "a" => BenchmarkGroup(["1", "2", "3"])
```

As you can see, the allowable syntax for the `@tagged` predicate expressions includes `!`, `()`, `||`, `&&`, in addition to the tags themselves. The above examples only use simple expressions, but the syntax supports more complicated expressions, for example:

```julia
# select all groups tagged both "linalg" and "sparse",
# except for groups also tagged "parallel" or "simd"
mygroup[@tagged ("linalg" && "sparse") && !("parallel" || "simd")]
```

### Indexing into a `BenchmarkGroup` with another `BenchmarkGroup`

It's sometimes useful to create `BenchmarkGroup` where the keys are drawn from one `BenchmarkGroup`, but the values are drawn from another. You can accomplish this by indexing into the latter `BenchmarkGroup` with the former:

```julia
julia> showall(g) # leaf values are integers
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

julia> showall(x) # leaf values are characters
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

julia> showall(g[x]) # index into `g` with the keys of `x`
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

# Save benchmark parameters to increase consistency and decrease execution time

A common workflow used in BenchmarkTools is the following:

1. Start a Julia session
2. Execute a benchmark suite using an old version of your package
3. Save the results somehow (e.g. in a JLD file)
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
  "trigonometry" => BenchmarkGroup(["math", "triangles"])

# tune the suite to configure benchmark parameters
julia> tune!(suite);

julia> using JLD

# save the suite's parameters using JLD
julia> JLD.save("evals.jld", "suite", evals(suite));
```

Now, instead of tuning `suite` every time we load the benchmarks in a new Julia session, we can simply load the parameters in the JLD file using the `loadevals!` function:

```julia
julia> loadevals!(suite, JLD.load("evals.jld", "suite"));
```

Caching parameters in this manner leads to a far shorter turnaround time, and more importantly, much more consistent results.

# Miscellaneous tips and info

- Times reported by BenchmarkTools are limited to nanosecond resolution, though derived estimates might report fractions of nanoseconds.
- If you use `rand` or something similar to generate the values that are used in your benchmarks, you should seed the RNG (or provide a seeded RNG) so that the values are consistent between trials/samples/evaluations.
- BenchmarkTools attempts to be robust against machine noise occurring between *samples*, but BenchmarkTools can't do very much about machine noise occurring between *trials*. To cut down on the latter kind of noise, it is advised that you dedicate CPUs and memory to the benchmarking Julia process by using a shielding tool such as [cset](http://manpages.ubuntu.com/manpages/precise/man1/cset.1.html).
- On some machines, for some versions of BLAS and Julia, the number of BLAS worker threads can exceed the number of available cores. This can occasionally result in scheduling issues and inconsistent performance for BLAS-heavy benchmarks. To fix this issue, you can use `BLAS.set_num_threads(i::Int)` in the Julia REPL to ensure that the number of BLAS threads is equal to or less than the number of available cores.
