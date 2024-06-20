using Aqua
using BenchmarkTools
using JuliaFormatter
using Test

print("Testing code quality...")
took_seconds = @elapsed Aqua.test_all(BenchmarkTools)
println("done (took ", took_seconds, " seconds)")

if VERSION >= v"1.6"
    print("Testing code formatting...")
    took_seconds = @elapsed @test JuliaFormatter.format(
        BenchmarkTools; verbose=false, overwrite=false
    )
    println("done (took ", took_seconds, " seconds)")
end

print("Testing Parameters...")
took_seconds = @elapsed include("ParametersTests.jl")
println("done (took ", took_seconds, " seconds)")

print("Testing Trial/TrialEstimate/TrialRatio/TrialJudgement...")
took_seconds = @elapsed include("TrialsTests.jl")
println("done (took ", took_seconds, " seconds)")

print("Testing BenchmarkGroup...")
took_seconds = @elapsed include("GroupsTests.jl")
println("done (took ", took_seconds, " seconds)")

print("Testing execution...")
took_seconds = @elapsed include("ExecutionTests.jl")
println("done (took ", took_seconds, " seconds)")

print("Testing serialization...")
took_seconds = @elapsed include("SerializationTests.jl")
println("done (took ", took_seconds, " seconds)")
