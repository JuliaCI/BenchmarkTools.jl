# This file is a part of BenchmarkTools.jl. License is MIT

module Timers
import Compat

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
end # module 