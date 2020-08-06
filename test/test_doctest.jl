module TestDoctest

import FGenerators
using Documenter: doctest
using Test

@testset "doctest" begin
    doctest(FGenerators; manual = false)
end

end  # module
