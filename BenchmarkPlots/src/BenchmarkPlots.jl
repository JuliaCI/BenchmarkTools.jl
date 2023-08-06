module BenchmarkPlots
using RecipesBase
using BenchmarkTools: Trial, BenchmarkGroup

@recipe function f(::Type{Trial}, t::Trial)
    seriestype --> :violin
    legend --> false
    yguide --> "t / ns"
    xticks --> false
    return t.times
end

@recipe function f(g::BenchmarkGroup, keys=keys(g))
    legend --> false
    yguide --> "t / ns"
    for k in keys
        @series begin
            label --> string(k)
            xticks --> true
            [string(k)], g[k]
        end
    end
end

end
