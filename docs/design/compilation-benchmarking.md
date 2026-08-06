# Design: Benchmarking compilation with `@benchmark`

## Motivation

Today `@benchmark foo($x)` measures steady-state runtime. Compilation of `foo`
(and its call tree) happens at most once, either in the warm-up call or in the
first sample. This means:

- Compile-time is not reported in a statistically meaningful way.
- Users wanting to characterize "time-to-first-execution" or track
  regressions in inference/codegen cost have to roll their own harness
  (typically using `@time` in a fresh process, or `SnoopCompile`).

Goal: add a first-class mode

```julia
@benchmark foo($x) compilation=true
```

that produces a `Trial` whose samples are compilation times (and optionally
inference / LLVM / allocations breakdown), with all the existing statistics
machinery (min/median/mean/std, tuning, comparison, regression detection).

## Requirements

1. **Repeatability**: each sample must actually recompile the code under
   measurement. Running the same expression twice without intervention will
   hit the cache on the second call.
2. **Scoped invalidation**: we must *only* invalidate methods reachable from
   the expression under test. Blowing away all caches (`jl_drop_all_caches`)
   would force `BenchmarkTools`, the REPL, and the test harness itself to
   recompile on every sample, making the measurement meaningless and orders
   of magnitude slower than the thing we want to measure.
3. **Low measurement overhead**: the recording/invalidation step is *not*
   part of the sample; only the recompile + run is timed.
4. **Composable with existing `Parameters`**: `samples`, `evals`,
   `seconds`, `gctrial`, etc. should continue to work. `evals` per sample
   should probably be forced to 1 (each eval would otherwise share a cache).
5. **No dependency on external packages** (SnoopCompile, Cthulhu). The core
   capability must live in `Base`/`Core` so that `BenchmarkTools` can depend
   only on the standard library.

## Proposed surface

### In `Base` (new, internal-but-public)

```julia
# Returns a collection of MethodInstance (or CodeInstance) objects that were
# actually executed while running `ex`. Equivalent in spirit to a
# `--trace-compile` trace, but captured in-process and returning live handles
# rather than strings.
methods = Base.@record_calls foo(x)

# Drops native code + inferred IR for the given MethodInstances, such that
# the next dispatch to each one will re-infer and re-codegen.
# Does NOT bump the global world age and does NOT touch any MI not in the set.
Base.invalidate_calls(methods)
```

Optionally a convenience:

```julia
Base.@with_recompilation foo(x)  # record, invalidate, return @timed result
```

### In `BenchmarkTools`

```julia
@benchmark foo($x) compilation=true
@benchmark foo($x) compilation=:full          # infer + codegen (default)
@benchmark foo($x) compilation=:codegen_only  # keep inferred IR, drop native
@benchmark foo($x) compilation=:inference_only
```

Trial samples would store (time_ns, compile_time_ns, recompile_time_ns,
inference_time_ns, gc_time_ns, bytes, allocs) — essentially the `NamedTuple`
already produced by `@timed`.

## Design options

The hard part is item 1+2: *scoped* invalidation. Four options, roughly in
increasing order of invasiveness in Base.

### Option A: Re-eval in a fresh anonymous module per sample

Sketch: wrap the expression in `@eval Module() begin ... end`. Each sample
defines a new closure in a throwaway module, which forces codegen for the
wrapper. The inner callee (`foo`) is still cached though — so this only
measures specialization of the wrapper, not of `foo` itself. Rejected as
insufficient.

### Option B: Global cache drop per sample

`Base.drop_all_caches()` already exists. Pros: trivial to implement, no new
API. Cons:

- Recompiles everything the harness touches between samples (printing,
  timing, `Statistics.quantile`, ...). Samples become dominated by
  harness recompilation, not by `foo`.
- World-age bump changes semantics of captured closures.
- Samples are not independent: the Nth sample recompiles strictly less than
  the 1st because some harness code stays hot.

Useful as a `compilation=:nuclear` debugging escape hatch, but not the
default.

### Option C: `--trace-compile` hook + per-MI invalidation (recommended)

Two new pieces of machinery:

**C.1 Recording.** Expose the existing trace-compile infrastructure as an
in-process callback rather than a text stream. The C runtime already
notifies on every `jl_generate_fptr` / inference entry (see
`jl_force_trace_compile_timing_enable` in `base/timing.jl` and the
`trace_compile` option). Add:

