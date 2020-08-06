module TestSyntax

using FGenerators
using Test

macro expansion_error(ex)
    quote
        err = try
            $Base.@eval $__module__ $ex
            nothing
        catch _err
            _err
        end
        $Test.@test err !== nothing
        err
    end
end

msgof(err) = sprint(showerror, err)

@testset begin
    err = @expansion_error @fgenerator(notype) do
    end
    @test occursin("requires `generator::GeneratorType`", msgof(err))

    err = @expansion_error @fgenerator(x::T) do arg
    end
    @test occursin("cannot be used with arguments after `do`", msgof(err))

    err = @expansion_error @fgenerator(function (; a); end, x::T)
    @test occursin("Got a function with keyword argument(s)", msgof(err))

    err = @expansion_error @fgenerator function ()
        @yield 1 2 3
    end
    @test occursin("`@yield` requires exactly one argument.", msgof(err))
end

end  # module
