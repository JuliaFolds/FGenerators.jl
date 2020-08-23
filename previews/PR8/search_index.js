var documenterSearchIndex = {"docs":
[{"location":"#FGenerators.jl","page":"FGenerators.jl","title":"FGenerators.jl","text":"","category":"section"},{"location":"","page":"FGenerators.jl","title":"FGenerators.jl","text":"","category":"page"},{"location":"","page":"FGenerators.jl","title":"FGenerators.jl","text":"FGenerators\nFGenerators.@fgenerator\nFGenerators.@yield","category":"page"},{"location":"#FGenerators","page":"FGenerators.jl","title":"FGenerators","text":"FGenerators: foldl for humans™\n\n(Image: Dev) (Image: GitHub Actions)\n\nFGenerators.jl is a package for defining Transducers.jl-compatible extended foldl with a simple @yield-based syntax.  An example for creating an ad-hoc \"generator\":\n\njulia> using FGenerators\n\njulia> @fgenerator function generate123()\n           @yield 1\n           @yield 2\n           @yield 3\n       end;\n\njulia> collect(generate123())\n3-element Array{Int64,1}:\n 1\n 2\n 3\n\njulia> sum(generate123())\n6\n\njulia> @fgenerator function organpipe(n::Integer)\n           i = 0\n           while i != n\n               i += 1\n               @yield i\n           end\n           while true\n               i -= 1\n               i == 0 && return\n               @yield i\n           end\n       end;\n\njulia> collect(organpipe(3))\n5-element Array{Int64,1}:\n 1\n 2\n 3\n 2\n 1\n\nFGenerators.jl is a spin-off of GeneratorsX.jl.\n\nUse FLoops.jl to iterate over the items yielded from the generator:\n\njulia> using FLoops\n\njulia> @floop for x in generate123()\n           @show x\n       end\nx = 1\nx = 2\nx = 3\n\n\n\n\n\n","category":"module"},{"location":"#FGenerators.@fgenerator","page":"FGenerators.jl","title":"FGenerators.@fgenerator","text":"@fgenerator function f(...) ... end\n@fgenerator f(...) = ...\n@fgenerator(generator::GeneratorType) do; ...; end\n\nDefine a function f that returns a \"generator\" usable with Transducers.jl-compatible APIs (akd foldable interface).  In @fgenerator(generator::GeneratorType) do ... end form, define Transducers.jl interface for GeneratorType.\n\nUse @yield in the function body for producing an item.  Use return to finish producing items.\n\nSee also FGenerators.\n\nExtended help\n\nExamples\n\nDefining a function that returns a generator:\n\njulia> using FGenerators\n\njulia> @fgenerator function generate123()\n           @yield 1\n           @yield 2\n           @yield 3\n       end;\n\njulia> collect(generate123())\n3-element Array{Int64,1}:\n 1\n 2\n 3\n\nDefining foldable interface for a pre-existing type:\n\njulia> struct Counting end;\n\njulia> @fgenerator(itr::Counting) do\n           i = 1\n           while true\n               @yield i\n               i += 1\n           end\n       end;\n\njulia> using Transducers  # for `Take`\n\njulia> Counting() |> Take(3) |> collect\n3-element Array{Int64,1}:\n 1\n 2\n 3\n\nNote that function such as collect and sum still dispatches to iterate-based methods (above Counting example worked because Counting was wrapped by Take).  To automatically dispatch to foldl-based methods, use Foldable as the supertype:\n\njulia> struct Count <: Foldable\n           start::Int\n           stop::Int\n       end;\n\njulia> @fgenerator(itr::Count) do\n           i = itr.start\n           i > itr.stop && return\n           while true\n               @yield i\n               i == itr.stop && break\n               i += 1\n           end\n       end;\n\njulia> collect(Count(0, 2))\n3-element Array{Int64,1}:\n 0\n 1\n 2\n\n\n\n\n\n","category":"macro"},{"location":"#FGenerators.@yield","page":"FGenerators.jl","title":"FGenerators.@yield","text":"@yield item\n\nYield an item from a generator.  This is usable only inside special contexts such as within @fgenerator macro.\n\n\n\n\n\n","category":"macro"}]
}
