module BenchFilter

using BenchmarkTools
using FGenerators
using Transducers

# some arbitrary predicate function that filters things out roughly half the time
@inline predicate(i, j, k) = xor(xor(i, j), k) < 7

@fgenerator function fgen(n)
    for i in 1:n, j in i:n, k in 1:n
        if predicate(i, j, k)
            @yield (i, j, k)
        end
    end
end

base(n) = ((i, j, k) for i in 1:n for j in i:n for k in 1:n if predicate(i, j, k))

const SUITE = BenchmarkGroup()

let s1 = SUITE[:reducer=>:collect] = BenchmarkGroup()
    s2 = s1[:impl=>:base] = BenchmarkGroup()
    s2[:src=>:base] = @benchmarkable(collect(base(10)))
    s2[:src=>:fgen] = @benchmarkable(collect(fgen(10)))

    s2 = s1[:impl=>:xf] = BenchmarkGroup()
    s2[:src=>:base] = @benchmarkable(collect(Map(identity), base(10)))
    s2[:src=>:fgen] = @benchmarkable(collect(Map(identity), fgen(10)))
end

let s1 = SUITE[:reducer=>:sum] = BenchmarkGroup()
    s2 = s1[:impl=>:base] = BenchmarkGroup()
    s2[:src=>:base] = @benchmarkable(sum(Base.splat(*), base(10)))
    # s2[:src=>:fgen] = @benchmarkable(sum(Base.splat(*), fgen(10)))

    s2 = s1[:impl=>:xf] = BenchmarkGroup()
    s2[:src=>:base] = @benchmarkable(foldl(+, MapSplat(*), base(10)))
    s2[:src=>:fgen] = @benchmarkable(foldl(+, MapSplat(*), fgen(10)))

    s2 = s1[:impl=>:xf_init] = BenchmarkGroup()
    s2[:src=>:base] = @benchmarkable(foldl(+, MapSplat(*), base(10); init = 0))
    s2[:src=>:fgen] = @benchmarkable(foldl(+, MapSplat(*), fgen(10); init = 0))
end

end  # module
BenchFilter.SUITE
