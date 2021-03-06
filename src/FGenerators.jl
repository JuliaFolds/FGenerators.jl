module FGenerators

# Use README as the docstring of the module:
@doc let path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    replace(read(path, String), r"^```julia"m => "```jldoctest README")
end FGenerators

export @fgenerator, @yield, @yieldfrom, Foldable

import ContextualMacros
using AbstractYieldMacros: @yield, @yieldfrom
using Base.Meta: isexpr
using FLoopsBase: with_extra_state_variables
using MacroTools: @capture, combinedef, splitdef
using Transducers: AdHocFoldable, Foldable, Transducers, foldl_nocomplete

"""
    @yield item

Yield an item from a generator.  This is usable only inside special
contexts such as within [`@fgenerator`](@ref) macro.
"""
:(@yield)

"""
    @yieldfrom foldable

Yield items from a `foldable`.  This is usable only inside special
contexts such as within [`@fgenerator`](@ref) macro.

## Examples

```jldoctest @yieldfrom
julia> using FGenerators

julia> @fgenerator function flatten2(xs, ys)
           @yieldfrom xs
           @yieldfrom ys
       end;

julia> collect(flatten2(1:2, 11:12))
4-element Array{Int64,1}:
  1
  2
 11
 12
```
"""
:(@yieldfrom)

const RF = gensym(:__rf__)
const ACC = gensym(:__acc__)

function _on_yield(ctx)
    if length(ctx.args) != 1
        throw(ArgumentError("`@yield` requires exactly one argument. Got:\n$(ctx.args)"))
    end
    x, = ctx.args
    quote
        $ACC = $Transducers.@next($RF, $ACC, $x)
    end |> esc
end

function _on_yieldfrom(ctx)
    if length(ctx.args) != 1
        throw(ArgumentError("`@yieldfrom` requires exactly one argument. Got:\n$(ctx.args)"))
    end
    foldable, = ctx.args
    quote
        $ACC = $Transducers.@return_if_reduced $foldl_nocomplete($RF, $ACC, $foldable)
    end |> esc
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
        if isexpr(x, :kw)
            x = x.args[1]
        end
        if @capture(x, args_...)
            args
        elseif @capture(x, a_::T_)
            a::Symbol
        else
            x::Symbol
        end
    end

    body = def[:body]
    funcname = gensym(string(def[:name], "#foldl"))
    folddef = define_foldl(__module__, funcname, NamedTuple, allargs, body)
    if VERSION < v"1.4"
        namedtuple(; kw...) = kw.data
        nt = :($namedtuple(; $((Expr(:kw, a, a) for a in allargs)...)))
    else
        nt = :((; $((Expr(:kw, a, a) for a in allargs)...)))
    end
    def[:body] = :($AdHocFoldable($folddef, $nt))
    esc(combinedef(def))
end

macro fgenerator(fun, coll)
    fun = _hack_annon!(fun)
    def = splitdef(fun)
    if !@capture(coll, collvar_::typename_)
        msg =
            "`@fgenerator(...) do; ...; end` (or two-argument form of `@fgenerator`)" *
            " requires `generator::GeneratorType` as in"
        throw(ArgumentError("""
        $msg

            @fgenerator(generator::GeneratorType) do
                ...
            end

        Instead of the argument of the form `generator::GeneratorType`, got:
        $coll
        """))
    end

    if length(def[:args]) != 0
        throw(ArgumentError(
            "`@fgenerator(...) do; ...; end` (or two-argument form of" *
            " `@fgenerator`) cannot be used with arguments after `do`. Got:\n" *
            join(def[:args], ", "),
        ))
    end
    if !isempty(def[:kwargs])
        # Since `do` block can't generate keyword arguments, assume
        # that it is from two-argument form.
        throw(ArgumentError(
            "Two-argument form of `@fgenerator` requires the first argument to" *
            " be a function with a single argument. Got a function with" *
            " keyword argument(s):\n" *
            string(:(; $(def[:kwargs]...))),
        ))
    end

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

function define_foldl(__module__::Module, funcname, structname, allargs, body)
    completion = :(return $Transducers.complete($RF, $ACC))
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
        return Expr(body.head, map(rewrite, body.args)...)
    end
    body = rewrite(body)
    if allargs isa Symbol
        xs = allargs
        unpack = []
    else
        @gensym xs
        unpack = [:(local $a = $xs.$a) for a in allargs]
    end
    ex = quote
        function $funcname($RF::RFType, $ACC, $xs::$structname) where {RFType}
            $(unpack...)
            $body
            $completion
        end
    end
    with_extra_state_variables([ACC]) do
        return ContextualMacros.expandwith(
            __module__,
            ex;
            yield = _on_yield,
            yieldfrom = _on_yieldfrom,
        )
    end
end

"""
    FGenerators.@with(f(...)) do ... end

Equivalent to `f(...) do ... end` but workarounds the boxing problem
when `@yield` is used inside the body of the `do` block.

!!! warning

    This macro is valid to use only for "context manager" type of `do`
    block use-case where the `do` block is executed *exactly once* and
    the result of the body is returned from `f`.  For example,
    `@with(open(filename)) do` is valid but `@with(map(xs)) do` is
    not.  This is because `map` can call the `do` block arbitrary
    number of times.
"""
macro with(doblock, call)
    @gensym acc1 acc2 ans1 ans2
    true_doblock = Expr(:block, __source__, doblock.args[end])
    doblock.args[end] = quote
        local $ACC = $acc1
        local $ans1 = $true_doblock
        ($ans1, $ACC)
    end
    calldo = Expr(:do, call, doblock)
    quote
        local $ans2, $acc2
        ($ans2, $acc2) = let $acc1 = $ACC
            $calldo
        end
        $ACC = $Transducers.@return_if_reduced $acc2
        $ans2
    end |> esc
end

end
