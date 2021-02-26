module SerializationTests

using BenchmarkTools
using Test

eq(x::T, y::T) where {T<:Union{values(BenchmarkTools.SUPPORTED_TYPES)...}} =
    all(i->eq(getfield(x, i), getfield(y, i)), 1:fieldcount(T))
eq(x::T, y::T) where {T} = isapprox(x, y)

function withtempdir(f::Function)
    d = mktempdir()
    try
        cd(f, d)
    finally
        rm(d, force=true, recursive=true)
    end
    nothing
end

@testset "Successful (de)serialization" begin
    b = @benchmarkable sin(1)
    tune!(b)
    bb = run(b)

    withtempdir() do
        tmp = joinpath(pwd(), "tmp.json")

        BenchmarkTools.save(tmp, b.params, bb)
        @test isfile(tmp)

        results = BenchmarkTools.load(tmp)
        @test results isa Vector{Any}
        @test length(results) == 2
        @test eq(results[1], b.params)
        @test eq(results[2], bb)
    end

    # Nested BenchmarkGroups
    withtempdir() do
        tmp = joinpath(pwd(), "tmp.json")

        g = BenchmarkGroup()
        g["a"] = BenchmarkGroup()
        g["b"] = BenchmarkGroup()
        g["c"] = BenchmarkGroup()
        BenchmarkTools.save(tmp, g)

        results = BenchmarkTools.load(tmp)[1]
        @test results isa BenchmarkGroup
        @test all(v->v isa BenchmarkGroup, values(results.data))
    end
end

@testset "Deprecated behaviors" begin
    b = @benchmarkable sin(1)
    tune!(b)
    bb = run(b)

    @test_throws ArgumentError BenchmarkTools.save("x.jld", b.params)
    @test_throws ArgumentError BenchmarkTools.save("x.txt", b.params)
    @test_throws ArgumentError BenchmarkTools.save("x.json")
    @test_throws ArgumentError BenchmarkTools.save("x.json", 1)

    withtempdir() do
        tmp = joinpath(pwd(), "tmp.json")
        @test_logs (:warn, r"Naming variables") BenchmarkTools.save(tmp, "b", b.params)
        @test isfile(tmp)
        results = BenchmarkTools.load(tmp)
        @test length(results) == 1
        @test eq(results[1], b.params)
    end

    @test_throws ArgumentError BenchmarkTools.load("x.jld")
    @test_throws ArgumentError BenchmarkTools.load("x.txt")
    @test_throws ArgumentError BenchmarkTools.load("x.json", "b")
end

@testset "Error checking" begin
    withtempdir() do
        tmp = joinpath(pwd(), "tmp.json")
        open(tmp, "w") do f
            print(f, """
            {"never":1,"gonna":[{"give":3,"you":4,"up":5}]}
            """)
        end
        try
            BenchmarkTools.load(tmp)
            error("madness")
        catch err
            # This function thows a bunch of errors, so test for this specifically
            @test occursin("Unexpected JSON format", err.msg)
        end
    end

    @test_throws ArgumentError BenchmarkTools.recover([1])
end

end # module
