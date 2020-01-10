module VectorizationBase

using LinearAlgebra

export Vec, VE, SVec,
    firstval, gep,
    extract_data,
    pick_vector_width,
    pick_vector_width_shift,
    vectorizable, stridedpointer,
    Pointer, ZeroInitializedPointer,
    load, store!, vbroadcast

const VE{T} = Core.VecElement{T}
const Vec{N,T} = NTuple{N,VE{T}}

abstract type AbstractStructVec{N,T} end
struct SVec{N,T} <: AbstractStructVec{N,T}
    data::Vec{N,T}
    # SVec{N,T}(v) where {N,T} = new(v)
end
# SVec{N,T}(x) where {N,T} = SVec(ntuple(i -> VE(T(x)), Val(N)))
# @inline function SVec{N,T}(x::Number) where {N,T}
    # SVec(ntuple(i -> VE(T(x)), Val(N)))
# end
# @inline function SVec{N,T}(x::Vararg{<:Number,N}) where {N,T}
    # SVec(ntuple(i -> VE(T(x[i])), Val(N)))
# end
# @inline function SVec(v::Vec{N,T}) where {N,T}
    # SVec{N,T}(v)
# end
@generated function vbroadcast(::Type{Vec{W,T}}, s::T) where {W, T <: Union{Ptr,Integer,Float16,Float32,Float64}}
    typ = llvmtype(T)
    vtyp = vtyp1 = "<$W x $typ>"
    instrs = String[]
    push!(instrs, "%ie = insertelement $vtyp undef, $typ %0, i32 0")
    push!(instrs, "%v = shufflevector $vtyp %ie, $vtyp undef, <$W x i32> zeroinitializer")
    push!(instrs, "ret $vtyp %v")
    quote
        $(Expr(:meta,:inline))
        Base.llvmcall( $(join(instrs,"\n")), Vec{$W,$T}, Tuple{$T}, s )
    end
end
@inline vbroadcast(::Val{W}, s::T) where {W,T} = SVec(vbroadcast(Vec{W,T}, s))
@inline vbroadcast(::Val{W}, ptr::Ptr{T}) where {W,T} = SVec(vbroadcast(Vec{W,T}, VectorizationBase.load(ptr)))
@inline vbroadcast(::Type{Vec{W,T1}}, s::T2) where {W,T1,T2} = vbroadcast(Vec{W,T1}, convert(T1,s))
@inline vbroadcast(::Type{Vec{W,T}}, ptr::Ptr{T}) where {W,T} = vbroadcast(Vec{W,T}, VectorizationBase.load(ptr))
@inline vbroadcast(::Type{Vec{W,T}}, ptr::Ptr) where {W,T} = vbroadcast(Vec{W,T}, Base.unsafe_convert(Ptr{T},ptr))
@inline vbroadcast(::Type{SVec{W,T}}, s) where {W,T} = SVec(vbroadcast(Vec{W,T}, s))
@inline vbroadcast(::Type{Vec{W,T}}, v::Vec{W,T}) where {W,T} = v
@inline vbroadcast(::Type{SVec{W,T}}, v::SVec{W,T}) where {W,T} = v
@inline vbroadcast(::Type{SVec{W,T}}, v::Vec{W,T}) where {W,T} = SVec(v)

@inline vone(::Type{Vec{N,T}}) where {N,T} = vbroadcast(Vec{W,T}, one(T))
@inline vzero(::Type{Vec{N,T}}) where {N,T} = vbroadcast(Vec{W,T}, zero(T))
@inline vone(::Type{SVec{N,T}}) where {N,T} = SVec(vbroadcast(Vec{W,T}, one(T)))
@inline vzero(::Type{SVec{N,T}}) where {N,T} = SVec(vbroadcast(Vec{W,T}, zero(T)))
@inline vone(::Type{T}) where {T} = one(T)
@inline vzero(::Type{T}) where {T} = zero(T)
@inline VectorizationBase.SVec{W,T}(s::T) where {W,T} = SVec(vbroadcast(Vec{W,T}, s))
@inline VectorizationBase.SVec{W,T}(s::Number) where {W,T} = SVec(vbroadcast(Vec{W,T}, convert(T, s)))


@inline SVec(v::SVec) = v
@inline Base.length(::AbstractStructVec{N}) where N = N
@inline Base.size(::AbstractStructVec{N}) where N = (N,)
@inline Base.eltype(::AbstractStructVec{N,T}) where {N,T} = T
@inline Base.conj(v::AbstractStructVec) = v # so that things like dot products work.
@inline Base.adjoint(v::AbstractStructVec) = v # so that things like dot products work.
@inline Base.transpose(v::AbstractStructVec) = v # so that things like dot products work.
@inline Base.getindex(v::SVec, i::Integer) = v.data[i].value

# @inline function SVec{N,T}(v::SVec{N,T2}) where {N,T,T2}
    # @inbounds SVec(ntuple(n -> Core.VecElement{T}(T(v[n])), Val(N)))
# end

@inline Base.one(::Type{<:AbstractStructVec{W,T}}) where {W,T} = SVec(vbroadcast(Vec{W,T}, one(T)))
@inline Base.one(::AbstractStructVec{W,T}) where {W,T} = SVec(vbroadcast(Vec{W,T}, one(T)))
@inline Base.zero(::Type{<:AbstractStructVec{W,T}}) where {W,T} = SVec(vbroadcast(Vec{W,T}, zero(T)))
@inline Base.zero(::AbstractStructVec{W,T}) where {W,T} = SVec(vbroadcast(Vec{W,T}, zero(T)))



const AbstractSIMDVector{N,T} = Union{Vec{N,T},AbstractStructVec{N,T}}

@inline extract_data(v) = v
@inline extract_data(v::SVec) = v.data

@inline firstval(x::Vec) = first(x).value
@inline firstval(x::SVec) = first(extract_data(x)).value
@inline firstval(x) = first(x)

function Base.show(io::IO, v::SVec{W,T}) where {W,T}
    print(io, "SVec{$W,$T}<")
    for w ∈ 1:W
        print(io, v[w])
        w < W && print(io, ", ")
    end
    print(">")
end

include("vectorizable.jl")
include("cpu_info.jl")
include("vector_width.jl")
include("number_vectors.jl")
include("masks.jl")
include("alignment.jl")
include("precompile.jl")
_precompile_()

end # module
