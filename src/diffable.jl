struct BenchmarkDiff{id}
    a::BenchmarkTools.Benchmark
    b::BenchmarkTools.Benchmark
    params::BenchmarkTools.Parameters
end

import Base: -
# eval_module, out_vars, setup_vars, core, setup, teardown, params
function -(a::BenchmarkTools.Benchmark, b::BenchmarkTools.Benchmark)
    id = Expr(:quote, gensym("benchmark"))
    #corefunc = gensym("core")
    #samplefunc = gensym("sample")
    #type_vars = [gensym() for i in 1:length(setup_vars)]
    #signature = Expr(:call, corefunc, setup_vars...)
    #signature_def = Expr(:where, Expr(:call, corefunc,
    #                              [Expr(:(::), setup_var, type_var) for (setup_var, type_var) in zip(setup_vars, type_vars)]...)
    #                , type_vars...)
    #if length(out_vars) == 0
    #    invocation = signature
    #    core_body = core
    #elseif length(out_vars) == 1
    #    returns = :(return $(out_vars[1]))
    #    invocation = :($(out_vars[1]) = $(signature))
    #    core_body = :($(core); $(returns))
    #else
    #    returns = :(return $(Expr(:tuple, out_vars...)))
    #    invocation = :($(Expr(:tuple, out_vars...)) = $(signature))
    #    core_body = :($(core); $(returns))
    #end
    return eval(quote
        #@noinline $(signature_def) = begin $(core_body) end
        function $BenchmarkTools.sample(b::$BenchmarkDiff{$(id)},
                                        p::$BenchmarkTools.Parameters = b.params)
            a__time, a__gctime, a__memory, a__allocs, a__return_val = $BenchmarkTools.sample(b.a, p)
            b__time, b__gctime, b__memory, b__allocs, b__return_val = $BenchmarkTools.sample(b.b, p)
            return (a__time   - b__time,
                    a__gctime - b__gctime,
                    a__memory - b__memory,
                    a__allocs - b__allocs,
                    (a__return_val,b__return_val),)
        end
        function $BenchmarkTools._run(b::$BenchmarkDiff{$(id)},
                                      p::$BenchmarkTools.Parameters;
                                      verbose = false, pad = "", kwargs...)
            a_trial, a_return_val = $BenchmarkTools._run(b.a, p)
            b_trial, b_return_val = $BenchmarkTools._run(b.b, p)
            trial = BenchmarkTools.Trial(p, a_trial.times   .- b_trial.times,
                                            a_trial.gctimes .- b_trial.gctimes,
                                            a_trial.memory   - b_trial.memory,
                                            a_trial.allocs  .- b_trial.allocs,)
            return (trial,
                    (a_return_val,b_return_val),)
        end
        $BenchmarkDiff{$(id)}($a, $b, $(b.params))
    end)
end

function BenchmarkTools.tune!(b::BenchmarkDiff, p::BenchmarkTools.Parameters = b.params;
               verbose::Bool = false, pad = "", kwargs...)
    tune!(b.a, p)
    tune!(b.b, p)
    return b
end

BenchmarkTools.run(b::BenchmarkDiff, p::BenchmarkTools.Parameters = b.params; kwargs...) = BenchmarkTools.run_result(b, p; kwargs...)[1]
BenchmarkTools.run_result(b::BenchmarkDiff, p::BenchmarkTools.Parameters = b.params; kwargs...) = Base.invokelatest(BenchmarkTools._run, b, p; kwargs...)


function BenchmarkTools.loadparams!(b::BenchmarkDiff, params::BenchmarkTools.Parameters, fields...)
    loadparams!(b.a, params, fields...)
    loadparams!(b.b, params, fields...)
    loadparams!(b, params)
    return b
end
