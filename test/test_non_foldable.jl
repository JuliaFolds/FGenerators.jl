module TestNonFoldable

using FGenerators
using FLoops
using Test

struct OrganPipe  # not inheriting `Foldable`
    n::Int
end

@fgenerator(foldable::OrganPipe) do
    n = foldable.n
    @yieldfrom 1:n
    @yieldfrom n-1:-1:1
end

@testset "n=$n" for (n, desired) in [
    (2, [1, 2, 1]),
    (3, [1, 2, 3, 2, 1]),
    (4, [1:4; 3:-1:1]),
    (5, [1:5; 4:-1:1]),
]
    actual = []
    @floop for x in OrganPipe(n)
        push!(actual, x)
    end
    @test actual == desired
end

end  # module
