This document is an API reference for the types and functions provided by BenchmarkTools. If you're looking for more in-depth documentation, see [the BenchmarkTools manual](manual.md).

# Table of Contents

- [Types](#types)
- [Functions](#functions)
- [Macros](#macros)

# Types

##### `BenchmarkGroup(tags::Vector, data::Dict)`
##### `BenchmarkGroup(tags::Vector, args::Pairs...)`
##### `BenchmarkGroup(args::Pairs...)`

A type that stores multiple benchmarks or benchmark results in a `Dict`-like structure.

`BenchmarkGroup` supports the following methods from Julia's `Associative` interface:

```julia
Base.:(==)(a::BenchmarkGroup, b::BenchmarkGroup)
Base.copy(group::BenchmarkGroup)
Base.similar(group::BenchmarkGroup)
Base.isempty(group::BenchmarkGroup)
Base.length(group::BenchmarkGroup)
Base.getindex(group::BenchmarkGroup, k...)
Base.setindex!(group::BenchmarkGroup, v, k...)
Base.delete!(group::BenchmarkGroup, v, k...)
Base.haskey(group::BenchmarkGroup, k)
Base.keys(group::BenchmarkGroup)
Base.values(group::BenchmarkGroup)
Base.start(group::BenchmarkGroup)
Base.next(group::BenchmarkGroup, state)
Base.done(group::BenchmarkGroup, state)
Base.filter(f, group::BenchmarkGroup)
Base.filter!(f, group::BenchmarkGroup)
```

Relevant manual documentation can be found [here](manual.md#the-benchmarkgroup-type).

##### `Parameters(; kwargs...)`

Not exported. A type containing all benchmark configuration parameters. Valid  `kwargs` values can be found in the relevant manual documentation [here](manual.md#benchmark-parameters).

##### `Benchmark`

Not exported. A type representation of a defined benchmark. Stores a `Parameters` instance that can be accessed using `parameters(::Benchmark)`.

##### `Trial`

Not exported. Stores all the samples retrieved during benchmark execution, as well as the parameters used to configure the benchmarking process. Relevant manual documentation can be found [here](manual.md#trial-and-trialestimate).

##### `TrialEstimate`

Not exported. An estimate that characterizes some aspect of the sample distribution stored in a `Trial`. Relevant manual documentation can be found [here](manual.md#trial-and-trialestimate).

##### `TrialRatio`

Not exported. A representation of a ratio between two `TrialEstimate`s. Relevant manual documentation can be found [here](manual.md#trialratio-and-trialjudgement).

##### `TrialJudgement`

Not exported. A type that stores a classification of a `TrialRatio`'s time and memory values as regressions, improvements, or invariants. Relevant manual documentation can be found [here](manual.md#trialratio-and-trialjudgement).

# Functions

## Accessor Functions

##### `time(x::Union{Trial, TrialEstimate, TrialRatio, TrialJudgement, BenchmarkGroup})`

Returns the time value (in nanoseconds) associated with `x`. If `isa(x, TrialJudgement)`, the value will not be a number, but a `Symbol` (`:regression`, `:invariant`, or `:improvement`). If `isa(x, BenchmarkGroup)`, return a `BenchmarkGroup` where `time` has been applied to the values of `x`.

##### `memory(x::Union{Trial, TrialEstimate, TrialRatio, TrialJudgement, BenchmarkGroup})`

Returns the memory value (in bytes) associated with `x`. If `isa(x, TrialJudgement)`, the value will not be a number, but a `Symbol` (`:regression`, `:invariant`, or `:improvement`).  If `isa(x, BenchmarkGroup)`, return a `BenchmarkGroup` where `memory` has been applied to the values of `x`.

##### `gctime(x::Union{Trial, TrialEstimate, TrialRatio, BenchmarkGroup})`

Returns the GC time value (in nanoseconds) associated with `x`. If `isa(x, BenchmarkGroup)`, return a `BenchmarkGroup` where `gctime` has been applied to the values of `x`.

##### `allocs(x::Union{Trial, TrialEstimate, TrialRatio, BenchmarkGroup})`

Returns the number of allocations associated with `x`. If `isa(x, BenchmarkGroup)`, return a `BenchmarkGroup` where `allocs` has been applied to the values of `x`.

##### `params(x::Union{Benchmark, Trial, TrialEstimate, TrialRatio, TrialJudgement, BenchmarkGroup})`

Returns the `Parameters` instance associated with `x`. If `isa(x, BenchmarkGroup)`, return a `BenchmarkGroup` where `params` has been applied to the values of `x`.

##### `ratio(x::TrialJudgement)`

Returns the `TrialRatio` instance that underlies `x`'s classification data.

## Result Analysis Functions

##### `ratio{T}(a::T, b::T)`

When `T <: TrialEstimate`, return the `TrialRatio` of `a` versus `b`. When `T <: Real`, return the ratio between two numbers. When `T <: BenchmarkGroup`, return the `BenchmarkGroup` obtained by mapping `ratio` onto the values of group `a` and values of group `b`. Relevant manual documentation can be found [here](manual.md#trialratio-and-trialjudgement).

##### `judge(a::TrialEstimate, b::TrialEstimate; kwargs...)`,
##### `judge(r::TrialRatio; kwargs...)`
##### `judge(groups::BenchmarkGroup...; kwargs...)`

Return the `TrialJudgement` obtained by classifying the time/memory fields of the input as regressions, accounting for the `time_tolerance` and `memory_tolerance` specified by the inputs' associated `Parameters` instance (these tolerances can be overridden by passing `time_tolerance` and `memory_tolerance` as `kwargs`). If the input argument(s) is/are of type `BenchmarkGroup`, return the `BenchmarkGroup` obtained by mapping `judge` over the value(s) of the argument(s). Relevant manual documentation can be found [here](manual.md#trialratio-and-trialjudgement).

##### `minimum(x::Union{Trial, BenchmarkGroup})`

Return the sample with the smallest time value in `x` as a `TrialEstimate`. If `isa(x, BenchmarkGroup)`, return the BenchmarkGroup obtained by mapping `minimum` onto the values of `x`.

##### `median(x::Union{Trial, BenchmarkGroup})`

Return the median of `x` as a `TrialEstimate`. If `isa(x, BenchmarkGroup)`, return the BenchmarkGroup obtained by mapping `median` onto the values of `x`.

##### `mean(x::Union{Trial, BenchmarkGroup})`

Return the mean of `x` as a `TrialEstimate`. If `isa(x, BenchmarkGroup)`, return the BenchmarkGroup obtained by mapping `mean` onto the values of `x`.

##### `maximum(x::Union{Trial, BenchmarkGroup})`

Return the sample with the largest time value in `x` as a `TrialEstimate`. If `isa(x, BenchmarkGroup)`, return the BenchmarkGroup obtained by mapping `maximum` onto the values of `x`.

##### `min{T}(args::T...)`

If `T <: TrialEstimate`, return the argument with the smallest time value. If `T <: BenchmarkGroup`, return the `BenchmarkGroup` obtained by mapping `min` onto the values of the given groups.

##### `max{T}(args::T...)`

If `T <: TrialEstimate`, return the argument with the largest time value. If `T <: BenchmarkGroup`, return the `BenchmarkGroup` obtained by mapping `max` onto the values of the given groups.

##### `isregression(x::Union{TrialJudgement, BenchmarkGroup})`

If `isa(x, TrialJudgement)`, return `true` if `time(x) == :regression || memory(x) == :regression`. If `isa(x, BenchmarkGroup)`, return `true` if `isregression` returns `true` for any of the values in `x`.

##### `isimprovement(x::Union{TrialJudgement, BenchmarkGroup})`

If `isa(x, TrialJudgement)`, return `true` if `time(x) == :improvement || memory(x) == :improvement`. If `isa(x, BenchmarkGroup)`, return `true` if `isimprovement` returns `true` for any of the values in `x`.

##### `isinvariant(x::Union{TrialJudgement, BenchmarkGroup})`

If `isa(x, TrialJudgement)`, return `true` if `time(x) == :invariant && memory(x) == :invariant`. If `isa(x, BenchmarkGroup)`, return `true` if `isinvariant` returns `true` for all values in `x`.

##### `improvements(x::BenchmarkGroup)`

Only makes sense if the leaf values of `x` are of type `TrialJudgement`. Return a `BenchmarkGroup` containing only the entries that are improvements (determined via `isimprovement`).

##### `invariants(x::BenchmarkGroup)`

Only makes sense if the leaf values of `x` are of type `TrialJudgement`. Return a `BenchmarkGroup` containing only the entries that are invariants (determined via `isinvariant`).

##### `regressions(x::BenchmarkGroup)`

Only makes sense if the leaf values of `x` are of type `TrialJudgement`. Return a `BenchmarkGroup` containing only the entries that are regressions (determined via `isregression`).

##### `rmskew!(x::Trial)`, `rmskew(x::Trial)`

Return `x` (or a copy of `x`, in the non-mutating case) where samples that positively skew `x`'s time distribution have been removed. This can be useful when examining a `Trial` generated in a very noisy environment; see [here](manual.md#which-estimator-should-i-use) for a short discussion of how machine noise can affect benchmark time distribution.

##### `trim(x::Trial, percentage = 0.1)`

Return a copy of `x` with the top `percentage` samples removed. Useful for outlier trimming.

##### `filtervals!(f, g::BenchmarkGroup)`, `filtervals(f, g::BenchmarkGroup)`

Not exported. Remove `k => v` pairs in `g` for which `f(v) == false`.

##### `mapvals!(f, g::BenchmarkGroup)`, `mapvals(f, g::BenchmarkGroup)`

Not exported. Apply the function `f` to every value in `g`.

## Misc. Functions

#### `addgroup!(suite::BenchmarkGroup, id, args...)`

A convenience function for making a new child `BenchmarkGroup` in `suite`. Equivalent to:

```julia
begin
    g = BenchmarkGroup(args...)
    suite[id] = g
    return g
end
```

##### `leaves(x::BenchmarkGroup)`

Return an iterator over `x`'s leaf index/value pairs. Relevant manual documentation can be found [here](manual.md#indexing-into-a-benchmarkgroup-using-a-vector).

##### `save(filename, args...)`

Not exported. This function calls `JSON.print` with custom serialization to write benchmarking data in a custom JSON format.

##### `load(filename, args...)`

Not exported. This function calls `JSON.parse` with custom deserialization to read back benchmarking data written from `save`.

##### `loadparams!(x::Parameters, y::Parameters, fields...)`
##### `loadparams!(x::Benchmark, y::Parameters, fields...)`
##### `loadparams!(x::BenchmarkGroup, y::BenchmarkGroup, fields...)`

If no `fields` are provided, load all of `y`'s parameters into `x`. If `fields` are provided, load only the parameters that correspond to those fields (e.g. `loadparams!(x, y, :evals, :samples)` will load only `y`'s `evals` and `samples` parameters). If `x` and `y` are `BenchmarkGroup` instances, change `x`'s values' parameters to the parameters stored at matching keys in `y`. Relevant manual documentation can be found [here](manual.md#caching-parameters).

##### `run(x::Union{Benchmark, BenchmarkGroup}; verbose = false, kwargs...)`

Run the specified benchmark(s), returning a `Trial` or a `BenchmarkGroup` with `Trial`s as leaf values. Valid  `kwargs` values can be found in the relevant manual documentation [here](manual.md#benchmark-parameters).

##### `tune!(x::Union{Benchmark, BenchmarkGroup}; verbose = false, kwargs...)`

Tune the `evals` parameter (evaluations per sample) of the specified benchmark(s). Valid `kwargs` match those of `run`. Relevant manual documentation can be found [here](manual.md#defining-and-executing-benchmarks).

##### `warmup(x::Union{Benchmark, BenchmarkGroup}; verbose = true)`

Run a single evaluation of `x`. This can be useful if you think JIT overhead is being incorporated into your results (which is rarely the case, unless very few samples are taken).

# Macros

##### `@belapsed(expr, kwargs...)`

Analogous to `Base.@elapsed expr`, but uses BenchmarkTools's execution framework to run the benchmark. The returned runtime is
calculated via the minimum estimator. Valid `kwargs` are [listed here](manual.md#benchmark-parameters).

##### `@benchmarkable(expr, kwargs...)`

Define and return, but do not tune or run, a `Benchmark` that can be used to test the performance of `expr`. Relevant manual documentation can be found [here](manual.md#benchmarking-basics) (for valid `kwargs` values, see [here](manual.md#benchmark-parameters) specifically). If used in local scope, all external local variables must be interpolated.

##### `@benchmark(expr, kwargs...)`

Define, tune, and run the `Benchmark` generated from `expr`. Relevant manual documentation can be found [here](manual.md#benchmarking-basics) (for valid `kwargs` values, see [here](manual.md#benchmark-parameters) specifically). If used in local scope, all external local variables must be interpolated.

##### `@btime(expr, kwargs...)`

Analogous to `Base.@time expr`, but uses BenchmarkTools's execution framework to run the benchmark. The printed runtime is calculated via the minimum estimator. Valid `kwargs` are [listed here](manual.md#benchmark-parameters).

##### `@tagged(expr)`

Construct a tag predicate from `expr` than can be used to index into a `BenchmarkGroup`. Relevant manual documentation can be found  [here](manual.md#indexing-into-a-benchmarkgroup-using-tagged).
