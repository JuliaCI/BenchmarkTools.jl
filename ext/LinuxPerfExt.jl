module LinuxPerfExt

import LinuxPerf: LinuxPerf, PerfBench, EventGroup, EventType
import LinuxPerf: enable!, disable!, enable_all!, disable_all!, close, read!

export LinuxPerfParameters

Base.@kwdef struct LinuxPerfParameters
    g = EventGroup([EventType(:hw, :instructions), EventType(:hw, :branches)])
    params = BenchmarkTools.Parameters()
end

function BenchmarkTools.prehook(evals, params::LinuxPerfParameters)
    state = BenchmarkTools.prehook(evals, params.params)
    bench = PerfBench(0, params.g)
    enable!(bench)
    (state, bench)
end

function BenchmarkTools.posthook((state, bench), evals, params::LinuxPerfParameters)
    disable!(bench)
    result = BenchmarkTools.posthook(state, evals, params.params)
    (N, time_enabled, time_running, insts, branches) = read!(
        bench.groups.leader_io, Vector{UInt64}(undef, 5)
    )
    if 2 * time_running <= time_enabled
        # enabled less than 50% of the time
        # (most likely due to PMU contention with other perf events)
        return (NaN, NaN)
    else
        # account for partially-active measurement
        k = time_enabled / time_running
        estimated_instructions = Float64(insts) * k
        estimated_branches = Float64(branches) * k
        return (estimated_instructions, estimated_branches)
    end
    close(bench)
    return (__sample_instructions, __sample_branches, result)
end
