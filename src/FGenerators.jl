module FGenerators

# Use README as the docstring of the module:
@doc let path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    replace(read(path, String), r"^```julia"m => "```jldoctest README")
end FGenerators

export @fgenerator, @yield

using Base.Meta: isexpr
using MacroTools: @capture, combinedef, splitdef
using Transducers: Foldable, Transducers

__yield__(x = nothing) = error("@yield used outside @generator")

macro yield(x)
    :(__yield__($(esc(x))) && return)
end

function _hack_annon!(ex)
    if isexpr(ex, :function, 2) && isexpr(ex.args[1], :tuple)
        ex.args[1] = Expr(:call, :_, ex.args[1].args...)
        # Update MacroTools.jl after anonymous function is supported:
        # https://github.com/MikeInnes/MacroTools.jl/pull/140
    elseif isexpr(ex, :->, 2)
        ex = Expr(:function, Expr(:call, :_, ex.args[1].args...), ex.args[2])
    end
    return ex
end

macro fgenerator(ex)
    # ex = _hack_annon!(ex)
    def = splitdef(ex)

    # if def[:name] === :_
    #     def[:name] = gensym(:anonymous)
    # end

    allargs = map([def[:args]; def[:kwargs]]) do x
        if @capture(x, args_...)
            args
        else
            x::Symbol
        end
    end

    tag = gensym(string(def[:name], "#itr"))
    structname = FGenerator{tag}

    body = def[:body]
    def[:body] = :($structname(($(allargs...),)))
    quote
        $(combinedef(def))
        $(define_foldl(__module__, structname, allargs, body))
    end |> esc
end

macro fgenerator(fun, coll)
    fun = _hack_annon!(fun)
    def = splitdef(fun)
    @assert isempty(def[:kwargs])
    @assert length(def[:args]) == 0
    @assert @capture(coll, collvar_::typename_)
    return esc(define_foldl(__module__, typename, collvar, def[:body]))
end

struct FGenerator{Tag,Params} <: Foldable
    params::Params
end

FGenerator{Tag}(params::Params) where {Tag,Params} = FGenerator{Tag,Params}(params)

function is_function(ex)
    if isexpr(ex, :(=)) || isexpr(ex, :->)
        isexpr(ex.args[1], :call) && return true
        isexpr(ex.args[1], :where) && return true
    elseif isexpr(ex, :function)
        return true
    end
    return false
end

function define_foldl(yielded::Function, structname, allargs, body)
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
        unpack = [:($a = $xs.params[$i]) for (i, a) in enumerate(allargs)]
    end
    # TODO: return AdHocFoldable when the input is anonymous function
    return quote
        function $Transducers.__foldl__($rf::RF, $acc, $xs::$structname) where {RF}
            $(unpack...)
            $body
            $completion
        end
    end
end

define_foldl(__module__::Module, structname, allargs, body) =
    define_foldl(structname, allargs, body) do body
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
