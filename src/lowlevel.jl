##########################
# Low-level benchmarking #
##########################
import Base: llvmcall

"""
    clobber()

Force the compiler to flush pending writes to global memory.
Acts as an effective read/write barrier.
"""
@inline function clobber()
    llvmcall("""
        call void asm sideeffect "", "~{memory}"()
        ret void
    """, Void, Tuple{})
end

"""
    _llvmname(type::Type)

Produce the string name of the llvm equivalent of our Julia code.
Oh my. The preferable way would be to use LLVM.jl to do this for us.
"""
function _llvmname(typ::Type)
    isboxed_ref = Ref{Bool}()
    llvmtyp = ccall(:julia_type_to_llvm, Ptr{Void},
                    (Any, Ptr{Bool}), typ, isboxed_ref)
    name = unsafe_string(
        ccall(:LLVMPrintTypeToString, Cstring, (Ptr{Void},), llvmtyp))
    return (isboxed_ref[], name)
end

"""
    escape(val)

The `escape` function can be used to prevent a value or
expression from being optimized away by the compiler. This function is
intended to add little to no overhead.
See: https://youtu.be/nXaxk27zwlk?t=2441
"""
@generated function escape(val::T) where T
    # If the value is `nothing` then a memory clobber
    # should have the same effect.
    if T == Void
        return :(clobber())
    end
    # We need to get the string representation of the LLVM type to be able to issue a
    # fake call.
    isboxed, name = _llvmname(T)
    if isboxed
        # name will be `jl_value_t*` which we can't use since string based llvmcall can't handle named structs...
        # Ideally we would issue a `bitcast jl_value_t* %0 to i8*`
        Base.warn_once("Trying to escape a boxed value. Don't know how to handle that.")
    else
        ir = """
            call void asm sideeffect "", "X,~{memory}"($name %0)
            ret void
        """
        quote
            llvmcall($ir, Void, Tuple{T}, val)
        end
    end
end

################
# Count cycles #
################

# Only implemented on x86_64 and needs cpuflags:
# rdtscp, tsc, nonstop_tsc, tsc_known_freq, constant_tsc
# See https://github.com/dterei/gotsc for a good discussion.

"""
    bench_start()

Issues the instructions `cpuid,rdtsc` to get a precise cycle counter at the beginning of a code segment.
"""
@inline function bench_start()
    llvmcall("""
        %a = call {i32, i32} asm sideeffect "CPUID\nRDTSC\nMOV %edx, \$0\nMOV %eax, \$1", "=r,=r,~{rax},~{rbx},~{rcx},~{rdx}"()
        %a.0 = extractvalue { i32, i32 } %a, 0
        %a.1 = extractvalue { i32, i32 } %a, 1
        %b0 = insertvalue [2 x i32] undef, i32 %a.0, 0
        %b  = insertvalue [2 x i32] %b0  , i32 %a.1, 1
        ret [2 x i32] %b
    """, Tuple{UInt32, UInt32}, Tuple{})
end

"""
    bench_end()

Issues the instructions `rdtscp,cpuid` to get a precise cycle counter at the end of a code segment.
"""
@inline function bench_end()
    llvmcall("""
        %a = call {i32, i32} asm sideeffect "RDTSCP\nMOV %edx, \$0\nMOV %eax, \$1\nCPUID", "=r,=r,~{rax},~{rbx},~{rcx},~{rdx}"()
        %a.0 = extractvalue { i32, i32 } %a, 0
        %a.1 = extractvalue { i32, i32 } %a, 1
        %b0 = insertvalue [2 x i32] undef, i32 %a.0, 0
        %b  = insertvalue [2 x i32] %b0  , i32 %a.1, 1
        ret [2 x i32] %b
    """, Tuple{UInt32, UInt32}, Tuple{})
end

function cyc_convert(c::Tuple{UInt32, UInt32})
    a, b = c
    ((a % UInt64) << 32) | b
end

macro elapsed_cyc(ex)
    quote
        local c0 = bench_start()
        escape($(esc(ex)))
        local c1 = bench_end()
        cyc_convert(c1)-cyc_convert(c0)
    end
end
