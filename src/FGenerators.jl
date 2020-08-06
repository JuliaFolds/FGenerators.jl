module FGenerators

# Use README as the docstring of the module:
@doc let path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    replace(read(path, String), r"^```julia"m => "```jldoctest README")
end FGenerators

export @fgenerator, @yield, Foldable

using Base.Meta: isexpr
using MacroTools: @capture, combinedef, splitdef
using Transducers: AdHocFoldable, Foldable, Transducers

__yield__(x = nothing) = error("@yield used outside @generator")

"""
    @yield item

Yield an item from a generator.  This is usable only inside special
contexts such as within [`@fgenerator`](@ref) macro.
"""
macro yield(x)
    :(__yield__($(esc(x))) && return)
end

function _hack_annon!(ex)
    if isexpr(ex, :function, 2) && isexpr(ex.args[1], :tuple)
        ex.args[1] = Expr(:call, :_, ex.args[1].args...)
        # Update MacroTools.jl after anonymous function is supported:
        # https://github.com/MikeInnes/MacroTools.jl/pull/140
    elseif isexpr(ex, :->, 2) && ex.args[1] isa Symbol
        ex = Expr(:function, Expr(:call, :_, ex.args[1]), ex.args[2])
    elseif isexpr(ex, :->, 2) && isexpr(ex.args[1], :tuple)
        ex = Expr(:function, Expr(:call, :_, ex.args[1].args...), ex.args[2])
    end
    return ex
end

"""
    @fgenerator function f(...) ... end
    @fgenerator f(...) = ...
    @fgenerator(generator::GeneratorType) do; ...; end

Define a function `f` that returns a "generator" usable with
Transducers.jl-compatible APIs (akd _foldable_ interface).  In
`@fgenerator(generator::GeneratorType) do ... end` form, define
Transducers.jl interface for `GeneratorType`.

Use [`@yield`](@ref) in the function body for producing an item.  Use
`return` to finish producing items.

See also [`FGenerators`](@ref).

# Extended help
## Examples

Defining a function that returns a generator:

```jldoctest @fgenerator
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
```

Defining foldable interface for a pre-existing type:

```jldoctest @fgenerator
julia> struct Counting end;

julia> @fgenerator(itr::Counting) do
           i = 1
           while true
               @yield i
               i += 1
           end
       end;

julia> using Transducers  # for `Take`

julia> Counting() |> Take(3) |> collect
3-element Array{Int64,1}:
 1
 2
 3
```

Note that function such as `collect` and `sum` still dispatches to
`iterate`-based methods (above `Counting` example worked because
`Counting` was wrapped by `Take`).  To automatically dispatch to
`foldl`-based methods, use `Foldable` as the supertype:

```jldoctest @fgenerator
julia> struct Count <: Foldable
           start::Int
           stop::Int
       end;

julia> @fgenerator(itr::Count) do
           i = itr.start
           i > itr.stop && return
           while true
               @yield i
               i == itr.stop && break
               i += 1
           end
       end;

julia> collect(Count(0, 2))
3-element Array{Int64,1}:
 0
 1
 2
```
"""
macro fgenerator(ex)
    ex = _hack_annon!(ex)
    def = splitdef(ex)

    if def[:name] === :_  # see `_hack_annon!`
        def[:name] = gensym(:anonymous)
    end

    allargs = map([def[:args]; def[:kwargs]]) do x
        if @capture(x, args_...)
            args
        else
            x::Symbol
        end
    end

    body = def[:body]
    funcname = gensym(string(def[:name], "#foldl"))
    folddef = define_foldl(__module__, funcname, NamedTuple, allargs, body)
    nt = :((; $((Expr(:kw, a, a) for a in allargs)...)))
    def[:body] = :($AdHocFoldable($folddef, $nt))
    esc(combinedef(def))
end

macro fgenerator(fun, coll)
    fun = _hack_annon!(fun)
    def = splitdef(fun)
    @assert isempty(def[:kwargs])
    @assert length(def[:args]) == 0
    @assert @capture(coll, collvar_::typename_)
    return esc(define_foldl(
        __module__,
        :($Transducers.__foldl__),
        typename,
        collvar,
        def[:body],
    ))
end

function is_function(ex)
    if isexpr(ex, :(=)) || isexpr(ex, :->)
        isexpr(ex.args[1], :call) && return true
        isexpr(ex.args[1], :where) && return true
    elseif isexpr(ex, :function)
        return true
    end
    return false
end

function define_foldl(yielded::Function, funcname, structname, allargs, body)
    @gensym rf acc
    completion = :(return $Transducers.complete($rf, $acc))
    function rewrite(body)
        body isa Expr || return body
        is_function(body) && return body
        isexpr(body, :meta) && return body
        if isexpr(body, :return)
            returning = get(body.args, 1, nothing)
            if returning in (:nothing, nothing)
                return completion
            end
            error("Returning non-nothing from a generator: $(body.args[1])")
        end
        if (x = yielded(body)) !== nothing
            # Found `@yield(x)`
            x = something(x)
            return :($acc = $Transducers.@next($rf, $acc, $x))
        end
        return Expr(body.head, map(rewrite, body.args)...)
    end
    body = rewrite(body)
    if allargs isa Symbol
        xs = allargs
        unpack = []
    else
        @gensym xs
        unpack = [:($a = $xs.$a) for a in allargs]
    end
    return quote
        function $funcname($rf::RF, $acc, $xs::$structname) where {RF}
            $(unpack...)
            $body
            $completion
        end
    end
end

define_foldl(__module__::Module, funcname, structname, allargs, body) =
    define_foldl(funcname, structname, allargs, body) do body
        if isexpr(body, :macrocall) && _issameref(__module__, body.args[1], var"@yield")
            @assert length(body.args) == 3
            return Some(body.args[end])
        elseif isexpr(body, :call) && _issameref(__module__, body.args[1], __yield__)
            # Just in case `macroexpand`'ed expression is provided.
            @assert length(body.args) == 2
            return Some(body.args[end])
        end
        return nothing
    end

struct _Undef end

@nospecialize
_resolveref(m, x::Symbol) = getfield(m, x)
_resolveref(m, x::Expr) =
    if isexpr(x, :.) && length(x.args) == 2
        y = _resolveref(m, x.args[1])
        y isa _Undef && return y
        _resolveref(y, x.args[2])
    else
        _Undef()
    end
_resolveref(m, x::QuoteNode) = _resolveref(m, x.value)
_resolveref(_, x) = x
function _issameref(m::Module, a, b)
    x = _resolveref(m, a)
    x isa _Undef && return false
    y = _resolveref(m, b)
    y isa _Undef && return false
    return x === y
end
@specialize

end
