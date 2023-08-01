# BenchmarkTools.jl

<picture>
<source media="(prefers-color-scheme: dark)" srcset="docs/src/assets/logo-dark.svg" width="100" height="100" align="right">
<img alt="BenchmarkTools logo" src="docs/src/assets/logo.svg" width="100" height="100" align="right">
</picture>

[![][docs-stable-img]][docs-stable-url]
[![][docs-dev-img]][docs-dev-url]
[![Build Status](https://github.com/JuliaCI/BenchmarkTools.jl/workflows/CI/badge.svg)](https://github.com/JuliaCI/BenchmarkTools.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Code Coverage](https://codecov.io/gh/JuliaCI/BenchmarkTools.jl/branch/master/graph/badge.svg?label=codecov&token=ccN7NZpkBx)](https://codecov.io/gh/JuliaCI/BenchmarkTools.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

BenchmarkTools makes **performance tracking of Julia code easy** by supplying a framework for **writing and running groups of benchmarks** as well as **comparing benchmark results**.

This package is used to write and run the benchmarks found in [BaseBenchmarks.jl](https://github.com/JuliaCI/BaseBenchmarks.jl).

The CI infrastructure for automated performance testing of the Julia language is not in this package, but can be found in [Nanosoldier.jl](https://github.com/JuliaCI/Nanosoldier.jl).

## Installation

<p>
BenchmarkTools is a &nbsp;
    <a href="https://julialang.org">
        <img src="https://raw.githubusercontent.com/JuliaLang/julia-logo-graphics/master/images/julia.ico" width="16em">
        Julia Language
    </a>
    &nbsp; package. To install BenchmarkTools,
    please <a href="https://docs.julialang.org/en/v1/manual/getting-started/">open
    Julia's interactive session (known as REPL)</a> and press <kbd>]</kbd> key in the REPL to use the package mode, then type the following command
</p>

```julia
pkg> add BenchmarkTools
```

## Documentation

If you're just getting started, check out the [manual](https://juliaci.github.io/BenchmarkTools.jl/dev/manual/) for a thorough explanation of BenchmarkTools.

If you want to explore the BenchmarkTools API, see the [reference document](https://juliaci.github.io/BenchmarkTools.jl/dev/reference/).

If you want a short example of a toy benchmark suite, see the sample file in this repo ([benchmark/benchmarks.jl](benchmark/benchmarks.jl)).

If you want an extensive example of a benchmark suite being used in the real world, you can look at the source code of [BaseBenchmarks.jl](https://github.com/JuliaCI/BaseBenchmarks.jl/tree/nanosoldier).

If you're benchmarking on Linux, I wrote up a series of [tips and tricks](https://juliaci.github.io/BenchmarkTools.jl/dev/linuxtips/) to help eliminate noise during performance tests.

## Quick Start

The primary macro provided by BenchmarkTools is `@benchmark`:

```julia
julia> using BenchmarkTools

# The `setup` expression is run once per sample, and is not included in the
# timing results. Note that each sample can require multiple evaluations
# benchmark kernel evaluations. See the BenchmarkTools manual for details.
julia> @benchmark sort(data) setup=(data=rand(10))
BenchmarkTools.Trial: 10000 samples with 972 evaluations.
 Range (min … max):  69.399 ns …  1.066 μs  ┊ GC (min … max): 0.00% … 0.00%
 Time  (median):     83.850 ns              ┊ GC (median):    0.00%
 Time  (mean ± σ):   89.471 ns ± 53.666 ns  ┊ GC (mean ± σ):  3.25% ± 5.16%

          ▁▄▇█▇▆▃▁                                                 
  ▂▁▁▂▂▃▄▆████████▆▅▄▃▃▃▃▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂
  69.4 ns           Histogram: frequency by time             145 ns (top 1%)

 Memory estimate: 160 bytes, allocs estimate: 1.
```

For quick sanity checks, one can use the [`@btime` macro](https://juliaci.github.io/BenchmarkTools.jl/stable/manual/#Benchmarking-basics), which is a convenience wrapper around `@benchmark` whose output is analogous to Julia's built-in [`@time` macro](https://docs.julialang.org/en/v1/base/base/#Base.@time):

```julia
# The `seconds` expression helps set a rough time budget, see Manual for more explanation
julia> @btime sin(x) setup=(x=rand()) seconds=3
  4.361 ns (0 allocations: 0 bytes)
0.49587200950472454
```

If the expression you want to benchmark depends on external variables, you should use [`$` to "interpolate"](https://juliaci.github.io/BenchmarkTools.jl/stable/manual/#Interpolating-values-into-benchmark-expressions) them into the benchmark expression to
[avoid the problems of benchmarking with globals](https://docs.julialang.org/en/v1/manual/performance-tips/#Avoid-global-variables).
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

Sometimes, interpolating variables into very simple expressions can give the compiler more information than you intended, causing it to "cheat" the benchmark by hoisting the calculation out of the benchmark code
```julia
julia> a = 1; b = 2
2

julia> @btime $a + $b
  0.024 ns (0 allocations: 0 bytes)
3
```
As a rule of thumb, if a benchmark reports that it took less than a nanosecond to perform, this hoisting probably occurred. You can avoid this by referencing and dereferencing the interpolated variables 
```julia
julia> @btime $(Ref(a))[] + $(Ref(b))[]
  1.277 ns (0 allocations: 0 bytes)
3
```

As described in the [manual](https://juliaci.github.io/BenchmarkTools.jl/dev/manual/), the BenchmarkTools package supports many other features, both for additional output and for more fine-grained control over the benchmarking process.

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

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://JuliaCI.github.io/BenchmarkTools.jl/dev/
[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://JuliaCI.github.io/BenchmarkTools.jl/stable
