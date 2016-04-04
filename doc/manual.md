This document provides in-depth on the design and use of BenchmarkTools. If you're looking for a quick reference, try reading [this](reference.md) instead.

# Introduction

### Terminology

In this document, "evaluation" generally refers to a single execution of a function.

A "sample" is a single time/memory measurement obtained by running multiple evaluations. For example, a sample might have a time value of 3 seconds for 6 evaluations (i.e., 0.5 seconds per evaluation).

A "trial" refers to an experiment in which multiple samples are gathered, or refers to the result of such an experiment.

The obvious question here is: why should individual samples ever require multiple evaluations? The simple reason is that fast-running benchmarks need to be executed and measured differently than slow-running ones. Specifically, if the time to execute a benchmark is smaller than the resolution of your timing method, than a single evaluation of the benchmark will generally not produce a valid sample. Thus, BenchmarkTools provides a mechanism (the `tune!` method) to automatically figure out a reasonable number of evaluations per sample required for a given benchmark.

### The BenchmarkTools workflow

BenchmarkTools was created with the following workflow in mind:

1. Define your benchmarks
2. Tune your benchmarks' configuration parameters (e.g. how many seconds to spend benchmarking, number of samples to take, etc.)
3. Execute trials to gather data for characterizing the benchmarks' performance
4. Analyze and compare results to determine whether a code change caused regressions or improvements

The intent of BenchmarkTools is to make it easy to do these 4 things, either separately or in order.

# Defining and executing benchmarks

### `@benchmark`, `@benchmarkable`, and `run`

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

The `@benchmark` macro is essentially shorthand for defining a benchmark, tuning the benchmark's configuration parameters, and running the benchmark. These three steps can be done explicitly using `@benchmarkable`, `tune!` and `run`:

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

You can pass the following keyword arguments to `@benchmark`, `@benchmarkable`, and `run` to configure the execution process:

- `samples`: The number of samples to take. Execution will end if this many samples have been collected. Defaults to `300`.
- `seconds`: The number of seconds budgeted for the benchmarking process. The trial will terminate if this time is exceeded (regardless of `samples`), but at least one sample will always be taken. Defaults to `5.0`.
- `evals`: The number of evaluations per sample. For best results, this should be kept consistent between trials. A good guess for this value can be automatically set on a benchmark via `tune!`, but using `tune!` can be less consistent than setting `evals` manually. Defaults to `1`.
- `gctrial`: If `true`, run `gc()` before executing the trial. Defaults to `true`.
- `gcsample`: If `true`, run `gc()` before each sample. Defaults to `false`.
- `tolerance`: The noise tolerance of the benchmark, as a percentage. Defaults to `0.05` (5%).

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

A good rule of thumb is that **external variables should always be explicitly interpolated into the benchmark expression**:

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

You should generally make sure your benchmarks are [idempotent](https://en.wikipedia.org/wiki/Idempotence) so that evaluation times are not order-dependent.

# Dealing with benchmark results

### Summarizing execution results: Trials and TrialEstimates

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

julia> dump(t) # let's look at fields of t
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

We've found that, for most benchmarks that we've tested, the time distribution is almost always right-skewed. This phenomena can be justified by considering that the machine noise affecting the benchmarking process is, in some ways, inherently positive. In other words, there aren't really sources of noise that would regularly cause your machine to execute a series of instructions *faster* than the theoretical "ideal" time prescribed by your hardware. From this characterization of benchmark noise, we can characterize our estimators:

- The minimum is a robust estimator for the location parameter of the time distribution, and should generally not be considered an outlier
- The median, as a robust measure of central tendency, should be relatively unaffected by outliers
- The mean, as a non-robust measure of central tendency, will usually be skewed positively by outliers
- The maximum should be considered a noise-driven outlier, and can change drastically between benchmark trials.

### Comparing benchmark results: TrialRatios

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

### Classifying regressions/improvements: TrialJudgements

Use the `judge` function to decide if one estimate represents a regression versus another
estimate:

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

# BenchmarkGroups

### Defining and organizing benchmark suites

Normally, you need to work with whole suites of benchmarks, not just individual ones. The `BenchmarkGroup` type exists to facilitate this.

A `BenchmarkGroup` stores a `Dict` that maps benchmark IDs to values, as well as "tags" that describe the group. The IDs and values can be of any type, so a `BenchmarkGroup` can store benchmark definitions, benchmark results, or even other `BenchmarkGroup` instances.

Here's an example where we organize multiple benchmarks using the `BenchmarkGroup` type:

```julia
julia> groups = BenchmarkGroup()
BenchmarkTools.BenchmarkGroup:
  tags: []

# These tags are useful for filtering BenchmarkGroups, which we'll cover in a later section
julia> groups["eig"] = BenchmarkGroup("linalg", "factorization", "math")
BenchmarkTools.BenchmarkGroup:
  tags: ["linalg", "factorization", "math"]

julia> for i in (10, 100, 1000)
           groups["eig"][i] = @benchmarkable eig(rand($i, $i))
       end

julia> groups["eig"]
BenchmarkTools.BenchmarkGroup:
  tags: ["linalg", "factorization", "math"]
  100 => BenchmarkTools.Benchmark{symbol("##benchmark#7153")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))
  10 => BenchmarkTools.Benchmark{symbol("##benchmark#7148")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))
  1000 => BenchmarkTools.Benchmark{symbol("##benchmark#7157")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))

julia> groups["trig"] = BenchmarkGroup("math", "sin", "cos", "tan")
BenchmarkTools.BenchmarkGroup:
  tags: ["math", "sin", "cos", "tan"]

julia> for f in (sin, cos, tan)
           for x in (0.0, pi)
               groups["trig"][string(f), x] = @benchmarkable $(f)($x)
           end
       end

julia> groups["trig"]
BenchmarkTools.BenchmarkGroup:
  tags: ["math", "sin", "cos", "tan"]
  ("tan",π = 3.1415926535897...) => BenchmarkTools.Benchmark{symbol("##benchmark#7211")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))
  ("cos",0.0) => BenchmarkTools.Benchmark{symbol("##benchmark#7196")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))
  ("cos",π = 3.1415926535897...) => BenchmarkTools.Benchmark{symbol("##benchmark#7201")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))
  ("sin",π = 3.1415926535897...) => BenchmarkTools.Benchmark{symbol("##benchmark#7187")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))
  ("sin",0.0) => BenchmarkTools.Benchmark{symbol("##benchmark#7179")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))
  ("tan",0.0) => BenchmarkTools.Benchmark{symbol("##benchmark#7206")}(BenchmarkTools.Parameters(5.0,300,1,true,false,0.05))

julia> groups
BenchmarkTools.BenchmarkGroup:
  tags: []
  "eig" => BenchmarkGroup(["linalg", "factorization", "math"])
  "trig" => BenchmarkGroup(["math", "sin", "cos", "tan"])
```

Now, we have a benchmark suite that can be tuned, run, and analyzed in aggregate.

### Tuning/Running BenchmarkGroups

### Working with results stored in BenchmarkGroups

### Filtering BenchmarkGroups by tag

# Caching benchmark parameters

# Miscellaneous tips and info

- Actual time samples are limited to nanosecond resolution, though estimates might report fractions of nanoseconds
- Mention how this package can't solve low-frequency noise (sources of noise that change between trials rather than between samples), but you can configure your machine to help with this.
- Use cset
- BLAS.set_num_threads
