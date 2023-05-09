# BenchmarkTools

BenchmarkTools makes **performance tracking of Julia code easy** by supplying a framework for **writing and running groups of benchmarks** as well as **comparing benchmark results**.

This package is used to write and run the benchmarks found in [BaseBenchmarks.jl](https://github.com/JuliaCI/BaseBenchmarks.jl).

The CI infrastructure for automated performance testing of the Julia language is not in this package, but can be found in [Nanosoldier.jl](https://github.com/JuliaCI/Nanosoldier.jl).

## Quick Start

The primary macro provided by BenchmarkTools is `@benchmark`:

```julia
julia> using BenchmarkTools

# The `setup` expression is run once per sample, and is not included in the
# timing results. Note that each sample can require multiple evaluations
# benchmark kernel evaluations. See the BenchmarkTools manual for details.
julia> @benchmark sort(data) setup=(data=rand(10))
BenchmarkTools.Trial:
 10000 samples with 968 evaulations took a median time of 90.902 ns (0.00% GC)
 Time  (mean ± σ):   94.936 ns ±  47.797 ns  (GC: 2.78% ±  5.03%)
 Range (min … max):  77.655 ns … 954.823 ns  (GC: 0.00% … 87.94%)

          ▁▃▅▆▇█▇▆▅▂▁                                          
  ▂▂▃▃▄▅▆▇███████████▇▆▄▄▃▃▂▂▂▂▂▂▂▂▂▂▂▁▂▁▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂
  77.7 ns         Histogram: frequency by time           137 ns

 Memory estimate: 160 bytes, allocs estimate: 1.
```

For quick sanity checks, one can use the [`@btime` macro](https://juliaci.github.io/BenchmarkTools.jl/stable/manual/#Benchmarking-basics), which is a convenience wrapper around `@benchmark` whose output is analogous to Julia's built-in [`@time` macro](https://docs.julialang.org/en/v1/base/base/#Base.@time):

```julia
julia> @btime sin(x) setup=(x=rand())
  4.361 ns (0 allocations: 0 bytes)
0.49587200950472454
```

If you're interested in profiling a fast-running command, you can use `@bprofile sin(x) setup=(x=rand())` and then your favorite
tools for displaying the results (`Profile.print` or a graphical viewer).

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

As described in the [Manual](https://juliaci.github.io/BenchmarkTools.jl/stable/reference/), the BenchmarkTools package supports many other features, both for additional output and for more fine-grained control over the benchmarking process.
