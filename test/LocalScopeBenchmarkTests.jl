using Test
using BenchmarkTools
using Statistics

function judge_loosely(t1, t2)
    judge(ratio(mean(t1), mean(t2)), time_tolerance=0.2)
end

global_x = 1.0

@testset "LocalScopeBenchmarks" begin
    @testset "Basic benchmarks" begin
        x = 1.0
        evals = 500
        t1 = @benchmark($sin($x), evals=500)
        t2 = @localbenchmark(sin(x), evals=500)
        j = judge_loosely(t1, t2)
        @test isinvariant(j)

        t1 = @benchmark($sin($x), evals=500)
        t2 = @localbenchmark(sin(x), evals=500)
        j = judge_loosely(t1, t2)
        @test isinvariant(j)

        f = sin
        x = 1.0
        t1 = @benchmark($f($x), evals=500)
        t2 = @localbenchmark(f(x), evals=500)
        j = judge_loosely(t1, t2)
        @test isinvariant(j)
    end

# This test fails to run if copy/pasted into the REPL due to differing LineNumbers where vars get
# pulled from.
    @testset "Generated code is identical" begin
        x = 1.0
        ex1 = Meta.@lower(@benchmark($sin($x), evals=500))
        ex2 = Meta.@lower(@localbenchmark(sin(x), evals=500))
    end

    @testset "Benchmarks with setup" begin
        @testset "Single setup" begin
            x =1.0
            t1 = @benchmark sin(x) setup=(x = 2.0)
            t2 = @localbenchmark sin(x) setup=(x = 2.0)
            j = judge_loosely(t1, t2)
            @test isinvariant(j)
        end

        @testset "Multiple setups" begin
            t1 = @benchmark atan(x, y) setup=(x = 2.0; y = 1.5)
            t2 = @localbenchmark atan(x, y) setup=(x = 2.0; y = 1.5)
            j = judge_loosely(t1, t2)
            @test isinvariant(j)
        end

        @testset "Setups override local vars" begin
            x = 1.0
            t1 = @benchmark (@assert x == 2.0) setup=(x = 2.0) evals = 500
            t2 = @localbenchmark (@assert x == 2.0) setup=(x = 2.0) evals=500
            j = judge_loosely(t1,t2)
            @test isinvariant(j)
        end

        @testset "Mixed setup and local vars" begin
            x = 1.0
            t1 = @benchmark atan($x, y) setup=(y = 2.0)
            t2 = @localbenchmark atan(x, y) setup=(y = 2.0)
            j = judge_loosely(t1, t2)
            @test isinvariant(j)
        end
        @testset "Simple generators and comprehensions" begin
            x = [i for i in 1:1000]
            t1 = @benchmark sum($x)
            t2 = @localbenchmark sum(x)
            j = judge_loosely(t1, t2)
            @test isinvariant(j)

            x = (i for i in 1:1000)
            t1 = @benchmark sum($x)
            t2 = @localbenchmark sum(x)
            j = judge_loosely(t1, t2)
            @test isinvariant(j)
        end
        @testset "Gens, comps, override local vars" begin
            x = [1.0, 1.0, 1.0]
            y = [2.0, 2.0, 2.0]
            t1 = @benchmark atan.($x, y) setup=(y = [2.0 for i in 1:3])
            t2 = @localbenchmark atan.(x, y) setup=(y = [2.0 for i in 1:3])
            j = judge_loosely(t1, t2)
            @test isinvariant(j)
        end
    end
    @testset "Additional kwargs" begin
        @testset "evals kwarg" begin
            x = 1.0
            t1 = @benchmark sin($x) evals=5
            t2 = @localbenchmark sin(x) evals=5
            j = judge_loosely(t1, t2)
            @test isinvariant(j)
        end

        @testset "evals and setup kwargs" begin
            x = 1.0
            t1 = @benchmark sin($x) setup=(x = 2.0) evals=500
            t2 = @localbenchmark sin(x) setup=(x = 2.0) evals=500
            j = judge_loosely(t1, t2)
            @test isinvariant(j)
        end
        @testset "kwargs, evals and gens and comprehension filters" begin
            f(x) = x # define some generators based on local scope
            i = π
            N = 3
            x = [1, 3]
            y = [f(i) for i = 1:N if f(i) % 2 != 0]
            t1 = @benchmark atan.($x, y) setup=(y = [$f(i) for i in 1:$N if $f(i) % 2 != 0]) evals=100
            t2 = @localbenchmark atan.(x, y) setup=(x = [1, 3]) evals=100
            j = judge_loosely(t1, t2)
            @test isinvariant(j)
        end
    end

    @testset "Test that local benchmarks are faster than globals" begin
        t1 = @benchmark sin(global_x) evals=5  # note the lack of $
        t2 = @localbenchmark sin(global_x) evals=5
        j = judge_loosely(t1, t2)
        @test isregression(j)
    end

    @testset "Other macros" begin
        x = 1.0
        t1 = @localbtime sin($x)
        t2 = @localbelapsed sin(x)
    end

    @testset "Interpolated values" begin
        t1 = @benchmark sum($(rand(1000)))
        t2 = @localbenchmark sum($(rand(1000)))
        j = judge_loosely(t1, t2)
        @test isinvariant(j)
    end
end
