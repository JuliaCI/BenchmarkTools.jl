##
# This file is a part of BenchmarkTools.jl. License is MIT
#
# Based upon https://github.com/google/benchmark, which is licensed under Apache v2:
# https://github.com/google/benchmark/blob/master/LICENSE
#
# In compliance with the Apache v2 license, here are the original copyright notices:
# Copyright 2015 Google Inc. All rights reserved.
##

const RUSAGE_SELF = Cint(0)
const RUSAGE_CHILDREN = Cint(-1)

struct TimeVal
    tv_sec::Clong
    tv_usec::Clong
end

struct RUsage
    ru_utime::TimeVal
    ru_stime::TimeVal
    ru_maxrss::Clong
    ru_ixrss::Clong
    ru_idrss::Clong
    ru_isrss::Clong
    ru_minflt::Clong
    ru_majflt::Clong
    ru_nswap::Clong
    ru_inblock::Clong
    ru_outblock::Clong
    ru_msgsnd::Clong
    ru_msgrcv::Clong
    ru_nsignals::Clong
    ru_nvcsw::Clong
    ru_nivcsw::Clong
end

@inline function maketime(utime::TimeVal, stime::TimeVal)
    user   = utime.tv_sec * 1e9 + utime.tv_usec *1e3
    kernel = stime.tv_sec * 1e9 + stime.tv_usec *1e3
    return user+kernel
end

@inline function realtime()
    Float64(Base.time_ns())
end

@inline function cputime()
    ru = Ref{RUsage}()
    ccall(:getRUsage, Cint, (Cint, Ref{RUsage}), RUSAGE_SELF, ru)
    return maketime(ru[].ru_utime, ru[].ru_stime)
end

struct Measurement
    realtime::UInt64
    uime::TimeVal
    stime::TimeVal
    function Measurement()
        rtime = time_ns()
        ru = Ref{RUsage}()
        ccall(:getRUsage, Cint, (Cint, Ref{RUsage}), RUSAGE_SELF, ru)
        return new(rtime, ru[].ru_utime, ru[].ru_stime)
    end
end

struct MeasurementDelta
    realtime::Float64
    cpuratio::Float64
    function MeasurementDelta(t1::Measurement, t0::Measurement)
        rt0 = Float64(t0.realtime)
        ct0 = maketime(t0.utime, t0.stime)
        rt1 = Float64(t1.realtime)
        ct1 = maketime(t1.utime, t1.stime)
        realtime = rt1 - rt0
        cputime = ct1 - ct0
        return new(realtime, cputime/realtime)
    end
end
