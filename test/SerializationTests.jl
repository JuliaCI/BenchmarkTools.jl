module SerializationTests

using BenchmarkTools
using Test

function eq(x::T, y::T) where {T<:Union{values(BenchmarkTools.SUPPORTED_TYPES)...}}
    return all(i -> eq(getfield(x, i), getfield(y, i)), 1:fieldcount(T))
end
eq(x::Vector{Float64}, y::Vector{Float64}) = all(eq.(x, y))
eq(x::T, y::T) where {T} = (x === y) || isapprox(x, y)

function withtempdir(f::Function)
    d = mktempdir()
    try
        cd(f, d)
    finally
        rm(d; force=true, recursive=true)
    end
    return nothing
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
        @test all(v -> v isa BenchmarkGroup, values(results.data))
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
            print(
                f,
                """
       {"never":1,"gonna":[{"give":3,"you":4,"up":5}]}
       """,
            )
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

@testset "Backwards Comppatibility with evals_set" begin
    json_string = "[{\"Julia\":\"1.11.0-DEV.1116\",\"BenchmarkTools\":\"1.4.0\"},[[\"Parameters\",{\"gctrial\":true,\"time_tolerance\":0.05,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5.0,\"overhead\":0.0,\"memory_tolerance\":0.01}]]]"
    json_io = IOBuffer(json_string)

    @test BenchmarkTools.load(json_io) == [
        BenchmarkTools.Parameters(
            5.0, 10000, 1, false, 0.0, true, false, 0.05, 0.05, 0.05, 0.01
        ),
    ]

    json_string = "[{\"Julia\":\"1.11.0-DEV.1116\",\"BenchmarkTools\":\"1.4.0\"},[[\"Parameters\",{\"gctrial\":true,\"time_tolerance\":0.05,\"evals_set\":true,\"samples\":10000,\"evals\":1,\"gcsample\":false,\"seconds\":5.0,\"overhead\":0.0,\"memory_tolerance\":0.01}]]]"
    json_io = IOBuffer(json_string)

    @test BenchmarkTools.load(json_io) == [
        BenchmarkTools.Parameters(
            5.0, 10000, 1, true, 0.0, true, false, 0.05, 0.05, 0.05, 0.01
        ),
    ]
end

@testset "Inf in Parameters struct" begin
    params = BenchmarkTools.Parameters(
        Inf, 10000, 1, false, Inf, true, false, Inf, Inf, Inf, Inf
    )

    io = IOBuffer()
    BenchmarkTools.save(io, params)
    json_string = String(take!(io))
    json_io = IOBuffer(json_string)

    @test BenchmarkTools.load(json_io) == [params]
end

@testset "NaN in Trial" begin
    trial1 = BenchmarkTools.Trial(
        BenchmarkTools.Parameters(), [0.49, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], 2, 1
    )
    trial2 = BenchmarkTools.Trial(
        BenchmarkTools.Parameters(), [0.49, 0.0], [NaN, NaN], [NaN, NaN], [0.0, 0.0], 2, 1
    )

    io = IOBuffer()
    BenchmarkTools.save(io, trial1, trial2)
    json_string = String(take!(io))
    json_io = IOBuffer(json_string)

    @test BenchmarkTools.load(json_io) == [trial1, trial2]
end

@testset "NaN in TrialEstimate" begin
    trial_estimate1 = BenchmarkTools.TrialEstimate(
        BenchmarkTools.Parameters(), 0.49, 0, 0, 0.0, 2, 1
    )
    trial_estimate2 = BenchmarkTools.TrialEstimate(
        BenchmarkTools.Parameters(), 0.49, NaN, NaN, 0.0, 2, 1
    )

    io = IOBuffer()
    BenchmarkTools.save(io, trial_estimate1, trial_estimate2)
    json_string = String(take!(io))
    json_io = IOBuffer(json_string)

    @test BenchmarkTools.load(json_io) == [trial_estimate1, trial_estimate2]
end

end # module
