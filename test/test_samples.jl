module TestSamples

using FGenerators
using FLoops
using SplittablesBase
using SplittablesTesting
using Test
using Transducers: Map

@fgenerator noone() = nothing
@fgenerator oneone() = @yield 1
@fgenerator function onetwothree()
    @yield 1
    @yield 2
    @yield 3
end

@fgenerator function organpipe(n::Integer)
    i = 0
    while i != n
        i += 1
        @yield i
    end
    while true
        i -= 1
        i == 0 && return
        @yield i
    end
end

struct OrganPipe <: Foldable
    n::Int
end

@fgenerator(foldable::OrganPipe) do
    n = foldable.n
    @yieldfrom 1:n
    @yieldfrom n-1:-1:1
end

function SplittablesBase.halve(foldable::OrganPipe)
    n = foldable.n
    return (1:n, n-1:-1:1)
end

Base.length(foldable::OrganPipe) = 2 * foldable.n - 1

@fgenerator function flatten2(a, b)
    @yieldfrom a
    @yieldfrom b
end

struct Count <: Foldable
    start::Int
    stop::Int
end

Base.length(itr::Count) = max(0, itr.stop - itr.start + 1)
Base.eltype(::Type{<:Count}) = Int

@fgenerator(itr::Count) do
    i = itr.start
    i > itr.stop && return
    while true
        @yield i
        i == itr.stop && break
        i += 1
    end
end

repeat3 = @fgenerator function (x)
    @yield x
    @yield x
    @yield x
end

repeat3_arrow = @fgenerator x -> begin
    @yield x
    @yield x
    @yield x
end

repeat3_arrow2 = @fgenerator (x,) -> begin
    @yield x
    @yield x
    @yield x
end

@fgenerator function ffilter(f, xs)
    @floop for x in xs
        if f(x)
            @yield x
        end
    end
end

asval(x::Val) = x
asval(x) = Val(x)
const FlagType = Union{Val{true},Val{false},Bool}

@fgenerator function linesin(str::AbstractString; keep::FlagType = Val(false))
    keep = asval(keep)
    start = firstindex(str)
    for (i, c) in pairs(str)
        if c == '\n'
            if keep === Val(true)
                @yield SubString(str, start, i)
            else
                @yield SubString(str, start, prevind(str, i))
            end
            start = nextind(str, i)
        end
    end
    if start <= ncodeunits(str)
        @yield SubString(str, start)
    end
end

raw_testdata = raw"""
noone() == []
oneone() == [1]
onetwothree() == [1, 2, 3]
organpipe(2) == [1, 2, 1]
organpipe(3) == [1, 2, 3, 2, 1]
OrganPipe(2) == [1, 2, 1]
OrganPipe(3) == [1, 2, 3, 2, 1]
flatten2((1, 2), (3,)) == [1, 2, 3]
Count(0, 2) == [0, 1, 2]
Count(0, -1) == Int[]
repeat3(:a) == [:a, :a, :a]
repeat3_arrow(:a) == [:a, :a, :a]
repeat3_arrow2(:a) == [:a, :a, :a]
ffilter(isodd, noone()) == []
ffilter(isodd, oneone()) == [1]
ffilter(isodd, onetwothree()) == [1, 3]
ffilter(isodd, 1:5) == [1, 3, 5]
ffilter(isodd, organpipe(3)) == [1, 3, 1]
linesin("a\nbb\nccc") == ["a", "bb", "ccc"]
linesin("a\nbb\nccc"; keep=true) == ["a\n", "bb\n", "ccc"]
linesin("a\nbb\nccc\n") == ["a", "bb", "ccc"]
linesin("a\nbb\nccc\n"; keep=true) == ["a\n", "bb\n", "ccc\n"]
"""

args_and_kwargs(args...; kwargs...) = args, (; kwargs...)

# An array of `(label, (f, args, kwargs, comparison, desired))`
testdata = map(split(raw_testdata, "\n", keepempty = false)) do x
    comp_ex = Meta.parse(x)
    @assert comp_ex.head == :call
    @assert length(comp_ex.args) == 3
    comparison, ex, desired = comp_ex.args
    f = ex.args[1]
    ex.args[1] = args_and_kwargs

    label = strip(x[1:prevind(x, first(findlast(String(comparison), x)))])
    Meta.parse(label)  # validation

    @eval ($label, ($(Symbol(f)), $ex..., $comparison, $desired))
end

@testset "$label" for (label, (f, args, kwargs, comparison, desired)) in testdata
    ==′ = comparison
    @test collect(f(args...; kwargs...)) ==′ desired
    @test collect(Map(identity), f(args...; kwargs...)) ==′ desired
end

@testset "inference" begin
    @test @inferred(sum(ffilter(isodd, onetwothree()))) == 4
    @test @inferred(sum(ffilter(isodd, organpipe(3)))) == 5
    @test @inferred(sum(ffilter(isodd, OrganPipe(3)))) == 5
end

SplittablesTesting.test_ordered(Any[OrganPipe(n) for n in 1:10])

end  # module