```c
// src/gf.c / codegen.cpp
JL_DLLEXPORT void jl_set_trace_compile_callback(
    void (*cb)(jl_method_instance_t*, int /*is_recompile*/, void*),
    void *ctx);
```

and a Julia wrapper:

```julia
# base/reflection.jl or base/compiler/...
function record_calls(f)
    seen = IdSet{Core.MethodInstance}()
    cb = mi -> push!(seen, mi)
    prev = _set_trace_compile_callback(cb)
    try
        Base.invokelatest(f)
    finally
        _set_trace_compile_callback(prev)
    end
    return seen
end

macro record_calls(ex)
    :(record_calls(() -> $(esc(ex))))
end
```

This piggybacks on infrastructure that already exists for
`--trace-compile` and `Base.@trace_compile`. No new instrumentation points
in the compiler.

**Handling already-compiled code.** A critical subtlety: by the time the
user types `@btime foo($x) compilation=true`, `foo(x)` may already be fully
compiled (from an earlier REPL call, from precompilation, or from a
pkgimage). A naive `@record_calls foo(x)` would then observe *nothing*,
because the trace-compile callback only fires on actual codegen. The
recording pass must therefore force a compile of the target expression, not
just run it. Two strategies:

1. **Record-by-invalidate-then-run (recommended).** Start with a sentinel
   MI set (e.g. the entry-point `MethodInstance` of the call `foo(x)`,
   obtainable via `Base.method_instance` / `Core.Compiler.specialize`).
   Invalidate that single MI, then run `foo(x)` under the trace-compile
   callback. Because the entry point is now uncompiled, dispatching to it
   re-enters codegen, which in turn recursively forces codegen of any of
   its callees whose native code has been dropped — and, crucially, also
   reports any callees that were *already* compiled but had to be
   re-specialized. Callees that stay cached will not appear, but that is
   the correct answer: we don't want to recompile them on every sample
   either. The captured `seen` is then the exact set we re-invalidate per
   sample.
2. **Snapshot + diff.** Snapshot all `MethodInstance`s (or just those
   reachable via `Base.specializations` from the target method) at entry,
   run `f`, diff. This works even if nothing new compiles — the "diff" is
   empty and we fall back to `{entry_point_mi}` alone. Simpler but misses
   indirect callees that were already compiled.

(1) is essentially what `SnoopCompile.@snoopi_deep` does, and it correctly
handles the already-compiled case because the forced invalidation of the
entry point guarantees at least one codegen event which then cascades.

In both strategies the first call in the benchmark sequence does *double
duty*: it populates `seen` and produces the first sample. Subsequent
samples just `invalidate_calls(seen); @timed foo(x)` in a loop.

**C.2 Invalidation.** Expose per-MI cache dropping:

```c
JL_DLLEXPORT void jl_mi_clear_native_code(jl_method_instance_t *mi);
JL_DLLEXPORT void jl_mi_clear_inferred(jl_method_instance_t *mi);
```

and

```julia
function invalidate_calls(mis; inferred::Bool=true, native::Bool=true)
    for mi in mis
        native   && ccall(:jl_mi_clear_native_code, Cvoid, (Any,), mi)
        inferred && ccall(:jl_mi_clear_inferred,    Cvoid, (Any,), mi)
    end
end
```

The implementation can lean on `invalidate_method_instance_caches` already
present in `src/gf.c`, but *without* the world-age bump that
`jl_method_table_disable` performs — we are not making a semantic change,
just dropping cached results. This is the key novelty: today's invalidation
APIs all assume the reason for invalidation is a method edit, so they bump
the world. For benchmarking we want a pure cache flush.

Concerns and how to address them:

- **`@generated` functions / cfunctions / `precompile`d code**: some MIs
  are pinned. `invalidate_calls` should silently skip what it cannot drop
  and optionally report it. BenchmarkTools would surface a warning like
  `"17/342 methods could not be invalidated and will not be re-timed"`.
- **Backedges**: dropping native code for `mi` does not need to propagate
  along backedges, because callers were compiled against `mi`'s signature
  not its native address; the dispatch will re-enter `mi` and trigger
  codegen on demand.
- **Concurrency / world age**: since we do not bump the world, other tasks
  can keep running; they will just pay codegen cost if they happen to call
  one of the invalidated MIs concurrently. BenchmarkTools already assumes
  sole ownership of the machine during a sample, so this is acceptable.
