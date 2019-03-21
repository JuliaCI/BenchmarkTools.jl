# BenchmarkTools.jl

[![Build Status](https://travis-ci.org/JuliaCI/BenchmarkTools.jl.svg?branch=master)](https://travis-ci.org/JuliaCI/BenchmarkTools.jl)
[![Coverage Status](https://coveralls.io/repos/github/JuliaCI/BenchmarkTools.jl/badge.svg?branch=master)](https://coveralls.io/github/JuliaCI/BenchmarkTools.jl?branch=master)

BenchmarkTools makes **performance tracking of Julia code easy** by supplying a framework for **writing and running groups of benchmarks** as well as **comparing benchmark results**.

This package is used to write and run the benchmarks found in [BaseBenchmarks.jl](https://github.com/JuliaCI/BaseBenchmarks.jl).

The CI infrastructure for automated performance testing of the Julia language is not in this package, but can be found in [Nanosoldier.jl](https://github.com/JuliaCI/Nanosoldier.jl).

## Installation

To install BenchmarkTools, you can run the following:

```julia
Pkg.add("BenchmarkTools")
```

## Documentation

If you're just getting started, check out the [manual](doc/manual.md) for a thorough explanation of BenchmarkTools.

If you want to explore the BenchmarkTools API, see the [reference document](doc/reference.md).

If you want a short example of a toy benchmark suite, see the sample file in this repo ([benchmark/benchmarks.jl](benchmark/benchmarks.jl)).

If you want an extensive example of a benchmark suite being used in the real world, you can look at the source code of [BaseBenchmarks.jl](https://github.com/JuliaCI/BaseBenchmarks.jl/tree/nanosoldier).

If you're benchmarking on Linux, I wrote up a series of [tips and tricks](https://github.com/JuliaCI/BenchmarkTools.jl/blob/master/doc/linuxtips.md) to help eliminate noise during performance tests.

## Quick Start

The primary macro provided by BenchmarkTools is `@benchmark`:

```julia
julia> using BenchmarkTools

# The `setup` expression is run once per sample, and is not included in the
# timing results. Note that each sample can require multiple evaluations
# benchmark kernel evaluations. See the BenchmarkTools manual for details.
julia> @benchmark sin(x) setup=(x=rand())
BenchmarkTools.Trial:
  memory estimate:  0 bytes
  allocs estimate:  0
  --------------
  minimum time:     4.248 ns (0.00% GC)
  median time:      4.631 ns (0.00% GC)
  mean time:        5.502 ns (0.00% GC)
  maximum time:     60.995 ns (0.00% GC)
  --------------
  samples:          10000
  evals/sample:     1000
```

For quick sanity checks, one can use the [`@btime` macro](https://github.com/JuliaCI/BenchmarkTools.jl/blob/master/doc/manual.md#benchmarking-basics), which is a convenience wrapper around `@benchmark` whose output is analogous to Julia's built-in [`@time` macro](https://docs.julialang.org/en/stable/stdlib/base/#Base.@time):

```julia
julia> @btime sin(x) setup=(x=rand())
  4.361 ns (0 allocations: 0 bytes)
0.49587200950472454
```

If the expression you want to benchmark depends on external variables, you should use [`$` to "interpolate"](https://github.com/JuliaCI/BenchmarkTools.jl/blob/master/doc/manual.md#interpolating-values-into-benchmark-expressions) them into the benchmark expression to
[avoid the problems of benchmarking with globals](https://docs.julialang.org/en/latest/manual/performance-tips/#Avoid-global-variables-1).
Essentially, any interpolated variable `$x` or expression `$(...)` is "pre-computed" before benchmarking begins:

```julia
julia> A = rand(3,3);

julia> @btime inv($A);            # we interpolate the global variable A with $A
  1.191 μs (10 allocations: 2.31 KiB)

julia> @btime inv($(rand(3,3)));  # interpolation: the rand(3,3) call occurs before benchmarking
  1.192 μs (10 allocations: 2.31 KiB)

julia> @btime inv(rand(3,3));     # the rand(3,3) call is included in the benchmark time
  1.295 μs (11 allocations: 2.47 KiB)
```

As described the [manual](doc/manual.md), the BenchmarkTools package supports many other features, both for additional output and for more fine-grained control over the benchmarking process.

## Why does this package exist?

Our story begins with two packages, "Benchmarks" and "BenchmarkTrackers". The Benchmarks package implemented an execution strategy for collecting and summarizing individual benchmark results, while BenchmarkTrackers implemented a framework for organizing, running, and determining regressions of groups of benchmarks. Under the hood, BenchmarkTrackers relied on Benchmarks for actual benchmark execution.

For a while, the Benchmarks + BenchmarkTrackers system was used for automated performance testing of Julia's Base library. It soon became apparent that the system suffered from a variety of issues:

1. Individual sample noise could significantly change the execution strategy used to collect further samples.
2. The estimates used to characterize benchmark results and to detect regressions were statistically vulnerable to noise (i.e. not robust).
3. Different benchmarks have different noise tolerances, but there was no way to tune this parameter on a per-benchmark basis.
4. Running benchmarks took a long time - an order of magnitude longer than theoretically necessary for many functions.
5. Using the system in the REPL (for example, to reproduce regressions locally) was often cumbersome.

The BenchmarkTools package is a response to these issues, designed by examining user reports and the benchmark data generated by the old system. BenchmarkTools offers the following solutions to the corresponding issues above:

1. Benchmark execution parameters are configured separately from the execution of the benchmark itself. This means that subsequent experiments are performed more consistently, avoiding branching "substrategies" based on small numbers of samples.
2. A variety of simple estimators are supported, and the user can pick which one to use for regression detection.
3. Noise tolerance has been made a per-benchmark configuration parameter.
4. Benchmark configuration parameters can be easily cached and reloaded, significantly reducing benchmark execution time.
5. The API is simpler, more transparent, and overall easier to use.

## Acknowledgements

This package was authored primarily by Jarrett Revels (@jrevels). Additionally, I'd like to thank the following people:

- John Myles White, for authoring the original Benchmarks package, which greatly inspired BenchmarkTools
- Andreas Noack, for statistics help and investigating weird benchmark time distributions
- Oscar Blumberg, for discussions on noise robustness
- Jiahao Chen, for discussions on error analysis
