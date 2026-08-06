using Aqua
using BenchmarkTools
using Test

print("Testing code quality...")
took_seconds = @elapsed begin
    if isdefined(Test, :detect_closure_boxes)
        @test isempty(Test.detect_closure_boxes(BenchmarkTools))
    end
    Aqua.test_all(BenchmarkTools)
end
println("done (took ", took_seconds, " seconds)")

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