- **Inlined callees**: if `bar` was inlined into `foo`, dropping `bar`'s
  native code does nothing — the code is duplicated inside `foo`'s native
  image. Dropping `foo` handles this correctly. This matches user
  expectation: `@benchmark foo($x) compilation=true` should measure the
  cost of compiling `foo` (with its current inlining decisions), not each
  inlinee independently.

### Option D: Process-level isolation

Run each sample in a fresh `julia` subprocess with
`--compile=all --trace-compile=...`, parse timings out of stdout. This is
what benchmarking-for-TTFX tools (`PkgEval`, `SnoopCompile`'s
`@snoopi_deep` with `flamegraph`) effectively do.

Pros: perfectly isolated, no API surface in Base.
Cons:

- Sample time ≈ 1–5 s of Julia startup + sysimage load, dominating what
  we want to measure for anything small.
- Cannot interpolate live Julia values (`$x`); would need serialization.
- Poor fit for `@benchmark`'s sampling loop.

Reasonable as a future `@benchmark_compile_isolated` macro, not as the
primary mechanism.

## Recommendation

Implement **Option C** in two PRs:

1. **julia PR**: add `Base.@record_calls` / `Base.record_calls` and
   `Base.invalidate_calls` (names open for bikeshedding — `Base.Compiler`
   may be a better home). Internally reuse the trace-compile callback
   machinery and `invalidate_method_instance_caches`. Mark them as
   experimental (`Base.Experimental`) for the first release.

2. **BenchmarkTools PR**: add a `compilation::Union{Bool,Symbol}`
   parameter to `Parameters`, wire it through `Benchmark.sample`, and
   store per-sample compile/infer/codegen/gc times. `evals` is forced
   to 1 when `compilation !== false`. Add a `ratio`/`judge` path for
   comparing compile-time trials just like runtime trials.

## Open questions

1. Should `invalidate_calls` take `MethodInstance`s, `CodeInstance`s, or
   both? `CodeInstance` is finer-grained (per-world, per-signature) and is
   what the backedge graph actually uses now; `MethodInstance` is what
   `--trace-compile` surfaces today.
2. Should `@record_calls` record transitively-inlined callees, or only
   entry points the compiler was invoked on? For benchmarking we want the
   latter; for introspection users may want the former.
3. `evals > 1`: could we support it by re-invalidating between evals
   *within* a sample? That would charge invalidation cost into the sample,
   so probably no — force `evals=1`.
4. Interaction with `--pkgimages=yes`: MIs loaded from a pkgimage are
   memory-mapped read-only. `jl_mi_clear_native_code` must either copy
   them out first or simply refuse; the former is preferable so TTFX-style
   measurements work — and is required for the already-compiled case to
   be useful, since most real-world code lives in pkgimages.
5. Interaction with `Revise`: Revise relies on the current invalidation
   API bumping world age. Our new path must not be confused with a
   user-visible method edit. Keeping it as a separate C entry point (and
   not going through `jl_method_table_disable`) achieves this.
6. Entry-point resolution: to bootstrap the record pass when `foo(x)` is
   already compiled, we need to turn the surface syntax `foo($x)` into the
   `MethodInstance` that would be dispatched to. `Base.method_instance(f,
   types)` (or equivalent via `which` + `Core.Compiler.specialize`) is the
   right primitive; BenchmarkTools already has the arg tuple from its
   quote/interpolation machinery.

## Example (target UX)

```julia
julia> using BenchmarkTools

julia> f(x) = sum(abs2, x) + prod(x .+ 1)
f (generic function with 1 method)

julia> @benchmark f($(rand(100))) compilation=true
BenchmarkTools.Trial: 48 samples with 1 evaluation per sample.
 Range (min … max):  92.1 ms … 138.4 ms  ┊ GC (min … max): 0.0% … 3.1%
 Time  (median):    101.7 ms             ┊ GC (median):    0.8%
 Time  (mean ± σ):  104.3 ms ±   8.9 ms  ┊ GC (mean ± σ):  1.1% ± 1.3%
 Compile:  98.2 ms (94.1%)   Infer: 41.7 ms (40.0%)
 Recompile: 0 ns             Codegen: 56.5 ms (54.1%)
 Methods recompiled per sample: 14 (± 0)
```
