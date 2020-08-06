module TestSamples

using FGenerators
using Test
using Transducers: Map

@fgenerator noone() = nothing
@fgenerator oneone() = @yield 1
@fgenerator function onetwothree()
    @yield 1
    @yield 2
    @yield 3
end

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

raw_testdata = """
noone() == []
oneone() == [1]
onetwothree() == [1, 2, 3]
flatten2((1, 2), (3,)) == [1, 2, 3]
Count(0, 2) == [0, 1, 2]
Count(0, -1) == Int[]
repeat3(:a) == [:a, :a, :a]
repeat3_arrow(:a) == [:a, :a, :a]
repeat3_arrow2(:a) == [:a, :a, :a]
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

end  # module
