module Plots

using Pkg

if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@optlevel"))
    @eval Base.Experimental.@optlevel 1
end
if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@max_methods"))
    @eval Base.Experimental.@max_methods 1
end

const _plots_project = Pkg.Types.read_project(normpath(@__DIR__, "..", "Project.toml"))
const _current_plots_version = _plots_project.version
const _plots_compats = _plots_project.compat
function _check_compat(sim::Module)
    sim_str = string(sim)
    haskey(_plots_compats, sim_str) || return nothing
    be_v = Pkg.Types.read_project(joinpath(Base.pkgdir(sim), "Project.toml")).version
    be_c = _plots_compats[sim_str]
    if be_c isa String # julia 1.6
        if !(be_v in Pkg.Types.semver_spec(be_c))
            @warn "$sim $be_v is not compatible with this version of Plots. The declared compatibility is $(be_c)."
        end
    else
        if isempty(intersect(be_v, be_c.val))
            @warn "$sim $be_v is not compatible with this version of Plots. The declared compatibility is $(be_c.str)."
        end
    end
end

using Reexport

using Dates, Printf, Statistics, Base64, LinearAlgebra, Random, Unzip
using SparseArrays

using FFMPEG

@reexport using RecipesBase
import RecipesBase: plot, plot!, animate, is_explicit, grid
using Base.Meta
@reexport using PlotUtils
@reexport using PlotThemes
import UnicodeFun
import StatsBase
import Downloads
import Showoff
import JSON
import JLFzf

using Requires

#! format: off
export
    grid,
    bbox,
    plotarea,
    KW,

    wrap,
    theme,

    plot,
    plot!,
    attr!,

    current,
    default,
    with,
    twinx,

    pie,
    pie!,
    plot3d,
    plot3d!,

    title!,
    annotate!,

    xlims,
    ylims,
    zlims,

    savefig,
    png,
    gui,
    inline,
    closeall,

    backend,
    backends,
    backend_name,
    backend_object,
    aliases,

    Shape,
    text,
    font,
    stroke,
    brush,
    Surface,
    OHLC,
    arrow,
    Segments,
    Formatted,

    Animation,
    frame,
    gif,
    mov,
    mp4,
    webm,
    animate,
    @animate,
    @gif,

    test_examples,
    iter_segments,
    coords,

    translate,
    translate!,
    rotate,
    rotate!,
    center,
    BezierCurve,

    plotattr,
    scalefontsize,
    scalefontsizes,
    resetfontsizes
#! format: on
# ---------------------------------------------------------

import NaNMath # define functions that ignores NaNs. To overcome the destructive effects of https://github.com/JuliaLang/julia/pull/12563
ignorenan_minimum(x::AbstractArray{<:AbstractFloat}) = NaNMath.minimum(x)
ignorenan_minimum(x) = Base.minimum(x)
ignorenan_maximum(x::AbstractArray{<:AbstractFloat}) = NaNMath.maximum(x)
ignorenan_maximum(x) = Base.maximum(x)
ignorenan_mean(x::AbstractArray{<:AbstractFloat}) = NaNMath.mean(x)
ignorenan_mean(x) = Statistics.mean(x)
ignorenan_extrema(x::AbstractArray{<:AbstractFloat}) = NaNMath.extrema(x)
ignorenan_extrema(x) = Base.extrema(x)

# ---------------------------------------------------------

# to cater for block matrices, Base.transpose is recursive.
# This makes it impossible to create row vectors of String and Symbol with the transpose operator.
# This solves this issue, internally in Plots at least.

# commented out on the insistence of the METADATA maintainers

#Base.transpose(x::Symbol) = x
#Base.transpose(x::String) = x

# ---------------------------------------------------------

import Measures

include("plotmeasures.jl")

using .PlotMeasures
import .PlotMeasures: Length, AbsoluteLength, Measure, width, height
# ---------------------------------------------------------

import RecipesPipeline
import RecipesPipeline:
    SliceIt,
    DefaultsDict,
    Formatted,
    AbstractSurface,
    Surface,
    Volume,
    is3d,
    is_surface,
    needs_3d_axes,
    group_as_matrix, # for StatsPlots
    reset_kw!,
    pop_kw!,
    scale_func,
    inverse_scale_func,
    dateformatter,
    datetimeformatter,
    timeformatter

# Use fixed version of Plotly instead of the latest one for stable dependency
# Ref: https://github.com/JuliaPlots/Plots.jl/pull/2779
const _plotly_min_js_filename = "plotly-2.6.3.min.js"

include("types.jl")
include("utils.jl")
include("colorbars.jl")
include("axes.jl")
include("args.jl")
include("components.jl")
include("consts.jl")
include("themes.jl")
include("plot.jl")
include("pipeline.jl")
include("layouts.jl")
include("recipes.jl")
include("animation.jl")
include("examples.jl")
include("arg_desc.jl")
include("plotattr.jl")
include("backends.jl")
include("output.jl")
include("ijulia.jl")
include("fileio.jl")
include("init.jl")
include("legend.jl")

include("backends/plotly.jl")
include("backends/gr.jl")
include("backends/web.jl")

const PlotOrSubplot = Union{Plot,Subplot}
include("shorthands.jl")

# ---------------------------------------------------------

const CURRENT_BACKEND = CurrentBackend(:none)
const PLOTS_SEED = 1234

using SnoopPrecompile

@precompile_setup begin
    n = length(_examples)
    imports = sizehint!(Expr[], n)
    examples = sizehint!(Expr[], 10n)
    for i in setdiff(1:n, _backend_skips[:gr])
        _examples[i].external && continue
        (imp = _examples[i].imports) === nothing || push!(imports, imp)
        func = gensym(string(i))
        push!(examples, quote
            $func() = begin  # evaluate each example in a local scope
                # @show $i  # debug
                $(_examples[i].exprs)
                if $i == 1  # only for one example
                    fn = tempname()
                    pl = current()
                    gui(pl)
                    savefig(pl, "$fn.png")
                    savefig(pl, "$fn.pdf")
                end
                nothing
            end
            $func()
        end)
    end
    withenv("GKSwstype" => "nul") do
        @precompile_all_calls begin
            eval.(imports)
            gr()
            eval.(examples)
            # eventually eval for another backend ...
        end
    end
end

end
