module TestWith

using FGenerators
using FGenerators: @with
using Test

callonce(f) = f()

@fgenerator function generate123()
    @yield 1
    ans = @with(callonce()) do
        @yield 2
        :returning
    end
    @test ans == :returning
    @yield 3
end

@testset begin
    @test collect(generate123()) == 1:3
end

end  # module
