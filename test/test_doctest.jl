module TestDoctest

import FGenerators
using Documenter: doctest
using Test

@testset "doctest" begin
    if lowercase(get(ENV, "JULIA_PKGEVAL", "false")) == "true"
        @info "Skipping doctests on PkgEval."
        return
    end
    doctest(FGenerators; manual = false)
end

end  # module
