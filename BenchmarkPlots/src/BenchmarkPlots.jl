module BenchmarkPlots
using RecipesBase
using BenchmarkTools: Trial, BenchmarkGroup, mean

@recipe function f(::Type{Trial}, t::Trial)
    seriestype --> :violin
    legend --> false
    yguide --> "t / ns"
    xticks --> false
    t.times
end

@recipe function f(g::BenchmarkGroup, keyset=keys(g))
    yguide --> "t / ns"
    if all(isa.(keyset, Number))
        keyvec = sort([keyset...])
        fillrange := [mean(g[key]).time for key in keyvec]
        seriestype --> :path
        fillalpha --> 0.5
        keyvec, [minimum(g[key]).time for key in keyvec]
    else
        legend --> false
        for key in keyset
            @series begin
                label --> string(key)
                xticks --> true
                [string(key)], g[key]
            end
        end
    end
end

# If a BenchmarkGroup has BenchmarkGroups for elements, ignore the xtick string given by
# parent, just run BenchmarkGroup recipe again
@recipe function f(::AbstractVector{String}, g::BenchmarkGroup)
    legend --> true
    return g
end

end
