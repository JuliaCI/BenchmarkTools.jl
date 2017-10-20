module SerializationTests

using Compat
using Compat.Test
using BenchmarkTools

eq(x::T, y::T) where {T<:Union{BenchmarkTools.SUPPORTED_TYPES...}} =
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

        BenchmarkTools.save(tmp, b, bb)
        @test isfile(tmp)

        results = BenchmarkTools.load(tmp)
        @test results isa Vector{Any}
        @test length(results) == 2
        @test eq(results[1], b)
        @test eq(results[2], bb)
    end
end

@testset "Deprecated behaviors" begin
    b = @benchmarkable sin(1)
    tune!(b)
    bb = run(b)

    @test_throws ArgumentError BenchmarkTools.save("x.jld", b)
    @test_throws ArgumentError BenchmarkTools.save("x.txt", b)
    @test_throws ArgumentError BenchmarkTools.save("x.json")
    @test_throws ArgumentError BenchmarkTools.save("x.json", 1)

    withtempdir() do
        tmp = joinpath(pwd(), "tmp.json")
        @test_warn "Naming variables" BenchmarkTools.save(tmp, "b", b)
        @test isfile(tmp)
        results = BenchmarkTools.load(tmp)
        @test length(results) == 1
        @test eq(results[1], b)
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
            # This function thows a bunch of ArgumentErrors, so test for this specifically
            @test err isa ArgumentError
            @test contains(err.msg, "Unexpected JSON format")
        end
    end

    @test_throws ArgumentError BenchmarkTools.recover([1])
end

end # module
