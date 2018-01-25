# This file is a part of BenchmarkTools.jl. License is MIT

module Timers
import Compat

###
# For each supported operating system, we define a struct:
# struct Measurement end
# -(a::Measurement, b::Measurement) -> MeasurmentDelta
#
# struct MeasurmentDelta end
# isless
# time
# cpuratio
###

const ACCURATE_CPUTIME = Compat.Sys.iswindows() ? haskey(ENV, "BT_FORCE_CPUTIME") : true

"""
    realtime()

Monotonic runtime counter

Returns time in ns as Float64.
"""
function realtime end

"""
    cputime()

Process specific CPU time clock.

Returns time in ns as Float64.
"""
function cputime end

function _applever()
    return VersionNumber(readchomp(`sw_vers -productVersion`))
end

if Compat.Sys.isapple() && _applever() < v"10.12.0"
    include("darwin.jl")
elseif Compat.Sys.isunix()
    include("unix.jl")
elseif Compat.Sys.iswindows()
    include("windows.jl")
else
    error("$(Sys.KERNEL) is not supported please file an issue")
end

Base.isless(a::MeasurementDelta, b::MeasurementDelta) = isless(time(a), time(b))
Base.:(-)(t1::Measurement, t0::Measurement) = MeasurementDelta(t1, t0)
time(a::MeasurementDelta) = a.realtime
cpuratio(a::MeasurementDelta) = a.cpuratio

end # module 