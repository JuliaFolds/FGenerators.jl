# FGenerators: `foldl` for humans™

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliafolds.github.io//FGenerators.jl/dev)
[![GitHub Actions](https://github.com/JuliaFolds//FGenerators.jl/workflows/Run%20tests/badge.svg)](https://github.com/JuliaFolds//FGenerators.jl/actions?query=workflow%3ARun+tests)

FGenerators.jl is a package for defining Transducers.jl-compatible
extended `foldl` with a simple `@yield`-based syntax.  Here are a few
examples for creating ad-hoc "generators":

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

julia> @fgenerator function organpipe2(n)
           @yieldfrom 1:n
           @yieldfrom n-1:-1:1
       end;

julia> collect(organpipe2(2))
3-element Array{Int64,1}:
 1
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

## Adding fold protocol to existing type

The `foldl` protocol can be implemented for an existing type `T`, by
using the syntax `@fgenerator(foldable::T) do .. end`:

```julia
julia> struct OrganPipe <: Foldable
           n::Int
       end

julia> @fgenerator(foldable::OrganPipe) do
           n = foldable.n
           @yieldfrom 1:n
           @yieldfrom n-1:-1:1
       end;

julia> collect(OrganPipe(2))
3-element Array{Int64,1}:
 1
 2
 1
```

## Defining parallelizable collection

`@fgenerator` alone is not enough for using parallel loops on the
collection.  However it can be easily supported by defining
[`SplittablesBase.halve`](https://github.com/JuliaFolds/SplittablesBase.jl)
and `length` (or `SplittablesBase.amount` if `length` is hard to
define).  Since `halve` and `length` has to be implemented on the same
existing type, `@fgenerator(...) do` notation as above should be used.
Extending `OrganPipe` example above:

```julia
julia> using SplittablesBase

julia> function SplittablesBase.halve(foldable::OrganPipe)
           n = foldable.n
           return (1:n, n-1:-1:1)
       end;

julia> Base.length(foldable::OrganPipe) = 2 * foldable.n - 1;

julia> @floop for x in OrganPipe(2)
           @reduce(s += x)
       end
       s
```
