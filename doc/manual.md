This document provides in-depth on the design and use of BenchmarkTools. If you're looking for a quick reference, try reading [this](reference.md) instead.

# Table of Contents

Bold links indicate sections that should be read carefully in order to avoid common benchmarking pitfalls.

- [Introduction](#introduction)
- [Benchmarking basics](#defining-and-executing-benchmarks)
    * [Defining and executing benchmarks](#defining-and-executing-benchmarks)
    * [Tunable benchmark parameters](#tunable-benchmark-parameters)
    * **[Interpolating values into benchmark expressions](#interpolating-values-into-benchmark-expressions)**
- [Handling benchmark results](#handling-benchmark-results)
    * [`Trial` and `TrialEstimate`](#trial-and-trialestimate)
    * **[Which estimator should I use?](#which-estimator-should-i-use)**
    * [`TrialRatio` and `TrialJudgement`](#trialratio-and-trialjudgement)
- [Using `BenchmarkGroup`s](#using-benchmarkgroups)
    * [Defining benchmark suites](#defining-benchmark-suites)
    * [Tuning and running a `BenchmarkGroup`](#tuning-and-running-a-benchmarkgroup)
    * [Working with `BenchmarkGroup` results](#working-with-benchmarkgroup-results)
    * [Filtering a `BenchmarkGroup` by tag](#filtering-a-benchmarkgroup-by-tag)
- **[Increase consistency and decrease execution time by caching benchmark parameters](#increase-consistency-and-decrease-execution-time-by-caching-benchmark-parameters)**
- [Miscellaneous tips and info](#miscellaneous-tips-and-info)

# Introduction

BenchmarkTools was created to facilitate the following tasks:

1. Organize collections of benchmarks into manageable benchmark suites
2. Tune benchmark configuration parameters for accuracy and consistency across trials
3. Execute trials to gather data that characterizes benchmark performance
4. Analyze and compare results to determine whether a code change caused regressions or improvements

Before we get too far, let's define some of the terminology used in this document:

- "evaluation": a single execution of a benchmark expression.
- "sample": a single time/memory measurement obtained by running multiple evaluations.
- "trial": an experiment in which multiple samples are gathered (or the result of such an experiment).

The reasoning behind our definition of "sample" may not be obvious to all readers. If the time to execute a benchmark is smaller than the resolution of your timing method, than a single evaluation of the benchmark will generally not produce a valid sample. In that case, one must "approximate" a valid sample by evaluating the benchmark multiple times, and dividing the total time by the number of evaluations performed. For example, if a sample takes 1 second for 1 million evaluations, the approximate time value for that sample is 1 microsecond per evaluation. It's not obvious what the right number of evaluations per sample should be for any given benchmark, so BenchmarkTools provides a mechanism (the `tune!` method) to automatically figure it out for you.

# Benchmarking basics

### Defining and executing benchmarks

To quickly benchmark a Julia expression, use `@benchmark`:

```julia
julia> @benchmark sin(1)
BenchmarkTools.Trial:
  samples:         300
  evals/sample:    76924
  noise tolerance: 5.0%
  memory:          0.0 bytes
  allocs:          0
  minimum time:    13.0 ns (0.0% GC)
  median time:     13.0 ns (0.0% GC)
  mean time:       13.0 ns (0.0% GC)
  maximum time:    14.0 ns (0.0% GC)
```

The `@benchmark` macro is essentially shorthand for defining a benchmark, auto-tuning the benchmark's configuration parameters, and running the benchmark. These three steps can be done explicitly using `@benchmarkable`, `tune!` and `run`:

```julia
julia> b = @benchmarkable sin(1) # define the benchmark with default parameters
BenchmarkTools.Benchmark{symbol("##benchmark#7341")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))

julia> tune!(b) # find the right evals/sample for this benchmark
BenchmarkTools.Benchmark{symbol("##benchmark#7341")}(BenchmarkTools.Parameters(5.0,300,76924,true,false,0.05))

julia> run(b)
BenchmarkTools.Trial:
  samples:         300
  evals/sample:    76924
  noise tolerance: 5.0%
  memory:          0.0 bytes
  allocs:          0
  minimum time:    13.0 ns (0.0% GC)
  median time:     13.0 ns (0.0% GC)
  mean time:       13.0 ns (0.0% GC)
  maximum time:    14.0 ns (0.0% GC)
```

### Tunable benchmark parameters

You can pass the following keyword arguments to `@benchmark`, `@benchmarkable`, and `run` to configure the execution process:

- `samples`: The number of samples to take. Execution will end if this many samples have been collected. Defaults to `300`.
- `seconds`: The number of seconds budgeted for the benchmarking process. The trial will terminate if this time is exceeded (regardless of `samples`), but at least one sample will always be taken. In practice, actual runtime can overshoot the budget by the duration of a sample. Defaults to `5.0`.
- `evals`: The number of evaluations per sample. For best results, this should be kept consistent between trials. A good guess for this value can be automatically set on a benchmark via `tune!`, but using `tune!` can be less consistent than setting `evals` manually. Defaults to `1`.
- `gctrial`: If `true`, run `gc()` before executing this benchmark's trial. Defaults to `true`.
- `gcsample`: If `true`, run `gc()` before each sample. Defaults to `false`.
- `tolerance`: The noise tolerance of the benchmark, as a percentage. Some BenchmarkTools functions automatically propagate/use this tolerance in their calculations (e.g. regression detection). Defaults to `0.05` (5%).

For example:

```julia
b = @benchmarkable sin(1) seconds=1 tolerance=0.01
run(b) # equivalent to run(b, seconds = 1, tolerance = 0.01)
```

### Interpolating values into benchmark expressions

You can interpolate values into `@benchmark` and `@benchmarkable` expressions:

```julia
# rand(1000) is executed for each evaluation
julia> @benchmark sum(rand(1000))
BenchmarkTools.Trial:
  samples:         300
  evals/sample:    575
  noise tolerance: 5.0%
  memory:          7.92 kb
  allocs:          3
  minimum time:    1.9 μs (0.0% GC)
  median time:     2.73 μs (0.0% GC)
  mean time:       3.61 μs (29.72% GC)
  maximum time:    8.77 μs (66.07% GC)

# rand(1000) is evaluated at definition time, and the resulting
# value is interpolated into the benchmark expression
julia> @benchmark sum($(rand(1000)))
BenchmarkTools.Trial:
  samples:         300
  evals/sample:    5209
  noise tolerance: 5.0%
  memory:          0.0 bytes
  allocs:          0
  minimum time:    192.0 ns (0.0% GC)
  median time:     192.0 ns (0.0% GC)
  mean time:       192.84 ns (0.0% GC)
  maximum time:    196.0 ns (0.0% GC)
```

A good rule of thumb is that **external variables should be explicitly interpolated into the benchmark expression**:

```julia
julia> A = rand(1000);

# A is a global variable in the benchmarking context
julia> @benchmark [i*i for i in A]
BenchmarkTools.Trial:
  samples:         300
  evals/sample:    2
  noise tolerance: 5.0%
  memory:          241.62 kb
  allocs:          9960
  minimum time:    887.97 μs (0.0% GC)
  median time:     894.81 μs (0.0% GC)
  mean time:       930.63 μs (3.47% GC)
  maximum time:    2.61 ms (64.13% GC)

# A is a constant value in the benchmarking context
julia> @benchmark [i*i for i in $A]
BenchmarkTools.Trial:
  samples:         300
  evals/sample:    807
  noise tolerance: 5.0%
  memory:          7.89 kb
  allocs:          1
  minimum time:    1.23 μs (0.0% GC)
  median time:     2.04 μs (0.0% GC)
  mean time:       2.92 μs (35.49% GC)
  maximum time:    5.9 μs (67.99% GC)
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

# Handling benchmark results

BenchmarkTools provides four types related to benchmark results:

- `Trial`: stores all samples collected during a benchmark trial, as well as the trial's parameters
- `TrialEstimate`: a single estimate used to summarize a `Trial`
- `TrialRatio`: a comparison between two `TrialEstimate`
- `TrialJudgement`: a classification of the fields of a `TrialRatio` as `invariant`, `regression`, or `improvement`

This section provides a limited number of examples demonstrating these types. For a thorough list of supported functionality, see [the reference document](reference.md#handling-results).

### `Trial` and `TrialEstimate`

Running a benchmark produces an instance of the `Trial` type:

```julia
julia> t = @benchmark eig(rand(10, 10))
BenchmarkTools.Trial:
  samples:         300
  evals/sample:    6
  noise tolerance: 5.0%
  memory:          20.47 kb
  allocs:          83
  minimum time:    181.82 μs (0.0% GC)
  median time:     187.0 μs (0.0% GC)
  mean time:       203.16 μs (0.7% GC)
  maximum time:    776.57 μs (54.66% GC)

julia> dump(t) # here's what's actually stored in a Trial
BenchmarkTools.Trial
params: BenchmarkTools.Parameters # Trials store the parameters of their parent process
  seconds: Float64 5.0
  samples: Int64 300
  evals: Int64 6
  gctrial: Bool true
  gcsample: Bool false
  tolerance: Float64 0.05
times: Array(Int64,(300,)) [181825,182299,  …  331774,776574] # every sample is stored in the Trial
gctimes: Array(Int64,(300,)) [0,0,  …  0,0,424460]
memory: Int64 20960
allocs: Int64 83
```

As you can see from the above, a couple of different timing estimates are pretty-printed with the `Trial`. You can calculate these estimates yourself using the `minimum`, `median`, `mean`, and `maximum` functions:

```julia
julia> minimum(t)
BenchmarkTools.TrialEstimate:
  time:    181.82 μs
  gctime:  0.0 ns (0.0%)
  memory:  20.47 kb
  allocs:  83
  noise tolerance: 5.0%

julia> median(t)
BenchmarkTools.TrialEstimate:
  time:    187.0 μs
  gctime:  0.0 ns (0.0%)
  memory:  20.47 kb
  allocs:  83
  noise tolerance: 5.0%

julia> mean(t)
BenchmarkTools.TrialEstimate:
  time:    203.16 μs
  gctime:  1.41 μs (0.7%)
  memory:  20.47 kb
  allocs:  83
  noise tolerance: 5.0%

julia> maximum(t)
BenchmarkTools.TrialEstimate:
  time:    776.57 μs
  gctime:  424.46 μs (54.66%)
  memory:  20.47 kb
  allocs:  83
  noise tolerance: 5.0%
```

### Which estimator should I use?

We've found that, for most benchmarks that we've tested, the time distribution is almost always right-skewed. This phenomena can be justified by considering that the machine noise affecting the benchmarking process is, in some sense, inherently positive. In other words, there aren't really sources of noise that would regularly cause your machine to execute a series of instructions *faster* than the theoretical "ideal" time prescribed by your hardware. Following this characterization of benchmark noise, we can describe the behavior of our estimators:

- The minimum is a robust estimator for the location parameter of the time distribution, and should generally not be considered an outlier
- The median, as a robust measure of central tendency, should be relatively unaffected by outliers
- The mean, as a non-robust measure of central tendency, will usually be skewed positively by outliers
- The maximum should be considered a noise-driven outlier, and can change drastically between benchmark trials.

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
  time:    180.61 μs
  gctime:  0.0 ns (0.0%)
  memory:  20.47 kb
  allocs:  83
  noise tolerance: 5.0%

julia> m2 = median(run(b))
BenchmarkTools.TrialEstimate:
  time:    180.38 μs
  gctime:  0.0 ns (0.0%)
  memory:  20.47 kb
  allocs:  83
  noise tolerance: 5.0%

julia> ratio(m1, m2)
  BenchmarkTools.TrialRatio:
    time:   1.0012751106712903
    gctime: 1.0
    memory: 1.0
    allocs:  1.0
    noise tolerance: 5.0%
```

Use the `judge` function to decide if one estimate represents a regression versus another estimate:

```julia
julia> m1 = median(@benchmark eig(rand(10, 10)))
BenchmarkTools.TrialEstimate:
  time:    182.28 μs
  gctime:  0.0 ns (0.0%)
  memory:  20.27 kb
  allocs:  81
  noise tolerance: 5.0%

julia> m2 = median(@benchmark eig(rand(10, 10)))
BenchmarkTools.TrialEstimate:
  time:    182.36 μs
  gctime:  0.0 ns (0.0%)
  memory:  20.67 kb
  allocs:  85
  noise tolerance: 5.0%

# percent change falls within noise tolerance for all fields
julia> judge(m1, m2)
BenchmarkTools.TrialJudgement:
  time:   -0.04% => invariant
  gctime: +0.0% => N/A
  memory: -1.97% => invariant
  allocs: -4.71% => invariant
  noise tolerance: 5.0%

# use 0.01 for noise tolerance
julia> judge(m1, m2, 0.01)
BenchmarkTools.TrialJudgement:
  time:   -0.04% => invariant
  gctime: +0.0% => N/A
  memory: -1.97% => improvement
  allocs: -4.71% => improvement
  noise tolerance: 1.0%

# switch m1 & m2
julia> judge(m2, m1, 0.01)
BenchmarkTools.TrialJudgement:
  time:   +0.04% => invariant
  gctime: +0.0% => N/A
  memory: +2.0% => regression
  allocs: +4.94% => regression
  noise tolerance: 1.0%

# you can pass in TrialRatios as well
julia> judge(ratio(m1, m2), 0.01) == judge(m1, m2, 0.01)
true
```

Note that GC isn't considered when determining regression status.

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
  "join" => BenchmarkTools.Benchmark{symbol("##benchmark#7184")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))
  "replace" => BenchmarkTools.Benchmark{symbol("##benchmark#7165")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))

julia> suite["trigonometry"]
BenchmarkTools.BenchmarkGroup:
  tags: ["math", "triangles"]
  ("tan",π = 3.1415926535897...) => BenchmarkTools.Benchmark{symbol("##benchmark#7233")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))
  ("cos",0.0) => BenchmarkTools.Benchmark{symbol("##benchmark#7218")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))
  ("cos",π = 3.1415926535897...) => BenchmarkTools.Benchmark{symbol("##benchmark#7223")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))
  ("sin",π = 3.1415926535897...) => BenchmarkTools.Benchmark{symbol("##benchmark#7209")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))
  ("sin",0.0) => BenchmarkTools.Benchmark{symbol("##benchmark#7201")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))
  ("tan",0.0) => BenchmarkTools.Benchmark{symbol("##benchmark#7228")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))
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

julia> judge(m1, m2, 0.001) # use 0.1 % tolerance
BenchmarkTools.BenchmarkGroup:
  tags: ["string", "unicode"]
  "join" => TrialJudgement(-0.76% => improvement)
  "replace" => TrialJudgement(+0.37% => regression)
```

`BenchmarkGroup` also supports a subset of Julia's `Associative` interface (e.g. `filter`, `keys`, `values`, etc.). A full list of supported functions can be found [in the reference document](reference.md#BenchmarkGroup).

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

# Increase consistency and decrease execution time by caching benchmark parameters

# Miscellaneous tips and info

- seed random values
- Actual time samples are limited to nanosecond resolution, though estimates might report fractions of nanoseconds
- Mention how this package can't solve low-frequency noise (sources of noise that change between trials rather than between samples), but you can configure your machine to help with this.
- Use cset
- BLAS.set_num_threads
