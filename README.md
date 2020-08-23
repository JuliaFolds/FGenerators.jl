# FGenerators: `foldl` for humans™

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliafolds.github.io//FGenerators.jl/dev)
[![GitHub Actions](https://github.com/JuliaFolds//FGenerators.jl/workflows/Run%20tests/badge.svg)](https://github.com/JuliaFolds//FGenerators.jl/actions?query=workflow%3ARun+tests)

FGenerators.jl is a package for defining Transducers.jl-compatible
extended `foldl` with a simple `@yield`-based syntax.  An example for
creating an ad-hoc "generator":

```julia
julia> using FGenerators

julia> @fgenerator function generate123()
           @yield 1
           @yield 2
           @yield 3
       end;

julia> collect(generate123())
3-element Array{Int64,1}:
 1
 2
 3

julia> sum(generate123())
6

julia> @fgenerator function organpipe(n::Integer)
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
       end;

julia> collect(organpipe(3))
5-element Array{Int64,1}:
 1
 2
 3
 2
 1
```

FGenerators.jl is a spin-off of
[GeneratorsX.jl](https://github.com/JuliaFolds/GeneratorsX.jl).

Use [FLoops.jl](https://github.com/JuliaFolds/FLoops.jl) to iterate
over the items yielded from the generator:

```julia
julia> using FLoops

julia> @floop for x in generate123()
           @show x
       end
x = 1
x = 2
x = 3
```
