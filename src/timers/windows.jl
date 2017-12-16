##
# This file is a part of BenchmarkTools.jl. License is MIT
#
# Based upon https://github.com/google/benchmark, which is licensed under Apache v2:
# https://github.com/google/benchmark/blob/master/LICENSE
#
# In compliance with the Apache v2 license, here are the original copyright notices:
# Copyright 2015 Google Inc. All rights reserved.
##

"""
    FileTime

See https://msdn.microsoft.com/en-us/library/windows/desktop/ms724284(v=vs.85).aspx
"""
struct FileTime
    dwLowDateTime::UInt32
    dwHighDateTime::UInt32
end

const HANDLE = Ptr{Void}

@inline function maketime(kernel_time::FileTime, user_time::FileTime)
    kernel = (kernel_time.dwHighDateTime % UInt64) << 32 | kernel_time.dwLowDateTime
    user   = (  user_time.dwHighDateTime % UInt64) << 32 |   user_time.dwLowDateTime
    (kernel + user) * 1e2
end

@inline function realtime()
    return Float64(Base.time_ns())
end

@inline function cputime()
    proc = ccall(:GetCurrentProcess, HANDLE, ())
    creation_time = Ref{FileTime}()
    exit_time = Ref{FileTime}()
    kernel_time = Ref{FileTime}()
    user_time = Ref{FileTime}()

    ccall(:GetProcessTimes, Cint, (HANDLE, Ref{FileTime}, Ref{FileTime}, Ref{FileTime}, Ref{FileTime}),
                                proc, creation_time, exit_time, kernel_time, user_time)
    return maketime(kernel_time[], user_time[])
end
