module LinuxPerfExt

import BenchmarkTools: PerfInterface
import LinuxPerf: LinuxPerf, PerfBench, EventGroup, EventType
import LinuxPerf: enable!, disable!, enable_all!, disable_all!, close, read!

function interface()
    let g = try
            EventGroup([EventType(:hw, :instructions), EventType(:hw, :branches)])
        catch
            # If perf is not working on the system, the above constructor will throw an
            # ioctl or perf_event_open error (after presenting a warning to the user)
            return PerfInterface()
        end
        close(g)
        length(g.fds) != 2 && return PerfInterface()
    end

    # If we made it here, perf seems to be working on this system
    return PerfInterface(;
        setup=() ->
            let g = EventGroup([EventType(:hw, :instructions), EventType(:hw, :branches)])
                PerfBench(0, EventGroup[g])
            end,
        start=(bench) -> enable_all!(),
        stop=(bench) -> disable_all!(),
        # start=(bench) -> enable!(bench),
        # stop=(bench) -> disable!(bench),
        teardown=(bench) -> close(bench),
        read=(bench) -> let g = only(bench.groups)
            (N, time_enabled, time_running, insts, branches) = read!(
                g.leader_io, Vector{UInt64}(undef, 5)
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
        end,
    )
end

end
