module Lib_Arts

# ==============================================================================
# DOECISORY - LIB ARTS (VISUALISATION)
# ==============================================================================
# Description: Visualisation and graphics module for academic data 
#              representation and response surface mapping.
# Module Tag:  ARTS
# ==============================================================================

using Base.Threads
using PlotlyJS
using Printf
using Statistics
using Distributions
using DataFrames
using ..Sys_Fast
using ..Lib_Core

const Main = parentmodule(@__MODULE__)

export ARTS_RenderPareto_DDEF, ARTS_RenderFit_DDEF, ARTS_RenderSurface_DDEF,
    ARTS_RenderContour_DDEF, ARTS_RenderSlice_DDEF, ARTS_RenderTrend_DDEF,
    ARTS_RenderSpace_DDEF, ARTS_RenderCandidates_DDEF, ARTS_Render_DDEF,
    ARTS_Downsample_DDEF, ARTS_RenderOptimalZone_DDEF, ARTS_RenderInteractionMatrix_DDEF,
    ARTS_RenderQQPlot_DDEF, ARTS_RenderResidualsVsPred_DDEF, ARTS_RenderSensitivityPlot_DDEF,
    ARTS_BaseLayout_DDEF, ARTS_Predict_DDEF, ARTS_BuildGrid_DDEF, ARTS_AdaptiveGridN_DDEF,
    ARTS_RenderSpaceImpl_DDEF, ARTS_GetDynamicN_DDEF, ARTS_PlotPareto_DDES,
    ARTS_PlotFit_DDES, ARTS_PlotInteractionMatrix_DDES, ARTS_PlotQQ_DDES,
    ARTS_PlotResiduals_DDES, ARTS_PlotSensitivity_DDES, ARTS_PlotSurface_DDES,
    ARTS_PlotContour_DDES, ARTS_PlotSlice_DDES, ARTS_PlotTrend_DDES,
    ARTS_PlotOptimalZone_DDES, ARTS_PlotDesignSpace_DDES, ARTS_PlotCandidates_DDES

# ==============================================================================
# PART A: VISUAL CORE & INFRASTRUCTURE
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 1: THEME & CONSTANTS
# ------------------------------------------------------------------------------

abstract type ARTS_AbstractPlotType_DDET end
struct ARTS_PlotPareto_DDES       <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotFit_DDES          <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotSurface_DDES      <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotContour_DDES      <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotSlice_DDES        <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotTrend_DDES        <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotOptimalZone_DDES  <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotDesignSpace_DDES  <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotCandidates_DDES   <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotInteractionMatrix_DDES <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotQQ_DDES            <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotResiduals_DDES     <: ARTS_AbstractPlotType_DDET end
struct ARTS_PlotSensitivity_DDES   <: ARTS_AbstractPlotType_DDET end

const ARTS_Theme_DDEC = let C = Main.Sys_Fast.FAST_Data_DDEC
    (
        PURWHI = C.COLOUR_PURWHI,
        LIGHIG = C.COLOUR_LIGHIG,
        LIGLOW = C.COLOUR_LIGLOW,
        DARLOW = C.COLOUR_DARLOW,
        DARHIG = C.COLOUR_DARHIG,
        PURBLA = C.COLOUR_PURBLA,
        HUERED = C.COLOUR_HUERED,
        SHAMAG = C.COLOUR_SHAMAG,
        SHABLU = C.COLOUR_SHABLU,
        TONCYA = C.COLOUR_TONCYA,
        TONGRE = C.COLOUR_TONGRE,
        HUEYEL = C.COLOUR_HUEYEL,
        FONT   = C.FONT_DEFAULT
    )
end

const ARTS_FactorPairs_DDEC = ((1, 2), (1, 3), (2, 3))

const ARTS_ViridisScale_DDEC = let C = Main.Sys_Fast.FAST_Data_DDEC
    [
        [0.00, C.COLOUR_SHAMAG],
        [0.25, C.COLOUR_SHABLU],
        [0.50, C.COLOUR_TONCYA],
        [0.75, C.COLOUR_TONGRE],
        [1.00, C.COLOUR_HUEYEL]
    ]
end

# ------------------------------------------------------------------------------
# SECTION 2: PLOT DIMENSIONS & FONT SIZES
# ------------------------------------------------------------------------------

const ARTS_PlotWidth_DDEC    = 320
const ARTS_PlotHeight_DDEC   = 400
const ARTS_SizeTitle_DDEC    = 14
const ARTS_SizeLabel_DDEC    = 11
const ARTS_SizeTick_DDEC     = 9
const ARTS_SizeLegend_DDEC   = 9
const ARTS_SizeAnnot_DDEC    = 9
const ARTS_SizeColourbar_DDEC = 8
const ARTS_SizeMarker_DDEC   = 7
const ARTS_SizeLeader_DDEC   = 2
const ARTS_WidthLine_DDEC    = 1.5
const ARTS_WidthGrid_DDEC    = 0.5

# ------------------------------------------------------------------------------
# SECTION 3: BASE LAYOUT FACTORY
# ------------------------------------------------------------------------------

"""
    ARTS_BaseLayout_DDEF(title; [height]) -> Layout
Generates a standardised PlotlyJS layout with fixed square canvas.
"""
function ARTS_BaseLayout_DDEF(title::AbstractString; height=ARTS_PlotHeight_DDEC)
    return Layout(;
        title=attr(
            text=title,
            font=attr(
                size=ARTS_SizeTitle_DDEC,
                family=ARTS_Theme_DDEC.FONT,
                color=ARTS_Theme_DDEC.PURBLA
            ),
            x=0.5,
            xanchor="center",
            y=0.92
        ),
        width=ARTS_PlotWidth_DDEC,
        height=height,
        autosize=true,
        paper_bgcolor=ARTS_Theme_DDEC.PURWHI,
        plot_bgcolor=ARTS_Theme_DDEC.PURWHI,
        font=attr(
            family=ARTS_Theme_DDEC.FONT,
            color=ARTS_Theme_DDEC.DARHIG,
            size=ARTS_SizeLabel_DDEC
        ),
        margin=attr(l=40, r=30, t=60, b=40),
        showlegend=true,
        legend=attr(
            orientation="h",
            yanchor="top",
            y=-0.28,
            xanchor="center",
            x=0.5,
            font=attr(size=ARTS_SizeLegend_DDEC),
            tracegroupgap=5
        ),
        xaxis=attr(
            showline=true,
            showgrid=true,
            gridcolor=ARTS_Theme_DDEC.LIGHIG,
            gridwidth=ARTS_WidthGrid_DDEC,
            griddash="dash",
            zeroline=false,
            linecolor=ARTS_Theme_DDEC.LIGHIG,
            linewidth=ARTS_WidthGrid_DDEC,
            mirror=true,
            ticks="outside",
            tickfont=attr(size=ARTS_SizeTick_DDEC),
            automargin=true
        ),
        yaxis=attr(
            showline=true,
            showgrid=true,
            gridcolor=ARTS_Theme_DDEC.LIGHIG,
            gridwidth=ARTS_WidthGrid_DDEC,
            griddash="dash",
            zeroline=false,
            linecolor=ARTS_Theme_DDEC.LIGHIG,
            linewidth=ARTS_WidthGrid_DDEC,
            mirror=true,
            ticks="outside",
            tickfont=attr(size=ARTS_SizeTick_DDEC),
            automargin=true
        ),
        colorway=[
            ARTS_Theme_DDEC.SHAMAG,
            ARTS_Theme_DDEC.TONGRE,
            ARTS_Theme_DDEC.HUEYEL,
            ARTS_Theme_DDEC.SHABLU,
            ARTS_Theme_DDEC.TONCYA
        ],
        hovermode="closest",
        template="plotly_white"
    )
end

# ------------------------------------------------------------------------------
# SECTION 4: SMART DOWNSAMPLING & GRID LIMITER CONSTANTS
# ------------------------------------------------------------------------------

const ARTS_MaxGridPoints_DDEC = 11000

# ------------------------------------------------------------------------------
# SECTION 5: ADAPTIVE GRID RESOLUTION LOGIC
# ------------------------------------------------------------------------------

"""
    ARTS_AdaptiveGridN_DDEF(preferred, [max_total]) -> Int
Returns a grid resolution N such that N×N ≤ max_total.
"""
function ARTS_AdaptiveGridN_DDEF(preferred::Integer, max_total::Integer=ARTS_MaxGridPoints_DDEC)
    N = preferred
    while N * N > max_total && N > 5
        N -= 1
    end
    return N
end

# ------------------------------------------------------------------------------
# SECTION 6: DYNAMIC HARDWARE RESOLUTION & DOWNSAMPLING & MATRIX PREPARATION
# ------------------------------------------------------------------------------

"""
    ARTS_GetDynamicN_DDEF() -> Int
Returns a dynamic grid resolution (N) based on available system hardware threads.
Rule: N=61 for ≤4 threads, N=101 for >4 threads.
"""
function ARTS_GetDynamicN_DDEF()::Int
    threads = Main.Sys_Fast.FAST_GetComputeThreads_DDEF()
    return (threads <= 4 ? 61 : 101)
end

"""
    ARTS_Downsample_DDEF(Z, target_rows, target_cols) -> Matrix
Sub-samples oversized matrices using strided decimation for optimal browser performance.
"""
function ARTS_Downsample_DDEF(Z::AbstractMatrix{T}, target_rows::Integer, target_cols::Integer) where T
    nr, nc = size(Z)
    (nr ≤ target_rows && nc ≤ target_cols) && return Z

    row_stride = max(1, nr ÷ target_rows)
    col_stride = max(1, nc ÷ target_cols)

    row_idx = 1:row_stride:nr
    col_idx = 1:col_stride:nc

    row_idx = unique([collect(row_idx); nr])
    col_idx = unique([collect(col_idx); nc])

    Main.Sys_Fast.FAST_Log_DDEF("ARTS", "DOWNSAMPLE",
        "Reduced $(nr)×$(nc) → $(length(row_idx))×$(length(col_idx))", "INFO")
    return Z[row_idx, col_idx]
end

"""
    ARTS_SmoothMatrix_DDEF(Z, [passes]) -> Matrix
Applies a 3x3 box blur filter to a matrix to reduce visual aliasing (staircase effect).
Automatically handles NaNs by calculating the mean of valid neighbouring pixels.
Includes boundary handling for consistent smoothing across the entire surface.
"""
function ARTS_SmoothMatrix_DDEF(Z::AbstractMatrix{Float64}, passes::Integer=1)
    nr, nc = size(Z)
    (nr < 2 || nc < 2) && return Z
    
    Current = copy(Z)
    for _ in 1:passes
        Next = copy(Current)
        
        @inbounds for j in 1:nc
            for i in 1:nr
                r_start, r_end = max(1, i-1), min(nr, i+1)
                c_start, c_end = max(1, j-1), min(nc, j+1)
                
                s_val = 0.0
                s_cnt = 0
                
                for c in c_start:c_end
                    for r in r_start:r_end
                        v = Current[r, c]
                        if !isnan(v)
                            s_val += v
                            s_cnt += 1
                        end
                    end
                end
                
                if s_cnt > 0
                    Next[i, j] = s_val / s_cnt
                end
            end
        end
        Current = Next
    end
    
    return Current
end

"""
    ARTS_PrepareMatrix_DDEF(M) -> Matrix{Float64}
Defensive matrix converter for JSON/store deserialised arrays or generic matrices.
"""
function ARTS_PrepareMatrix_DDEF(M::Matrix{Float64})
    return M
end

function ARTS_PrepareMatrix_DDEF(M::AbstractMatrix)
    return Float64.(collect(M))
end

function ARTS_PrepareMatrix_DDEF(M::AbstractVector)
    if !isempty(M) && all(m -> m isa AbstractVector, M)
        return Float64.(reduce(vcat, transpose.(collect.(M))))
    end
    return Float64.(collect(M))
end

function ARTS_PrepareMatrix_DDEF(M::Any)
    return Float64.(collect(M))
end

"""
    ARTS_PrepareStringVector_DDEF(S) -> Vector{String}
Defensive string vector converter that returns the vector directly if already Vector{String}.
"""
function ARTS_PrepareStringVector_DDEF(S::Vector{String})
    return S
end

function ARTS_PrepareStringVector_DDEF(S::AbstractVector)
    return collect(String, map(string, S))
end

"""
    ARTS_PrepareFloatVector_DDEF(V) -> Vector{Float64}
Defensive float vector converter that returns the vector directly if already Vector{Float64}.
"""
function ARTS_PrepareFloatVector_DDEF(V::Vector{Float64})
    return V
end

function ARTS_PrepareFloatVector_DDEF(V::AbstractVector)
    return collect(Float64, V)
end

"""
    ARTS_PrepareNestedVector_DDEF(N) -> Vector{Vector{Float64}}
Defensive nested float vector converter that returns the vector directly if already Vector{Vector{Float64}}.
"""
function ARTS_PrepareNestedVector_DDEF(N::Vector{Vector{Float64}})
    return N
end

function ARTS_PrepareNestedVector_DDEF(N::AbstractVector)
    return [collect(Float64, s) for s in N]
end

"""
    ARTS_HexToRGBA_DDEF(hex, alpha) -> String
    Converts hex colour strings to RGBA format for Plotly transparency support.
"""
function ARTS_HexToRGBA_DDEF(hex::AbstractString, alpha::AbstractFloat)
    h = replace(hex, "#" => "")
    r = parse(Int, h[1:2], base=16)
    g = parse(Int, h[3:4], base=16)
    b = parse(Int, h[5:6], base=16)
    return "rgba($r, $g, $b, $alpha)"
end

"""
    ARTS_GenerateAlphaViridis_DDEF(thresh) -> Vector
Generates a custom Viridis colorscale with a smooth alpha-gradient at the threshold.
Eliminates aliasing by using fragment-level transparency instead of mesh-level NaN clipping.
"""
function ARTS_GenerateAlphaViridis_DDEF(thresh::AbstractFloat)
    C = Main.Sys_Fast.FAST_Data_DDEC
    fade_start = max(0.0, thresh - 0.10)
    
    base_cols = [
        C.COLOUR_SHAMAG, C.COLOUR_SHABLU, C.COLOUR_TONCYA, C.COLOUR_TONGRE, C.COLOUR_HUEYEL
    ]
    
    scale = Any[]
    push!(scale, [0.0, "rgba(255,255,255,0)"])
    push!(scale, [max(0.0, fade_start - 0.01), "rgba(255,255,255,0)"])
    
    # Smooth Alpha Transition Zone
    push!(scale, [fade_start, ARTS_HexToRGBA_DDEF(base_cols[1], 0.0)])
    push!(scale, [thresh,     ARTS_HexToRGBA_DDEF(base_cols[1], 1.0)])
    
    # Mapped Viridis Zone
    for i in 2:5
        val = thresh + (1.0 - thresh) * ((i - 1) / 4)
        push!(scale, [val, ARTS_HexToRGBA_DDEF(base_cols[i], 1.0)])
    end
    
    return scale
end

# ==============================================================================
# PART B: ACADEMIC DIAGNOSTICS & PLOTTING
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 7: PARETO ANALYSIS VISUALISER (MULTIPLE DISPATCH)
# ------------------------------------------------------------------------------

"""
    ARTS_RenderPareto_DDEF(Model, OutName, R2_Adj, Q2) -> Plot
Convenience dispatch wrapper for the Pareto Draw pipeline.
"""
function ARTS_RenderPareto_DDEF(Model::AbstractDict, OutName::AbstractString, R2_Adj::AbstractFloat, R2_Pred::AbstractFloat)
    return ARTS_Draw_DDEF(ARTS_PlotPareto_DDES(), Model, OutName, R2_Adj, R2_Pred)
end

function ARTS_Draw_DDEF(::ARTS_PlotPareto_DDES, Model::AbstractDict, OutName::AbstractString, R2_Adj::AbstractFloat, R2_Pred::AbstractFloat)
    mod_status = get(Model, "Status", "FAIL")
    if mod_status != "OK"
        # Emergency placeholder layout for failed models
        layout = ARTS_BaseLayout_DDEF("Analysis Bypass: $OutName")
        return Plot(scatter(x=[0], y=[0], mode="text", text="Modelling Failure: Check Diagnostics"), layout)
    end
    
    # Defensive acquisition of model coefficients and metadata
    Coefs = get(Model, "Coefs", Float64[])
    isempty(Coefs) && return Plot(scatter(x=[0], y=[0], mode="text", text="Incomplete Data: No Coefs"), ARTS_BaseLayout_DDEF(OutName))
    
    Names = get(Model, "TermNames", ["T$i" for i in eachindex(Coefs)])
    t_Stats = get(Model, "t_Stats", Coefs) 
    N_Samples = get(Model, "N_Samples", length(Coefs) + 5)

    clean_eff = @view t_Stats[2:end]
    clean_nms = @view Names[2:end]
    clean_signs = any(isnan, clean_eff) ? sign.(@view Coefs[2:end]) : sign.(clean_eff)
    magnitudes = any(isnan, clean_eff) ? abs.(@view Coefs[2:end]) : abs.(clean_eff)

    perm = sortperm(magnitudes)
    sorted_mag, sorted_nms, sorted_sgn = magnitudes[perm], clean_nms[perm], clean_signs[perm]

    traces = GenericTrace[]
    for (sgn, col, label) in [(-1, ARTS_Theme_DDEC.SHAMAG, "Negative Effect"), (1, ARTS_Theme_DDEC.HUEYEL, "Positive Effect")]
        idx = findall(x -> sgn == -1 ? x < 0 : x >= 0, sorted_sgn)
        if !isempty(idx)
            push!(traces, bar(;
                x=sorted_mag[idx], y=sorted_nms[idx], orientation="h", name=label,
                marker=attr(color=col, line=attr(width=0)),
                text=[@sprintf("%.2f", m) for m in sorted_mag[idx]],
                textposition="auto", textfont=attr(size=ARTS_SizeAnnot_DDEC)
            ))
        end
    end

    r2_str, q2_str = [@sprintf("%.3f", isnan(v) ? 0.0 : v) for v in (R2_Adj, R2_Pred)]
    layout = ARTS_BaseLayout_DDEF("Pareto: $OutName (R²Adj: $r2_str | Q²: $q2_str)")
    layout[:xaxis][:title] = "Standardised Effect (|t-value|)"
    layout[:barmode] = "stack"

    df, alpha = max(1, N_Samples - length(Coefs)), 0.05 / length(clean_eff)
    t_crit = quantile(TDist(df), 1.0 - alpha / 2)
    layout[:shapes] = [attr(type="line", x0=t_crit, x1=t_crit, y0=0, y1=1, yref="paper", line=attr(color=ARTS_Theme_DDEC.HUERED, width=2, dash="dash"))]

    return Plot(traces, layout)
end

# ------------------------------------------------------------------------------
# SECTION 8: PREDICTION ACCURACY PLOTS
# ------------------------------------------------------------------------------

"""
    ARTS_RenderFit_DDEF(Y_Real, Y_Pred, OutName) -> Plot
Convenience dispatch wrapper for the Fit Accuracy Draw pipeline.
"""
function ARTS_RenderFit_DDEF(Y_Real::AbstractVector{Float64}, Y_Pred::AbstractVector{Float64}, OutName::AbstractString)
    return ARTS_Draw_DDEF(ARTS_PlotFit_DDES(), Y_Real, Y_Pred, OutName)
end

function ARTS_Draw_DDEF(::ARTS_PlotFit_DDES, Y_Real::AbstractVector{Float64}, Y_Pred::AbstractVector{Float64}, OutName::AbstractString)
    mn, mx = min(minimum(Y_Real), minimum(Y_Pred)), max(maximum(Y_Real), maximum(Y_Pred))
    margin = (mx - mn) * 0.05

    t_data = scatter(; x = Y_Real, y = Y_Pred, mode = "markers",
        marker = attr(size=ARTS_SizeMarker_DDEC, color=ARTS_Theme_DDEC.TONGRE, line=attr(width=1, color=ARTS_Theme_DDEC.PURBLA)), 
        name = "Measured Data")

    t_ideal = scatter(; x = [mn - margin, mx + margin], y = [mn - margin, mx + margin],
        mode = "lines", line = attr(color=ARTS_Theme_DDEC.DARHIG, dash="dash", width=ARTS_WidthLine_DDEC), 
        name = "Perfect Fit (Ideal)")

    layout = ARTS_BaseLayout_DDEF("Prediction Accuracy Audit: $OutName")
    layout[:xaxis][:title], layout[:yaxis][:title] = "Experimental Record", "Model Estimation"
    
    return Plot([t_data, t_ideal], layout)
end

# ==============================================================================
# PART C: RESPONSE SURFACE METHODOLOGY (RSM) ANALYTICS
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 9: RSM INTERNAL PREDICTION GATEWAY
# ------------------------------------------------------------------------------

"""
    ARTS_Predict_DDEF(Model, X) -> Vector{Float64}
Internal evaluator for plotting grids (stateless design matrix expansion).
"""
function ARTS_Predict_DDEF(Model::AbstractDict, X::AbstractMatrix{Float64}, buff_Xd::Union{Nothing, AbstractMatrix{Float64}}=nothing)
    m_type = Main.Lib_Core.CORE_GetModelType_DDEF(string(get(Model, "ModelType", "quadratic")))
    return ARTS_Predict_DDEF(m_type, X, get(Model, "Coefs", Float64[]), buff_Xd)
end

function ARTS_Predict_DDEF(::Main.Lib_Core.CORE_ModelQuadratic_DDES, X::AbstractMatrix{Float64}, Beta::AbstractVector, buff_Xd)
    return ARTS_PredictQuadratic_DDEF(X, Beta, buff_Xd)
end

function ARTS_Predict_DDEF(::Main.Lib_Core.CORE_ModelLinear_DDES, X::AbstractMatrix{Float64}, Beta::AbstractVector, buff_Xd)
    return ARTS_PredictLinear_DDEF(X, Beta, buff_Xd)
end

function ARTS_PredictLinear_DDEF(X, Beta, buff_Xd)
    N = size(X, 1)
    if isnothing(buff_Xd)
        Xd = hcat(ones(N), X)
    else
        Xd = view(buff_Xd, 1:N, 1:4)
        fill!(view(Xd, :, 1), 1.0)
        copyto!(view(Xd, :, 2:4), X)
    end
    return Xd * Beta
end

function ARTS_PredictQuadratic_DDEF(X, Beta, buff_Xd)
    N = size(X, 1)
    # Standard 10-term Quadratic (1 + 3 + 3 + 3)
    Xd = if !isnothing(buff_Xd) && size(buff_Xd, 1) >= N && size(buff_Xd, 2) >= 10
        view(buff_Xd, 1:N, 1:10)
    else
        Matrix{Float64}(undef, N, 10)
    end
    
    fill!(view(Xd, :, 1), 1.0)
    copyto!(view(Xd, :, 2:4), X)
    
    # Interactions: Optimised mapping for 3-factor system
    @inbounds @views begin
        @. Xd[:, 5] = X[:, 1] * X[:, 2]
        @. Xd[:, 6] = X[:, 1] * X[:, 3]
        @. Xd[:, 7] = X[:, 2] * X[:, 3]
        @. Xd[:, 8:10] = abs2(X)
    end
    
    return Xd * Beta
end

# ------------------------------------------------------------------------------
# SECTION 10: PREDICTION GRID CONSTRUCTOR
# ------------------------------------------------------------------------------

function ARTS_BuildGrid_DDEF(X::AbstractMatrix{Float64}, ix::Integer, iy::Integer, N_requested::Integer, buff_Grid::Union{Nothing, AbstractMatrix{Float64}}=nothing)
    N = ARTS_AdaptiveGridN_DDEF(N_requested)
    x1 = range(minimum(view(X, :, ix)), maximum(view(X, :, ix)); length=N)
    x2 = range(minimum(view(X, :, iy)), maximum(view(X, :, iy)); length=N)

    Grid = if !isnothing(buff_Grid) && size(buff_Grid, 1) >= (N*N)
        view(buff_Grid, 1:(N*N), :)
    else
        repeat(mean(X; dims=1), N * N)
    end
    
    @inbounds for (k, pt) in enumerate(Iterators.product(x1, x2))
        Grid[k, ix] = pt[1]
        Grid[k, iy] = pt[2]
    end
    return x1, x2, Grid
end

# ------------------------------------------------------------------------------
# SECTION 11: 3D RESPONSE SURFACE RENDERER
# ------------------------------------------------------------------------------

"""
    ARTS_RenderSurface_DDEF(Model, X_Train, Idx, Lbls, OutName) -> Plot
Convenience dispatch wrapper for the 3D Surface Draw pipeline.
"""
function ARTS_RenderSurface_DDEF(Model::AbstractDict, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString)
    return ARTS_Draw_DDEF(ARTS_PlotSurface_DDES(), Model, X, Idx, Lbls, OutName)
end

function ARTS_Draw_DDEF(::ARTS_PlotSurface_DDES, Model::AbstractDict, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString)
    ix, iy = Idx[1], Idx[2]
    N = ARTS_GetDynamicN_DDEF()
    x1, x2, Grid = ARTS_BuildGrid_DDEF(X, ix, iy, N)
    Z = reshape(ARTS_Predict_DDEF(Model, Grid), N, N)'

    # Internal decimation safeguard for high-resolution surfaces
    if length(Z) > ARTS_MaxGridPoints_DDEC
        target_N = Int(sqrt(ARTS_MaxGridPoints_DDEC))
        Z = ARTS_Downsample_DDEF(Z, target_N, target_N)
        # Re-map x/y axes for decimated matrix
        x1 = range(first(x1), last(x1), length=size(Z, 2))
        x2 = range(first(x2), last(x2), length=size(Z, 1))
    end
    
    # Apply Smoothing (Anti-aliasing)
    Z = ARTS_SmoothMatrix_DDEF(Z, 1)

    trace = surface(; x=collect(x1), y=collect(x2), z=Z, colorscale=ARTS_ViridisScale_DDEC,
        contours=attr(z=attr(show=true, usecolormap=true, project_z=true)),
        colorbar=attr(orientation="h", x=0.5, xanchor="center", y=-0.24, yanchor="top", thickness=15, len=0.6, tickfont=attr(size=ARTS_SizeColourbar_DDEC)))

    layout = ARTS_BaseLayout_DDEF("Response Surface Mapping: $OutName")
    layout[:scene] = attr(xaxis=attr(title=Lbls[1]), yaxis=attr(title=Lbls[2]), zaxis=attr(title=OutName),
        camera=attr(eye=attr(x=1.65, y=1.65, z=0.9)), aspectmode="cube")
    layout[:margin] = attr(l=5, r=5, t=65, b=100)

    return Plot(trace, layout)
end

# ------------------------------------------------------------------------------
# SECTION 12: 2D CONTOUR PROJECTION RENDERER 
# ------------------------------------------------------------------------------

"""
    ARTS_RenderContour_DDEF(Model, X_Train, Idx, Lbls, OutName) -> Plot
Convenience dispatch wrapper for the Contour Draw pipeline.
"""
function ARTS_RenderContour_DDEF(Model::AbstractDict, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString)
    return ARTS_Draw_DDEF(ARTS_PlotContour_DDES(), Model, X, Idx, Lbls, OutName)
end

function ARTS_Draw_DDEF(::ARTS_PlotContour_DDES, Model::AbstractDict, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString)
    ix, iy = Idx[1], Idx[2]
    N = ARTS_GetDynamicN_DDEF()
    x1, x2, Grid = ARTS_BuildGrid_DDEF(X, ix, iy, N)
    Z = reshape(ARTS_Predict_DDEF(Model, Grid), N, N)'

    if length(Z) > ARTS_MaxGridPoints_DDEC
        target_N = Int(sqrt(ARTS_MaxGridPoints_DDEC))
        Z = ARTS_Downsample_DDEF(Z, target_N, target_N)
        x1 = range(first(x1), last(x1), length=size(Z, 2))
        x2 = range(first(x2), last(x2), length=size(Z, 1))
    end
    
    # Apply Smoothing (Anti-aliasing) for heatmap clarity
    Z = ARTS_SmoothMatrix_DDEF(Z, 2)

    trace = contour(; x=collect(x1), y=collect(x2), z=Z, colorscale=ARTS_ViridisScale_DDEC,
        contours=attr(coloring="heatmap", showlabels=true, labelfont=attr(size=ARTS_SizeTick_DDEC)),
        colorbar=attr(orientation="h", x=0.5, xanchor="center", y=-0.24, yanchor="top", thickness=15, len=0.6, tickfont=attr(size=ARTS_SizeColourbar_DDEC)))

    layout = ARTS_BaseLayout_DDEF("Contour Projection Index: $OutName")
    layout[:xaxis][:title], layout[:yaxis][:title] = Lbls[1], Lbls[2]
    
    return Plot(trace, layout)
end

# ==============================================================================
# PART D: SOLUTION SPACE MAPPING & OPTIMISATION
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 13: INTERACTION SLICE ANALYSER
# ------------------------------------------------------------------------------

"""
    ARTS_RenderSlice_DDEF(Model, X, Idx, Lbls, OutName) -> Plot
Convenience dispatch wrapper for the Interaction Slice Draw pipeline.
"""
function ARTS_RenderSlice_DDEF(Model::AbstractDict, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString)
    return ARTS_Draw_DDEF(ARTS_PlotSlice_DDES(), Model, X, Idx, Lbls, OutName)
end

function ARTS_Draw_DDEF(::ARTS_PlotSlice_DDES, Model::AbstractDict, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString)
    ix, iy = Idx[1], Idx[2]
    N = ARTS_GetDynamicN_DDEF()

    x1 = collect(range(minimum(view(X, :, ix)), maximum(view(X, :, ix)); length=N))
    y_vals = (minimum(view(X, :, iy)), mean(view(X, :, iy)), maximum(view(X, :, iy)))
    y_names, styles = ("Min", "Mean", "Max"), ("solid", "dash", "solid")
    colours = (ARTS_Theme_DDEC.SHAMAG, ARTS_Theme_DDEC.TONCYA, ARTS_Theme_DDEC.HUEYEL)

    col_means = vec(mean(X; dims=1))
    traces = GenericTrace[]

    for i in eachindex(y_vals)
        Grid = repeat(col_means', length(x1))
        Grid[:, ix] .= x1
        Grid[:, iy] .= y_vals[i]

        z = ARTS_Predict_DDEF(Model, Grid)
        push!(traces, scatter(; x=x1, y=z, mode="lines", name="$(Lbls[2]) = $(y_names[i])",
            line=attr(color=colours[i], dash=styles[i], width=ARTS_WidthLine_DDEC)))
    end

    layout = ARTS_BaseLayout_DDEF("Interaction Cross-Section: $OutName")
    layout[:xaxis][:title], layout[:yaxis][:title] = Lbls[1], OutName
    
    return Plot(traces, layout)
end

# ------------------------------------------------------------------------------
# SECTION 14: MAIN EFFECT TREND VISUALISER
# ------------------------------------------------------------------------------

"""
    ARTS_RenderTrend_DDEF(Model, X, Y_Real, Idx, Lbls, OutName) -> Plot
Convenience dispatch wrapper for the Main Effect Trend Draw pipeline.
"""
function ARTS_RenderTrend_DDEF(Model::AbstractDict, X::AbstractMatrix{Float64}, Y_Real::AbstractVector{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString)
    return ARTS_Draw_DDEF(ARTS_PlotTrend_DDES(), Model, X, Y_Real, Idx, Lbls, OutName)
end

function ARTS_Draw_DDEF(::ARTS_PlotTrend_DDES, Model::AbstractDict, X::AbstractMatrix{Float64}, Y_Real::AbstractVector{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, OutName::AbstractString)
    ix = Idx[1]
    N = ARTS_GetDynamicN_DDEF()

    xr = collect(range(minimum(view(X, :, ix)), maximum(view(X, :, ix)); length = N))
    Grid = repeat(mean(X; dims=1), N)
    Grid[:, ix] .= xr

    y_trend = ARTS_Predict_DDEF(Model, Grid)

    t_line = scatter(; x=xr, y=y_trend, mode="lines", name="Model Estimator",
        line=attr(color=ARTS_Theme_DDEC.DARHIG, dash="dash", width=ARTS_WidthLine_DDEC))

    t_data = scatter(; x=X[:, ix], y=Y_Real, mode="markers", name="Experimental Obs.",
        marker=attr(color=ARTS_Theme_DDEC.TONGRE, size=ARTS_SizeMarker_DDEC, line=attr(width=0.5, color=ARTS_Theme_DDEC.PURBLA)))

    layout = ARTS_BaseLayout_DDEF("Main Effect Trend: $(Lbls[1])")
    layout[:xaxis][:title], layout[:yaxis][:title] = Lbls[1], OutName
    
    return Plot([t_line, t_data], layout)
end

# ------------------------------------------------------------------------------
# SECTION 15: DESIRABILITY SPACE EXPLORER
# ------------------------------------------------------------------------------

"""
    ARTS_RenderSpace_DDEF(Models, Goals, X, Idx, Lbls, [Best_Point]) -> Plot
Visualises the multi-objective desirability space.
"""
function ARTS_RenderSpace_DDEF(Models, Goals, X::AbstractMatrix{Float64}, Idx::AbstractVector{<:Integer}, Lbls::AbstractVector{<:AbstractString}, Leaders_DF::AbstractDataFrame=DataFrame())
    return ARTS_Draw_DDEF(ARTS_PlotDesignSpace_DDES(), Models, Goals, X, Idx, Lbls, Leaders_DF)
end

"""
    ARTS_RenderCandidates_DDEF(Models, Goals, X, Idx, Lbls, [Best_Point]) -> (Plot, PctString)
Visualises the top quartile of the desirability space (Optimal Solution Space).
"""
function ARTS_RenderCandidates_DDEF(Models, Goals, X::AbstractMatrix{Float64}, Idx::Union{AbstractVector{<:Integer}, Tuple{Integer, Integer}}, Lbls::AbstractVector{<:AbstractString}, Leaders_DF::AbstractDataFrame=DataFrame())
    return ARTS_Draw_DDEF(ARTS_PlotCandidates_DDES(), Models, Goals, X, Idx, Lbls, Leaders_DF)
end

# Internal Implementation Redirect for Space/Candidates
function ARTS_Draw_DDEF(::ARTS_PlotDesignSpace_DDES, Models, Goals, X, Idx, Lbls, Leaders_DF)
    p, _ = ARTS_RenderSpaceCore_DDEF(Models, Goals, X, Idx, Lbls, Leaders_DF, false)
    return p
end

function ARTS_Draw_DDEF(::ARTS_PlotCandidates_DDES, Models, Goals, X, Idx, Lbls, Leaders_DF)
    return ARTS_RenderSpaceCore_DDEF(Models, Goals, X, Idx, Lbls, Leaders_DF, true)
end

function ARTS_AddLeaderMarkers_DDEF!(traces::Vector{GenericTrace}, Leaders_DF::AbstractDataFrame, ix::Int, iy::Int, iz::Int)
    nrow(Leaders_DF) == 0 && return
    C, th = Main.Sys_Fast.FAST_Data_DDEC, ARTS_Theme_DDEC
    in_cols = filter(n -> startswith(uppercase(string(n)), uppercase(C.PRE_INPUT)), names(Leaders_DF))
    for r in 1:nrow(Leaders_DF)
        id = hasproperty(Leaders_DF, :ID) ? string(Leaders_DF[r, :ID]) : "L$r"
        is_top = occursin("TOP", uppercase(id))
        marker_col = is_top ? th.HUERED : th.PURBLA
        
        push!(traces, scatter3d(; x=[Leaders_DF[r, Symbol(in_cols[ix])]], y=[Leaders_DF[r, Symbol(in_cols[iy])]], 
            z=[iz > 0 ? Leaders_DF[r, Symbol(in_cols[iz])] : 0.0], mode="markers",
            marker=attr(size=ARTS_SizeLeader_DDEC, color=marker_col, symbol="diamond", line=attr(color=th.PURBLA, width=1)),
            showlegend=false, name="Leader $id"))
    end
end

function ARTS_RenderSpaceCore_DDEF(Models, Goals, X::AbstractMatrix{Float64}, Idx::Union{AbstractVector{<:Integer}, Tuple{Integer, Integer}}, Lbls::AbstractVector{<:AbstractString}, Leaders_DF::AbstractDataFrame, is_candidate::Bool)
    ix, iy = Idx[1], Idx[2]
    N = ARTS_GetDynamicN_DDEF()
    iz = first(setdiff(1:3, Idx))
    
    x1, x2 = range(minimum(view(X,:,ix)), maximum(view(X,:,ix)), length=N), range(minimum(view(X,:,iy)), maximum(view(X,:,iy)), length=N)
    col_ref = vec(mean(X; dims=1))
    z_vals = [minimum(view(X,:,iz)), col_ref[iz], maximum(view(X,:,iz))]

    traces, all_scores = GenericTrace[], Vector{AbstractMatrix{Float64}}(undef, 3)
    parsed_goals = [Main.Lib_Core.CORE_ExtractGoal_DDEF(get(Models[m], "Goal", Goals[m])) for m in eachindex(Models)]
    base_goals   = [(g[1], g[2], g[3], g[4], 1.0) for g in parsed_goals]
    k_models     = length(Models)
    inv_k        = k_models > 0 ? (1.0 / k_models) : 1.0
    neighbour_weights = [Main.Lib_Core.CORE_GetNeighbourWeights_DDEF(g[5]) for g in parsed_goals]

    # Allocated once, reused for all 3 slices
    Grid_buf   = repeat(reshape(col_ref, 1, :), N * N)
    Xd_buf     = Matrix{Float64}(undef, N * N, 10)
    Prod_u     = Vector{Float64}(undef, N * N)
    Prod_e     = Vector{Float64}(undef, N * N)
    Scores_buf = Vector{Float64}(undef, N * N)

    for (s, zv) in enumerate(z_vals)
        @inbounds for (k_idx, pt) in enumerate(Iterators.product(x1, x2))
            Grid_buf[k_idx, ix], Grid_buf[k_idx, iy], Grid_buf[k_idx, iz] = pt[1], pt[2], zv
        end

        fill!(Prod_u, 1.0)
        fill!(Prod_e, 1.0)

        for (m, model) in enumerate(Models)
            preds = ARTS_Predict_DDEF(model, Grid_buf, Xd_buf)
            bg = base_goals[m]
            w_m, w_c, w_p = neighbour_weights[m]
            
            @inbounds for i in 1:(N * N)
                val = preds[i]
                if isnan(val) || isinf(val)
                    Prod_u[i] = 0.0
                    Prod_e[i] = 0.0
                    continue
                end

                b = Main.Lib_Core.CORE_CalcDesirability_DDEF(val, bg)
                if b <= 1e-12
                    Prod_u[i] = 0.0
                    Prod_e[i] = 0.0
                else
                    u = b^(w_c * inv_k)
                    e = (b^(w_m * inv_k) + u + b^(w_p * inv_k)) / 3.0
                    Prod_u[i] *= u
                    Prod_e[i] *= e
                end
            end
        end

        @inbounds for i in 1:(N * N)
            sc = 0.50 * Prod_u[i] + 0.50 * Prod_e[i]
            Scores_buf[i] = (isnan(sc) || isinf(sc)) ? 0.0 : clamp(sc, 0.0, 1.0)
        end
        all_scores[s] = reshape(Scores_buf, N, N)'
    end

    all_flat = vcat([vec(s) for s in all_scores]...)
    valid_sc = filter(v -> v > 1e-6, all_flat)
    thresh = isempty(valid_sc) ? 1.0 : quantile(valid_sc, 0.75)
    pct_str = @sprintf("%.2f", (length(valid_sc) * 0.25 / (3*N*N)) * 100.0)

    for (s, zv) in enumerate(z_vals)
        Masked = is_candidate ? ARTS_SmoothMatrix_DDEF(all_scores[s], 2) : all_scores[s]
        alpha = (s == 2) ? (is_candidate ? 0.85 : 0.70) : (is_candidate ? 0.35 : 0.20)
        
        push!(traces, surface(; x=collect(x1), y=collect(x2), z=fill(zv, N, N), surfacecolor=Masked,
            colorscale = is_candidate ? ARTS_GenerateAlphaViridis_DDEF(thresh) : ARTS_ViridisScale_DDEC,
            cmin=0.0, cmax=1.0, opacity=alpha, showscale=(s==1), showlegend=false,
            contours=attr(z=attr(show=true, usecolormap=true, width=3))))
    end

    ARTS_AddLeaderMarkers_DDEF!(traces, Leaders_DF, ix, iy, iz)
    title = is_candidate ? "Optimal Candidates ($pct_str%)" : "Decision Space Exploration"
    layout = ARTS_BaseLayout_DDEF(title)
    layout[:scene] = attr(xaxis=attr(title=Lbls[1]), yaxis=attr(title=Lbls[2]), zaxis=attr(title=Lbls[3]), aspectmode="cube")
    return Plot(traces, layout), pct_str
end

# ------------------------------------------------------------------------------
# SECTION 16: 3D OPTIMAL ZONE VOLUME RENDERER
# ------------------------------------------------------------------------------

"""
    ARTS_RenderOptimalZone_DDEF(Models, Goals, X, InNames, [Leaders_DF]) -> (Plot, PctString)
Convenience dispatch wrapper for the Optimal Zone Draw pipeline.
"""
function ARTS_RenderOptimalZone_DDEF(Models, Goals, X::AbstractMatrix{Float64}, InNames::AbstractVector{<:AbstractString}, Leaders_DF::AbstractDataFrame=DataFrame())
    return ARTS_Draw_DDEF(ARTS_PlotOptimalZone_DDES(), Models, Goals, X, InNames, Leaders_DF)
end

function ARTS_Draw_DDEF(::ARTS_PlotOptimalZone_DDES, Models, Goals, X::AbstractMatrix{Float64}, InNames::AbstractVector{<:AbstractString}, Leaders_DF::AbstractDataFrame)
    N = 41 
    ranges = [range(minimum(view(X, :, i)), maximum(view(X, :, i)); length=N) for i in 1:3]
    Grid = Matrix{Float64}(undef, N^3, 3)
    idx = 1
    for (x, y, z) in Iterators.product(ranges...)
        Grid[idx, 1], Grid[idx, 2], Grid[idx, 3] = x, y, z
        idx += 1
    end

    parsed_goals = [Main.Lib_Core.CORE_ExtractGoal_DDEF(get(Models[m], "Goal", Goals[m])) for m in eachindex(Models)]
    base_goals   = [(g[1], g[2], g[3], g[4], 1.0) for g in parsed_goals]
    k_models     = length(Models)
    inv_k        = k_models > 0 ? (1.0 / k_models) : 1.0
    neighbour_weights = [Main.Lib_Core.CORE_GetNeighbourWeights_DDEF(g[5]) for g in parsed_goals]

    Prod_u = ones(N^3)
    Prod_e = ones(N^3)
    Scores = Vector{Float64}(undef, N^3)

    for (m, model) in enumerate(Models)
        preds = ARTS_Predict_DDEF(model, Grid)
        bg = base_goals[m]
        w_m, w_c, w_p = neighbour_weights[m]

        @inbounds for i in 1:(N^3)
            val = preds[i]
            if isnan(val) || isinf(val)
                Prod_u[i] = 0.0
                Prod_e[i] = 0.0
                continue
            end

            b = Main.Lib_Core.CORE_CalcDesirability_DDEF(val, bg)
            if b <= 1e-12
                Prod_u[i] = 0.0
                Prod_e[i] = 0.0
            else
                u = b^(w_c * inv_k)
                e = (b^(w_m * inv_k) + u + b^(w_p * inv_k)) / 3.0
                Prod_u[i] *= u
                Prod_e[i] *= e
            end
        end
    end

    @inbounds for i in 1:(N^3)
        sc = 0.50 * Prod_u[i] + 0.50 * Prod_e[i]
        Scores[i] = (isnan(sc) || isinf(sc)) ? 0.0 : clamp(sc, 0.0, 1.0)
    end
    valid_sc = filter(s -> !isnan(s) && s > 1e-6, Scores)
    thresh = isempty(valid_sc) ? 0.9 : quantile(valid_sc, 0.90)
    pct_str = @sprintf("%.2f", (count(s -> s >= thresh, Scores) / length(Scores)) * 100.0)

    trace = volume(; x=Grid[:, 1], y=Grid[:, 2], z=Grid[:, 3], value=Scores, isomin=thresh, isomax=1.0, 
        opacity=0.3, surface_count=5, colorscale=ARTS_ViridisScale_DDEC, cmin=0.0, cmax=1.0)

    layout = ARTS_BaseLayout_DDEF("Optimal Volumetric Zone ($pct_str%)")
    layout[:scene] = attr(xaxis=attr(title=InNames[1]), yaxis=attr(title=InNames[2]), zaxis=attr(title=InNames[3]), aspectmode="cube")
    
    traces = GenericTrace[trace]
    ARTS_AddLeaderMarkers_DDEF!(traces, Leaders_DF, 1, 2, 3)

    return Plot(traces, layout), pct_str
end

# ------------------------------------------------------------------------------
# SECTION 17: INTERACTION LANDSCAPE HEATMAP
# ------------------------------------------------------------------------------

"""
    ARTS_RenderInteractionMatrix_DDEF(Model, InNames, OutName) -> Plot
Convenience dispatch wrapper for the Interaction Matrix Draw pipeline.
"""
function ARTS_RenderInteractionMatrix_DDEF(Model::AbstractDict, InNames::AbstractVector{<:AbstractString}, OutName::AbstractString)
    return ARTS_Draw_DDEF(ARTS_PlotInteractionMatrix_DDES(), Model, InNames, OutName)
end

function ARTS_Draw_DDEF(::ARTS_PlotInteractionMatrix_DDES, Model::AbstractDict, InNames::AbstractVector{<:AbstractString}, OutName::AbstractString)
    # Use Multiple Dispatch to resolve matrix calculation based on model type
    m_type::Main.Lib_Core.CORE_AbstractModelType_DDET = Main.Lib_Core.CORE_GetModelType_DDEF(string(get(Model, "ModelType", "quadratic")))
    coefs = get(Model, "Coefs", Float64[])
    
    M = ARTS_GetInteractionMatrix_DDEF(m_type, coefs)

    max_abs = max(1e-9, maximum(abs.(M)))
    M_norm = M ./ max_abs

    trace = heatmap(; z=M_norm, x=InNames, y=InNames, zmid=0,
        colorscale=[[0, ARTS_Theme_DDEC.SHAMAG], [0.5, ARTS_Theme_DDEC.PURWHI], [1, ARTS_Theme_DDEC.HUEYEL]], 
        colorbar=attr(
            title="Relative Impact",
            orientation="h", x=0.5, xanchor="center", y=-0.28, yanchor="top", 
            thickness=12, len=0.7, tickfont=attr(size=ARTS_SizeColourbar_DDEC)
        ),
        hovertemplate="Factor A: %{x}<br>Factor B: %{y}<br>Impact: %{z:.3f}<extra></extra>")
    
    layout = ARTS_BaseLayout_DDEF("Interaction Landscape Index: $OutName")
    layout[:margin] = attr(l=80, r=40, t=65, b=120)
    
    return Plot(trace, layout)
end

# Internal Multiple Dispatch Gateways for Interaction Landscapes
function ARTS_GetInteractionMatrix_DDEF(::Main.Lib_Core.CORE_ModelQuadratic_DDES, B::AbstractVector)::Matrix{Float64}
    M = zeros(3, 3)
    # Map Standard Quadratic: 1(Int), 2,3,4(Lin), 5,6,7(Inter), 8,9,10(Quad)
    if length(B) >= 10
        M[1,1], M[2,2], M[3,3] = B[8], B[9], B[10]
        M[1,2] = M[2,1] = B[5]; M[1,3] = M[3,1] = B[6]; M[2,3] = M[3,2] = B[7]
    end
    return M
end

ARTS_GetInteractionMatrix_DDEF(::Main.Lib_Core.CORE_ModelLinear_DDES, B::AbstractVector) = zeros(3, 3)

# ------------------------------------------------------------------------------
# SECTION 18: DIAGNOSTIC PLOTS
# ------------------------------------------------------------------------------

"""
    ARTS_RenderQQPlot_DDEF(Residuals::AbstractVector{Float64}, OutName::AbstractString) -> Plot

Render a Quantile-Quantile (Q-Q) normal probability diagnostic plot for regression residuals.
Compares standardised residuals against theoretical standard normal quantiles to evaluate normality.

# Arguments
- `Residuals`: Vector of model residuals (observed minus predicted).
- `OutName`: Name of the response variable for plot titling.

# Returns
- A `PlotlyJS.Plot` object formatted with academic styling.
"""
function ARTS_RenderQQPlot_DDEF(Residuals::AbstractVector{Float64}, OutName::AbstractString)
    return ARTS_Draw_DDEF(ARTS_PlotQQ_DDES(), Residuals, OutName)
end

function ARTS_Draw_DDEF(::ARTS_PlotQQ_DDES, Residuals::AbstractVector{Float64}, OutName::AbstractString)
    n = length(Residuals)
    z_res = (sort(Residuals) .- mean(Residuals)) ./ std(Residuals)
    theoretical = quantile.(Normal(0, 1), [(i - 0.5) / n for i in 1:n])

    t_pts = scatter(; x=theoretical, y=z_res, mode="markers", name="Residuals",
        marker=attr(color=ARTS_Theme_DDEC.SHAMAG, size=ARTS_SizeMarker_DDEC, opacity=0.7, line=attr(width=1, color=ARTS_Theme_DDEC.PURBLA)))
    
    lims = [minimum([theoretical; z_res]), maximum([theoretical; z_res])]
    t_line = scatter(; x=lims, y=lims, mode="lines", name="Normal Distribution",
        line=attr(color=ARTS_Theme_DDEC.HUEYEL, width=ARTS_WidthLine_DDEC, dash="dash"))

    layout = ARTS_BaseLayout_DDEF("Normal Probability (Q-Q): $OutName")
    layout[:xaxis][:title], layout[:yaxis][:title] = "Theoretical Quantiles", "Standardised Residuals"
    return Plot([t_pts, t_line], layout)
end

"""
    ARTS_RenderResidualsVsPred_DDEF(Y_Pred::AbstractVector{Float64}, Residuals::AbstractVector{Float64}, OutName::AbstractString) -> Plot

Render a residuals versus predicted values diagnostic plot to assess variance homogeneity (homoscedasticity).

# Arguments
- `Y_Pred`: Vector of model predictions.
- `Residuals`: Vector of model residuals.
- `OutName`: Name of the response variable for plot titling.

# Returns
- A `PlotlyJS.Plot` object formatted with academic styling.
"""
function ARTS_RenderResidualsVsPred_DDEF(Y_Pred::AbstractVector{Float64}, Residuals::AbstractVector{Float64}, OutName::AbstractString)
    return ARTS_Draw_DDEF(ARTS_PlotResiduals_DDES(), Y_Pred, Residuals, OutName)
end

function ARTS_Draw_DDEF(::ARTS_PlotResiduals_DDES, Y_Pred::AbstractVector{Float64}, Residuals::AbstractVector{Float64}, OutName::AbstractString)
    t_pts = scatter(; x=Y_Pred, y=Residuals, mode="markers", name="Residuals",
        marker=attr(color=ARTS_Theme_DDEC.SHAMAG, size=ARTS_SizeMarker_DDEC, opacity=0.7, line=attr(width=1, color=ARTS_Theme_DDEC.PURWHI)))

    t_zero = scatter(; x=[minimum(Y_Pred), maximum(Y_Pred)], y=[0, 0], mode="lines", showlegend=false,
        line=attr(color=ARTS_Theme_DDEC.HUEYEL, width=ARTS_WidthLine_DDEC, dash="solid"))

    layout = ARTS_BaseLayout_DDEF("Variance Homogeneity: $OutName")
    layout[:xaxis][:title], layout[:yaxis][:title] = "Predicted Estimation", "Residual Error"
    return Plot([t_pts, t_zero], layout)
end

"""
    ARTS_RenderSensitivityPlot_DDEF(Sens::AbstractVector{Float64}, InNames::AbstractVector{<:AbstractString}, OutName::AbstractString) -> Plot

Render a bar chart illustrating percentage contributions of experimental factors based on local sensitivity analysis.

# Arguments
- `Sens`: Vector of fractional sensitivities summing to 1.0.
- `InNames`: Vector of factor names.
- `OutName`: Name of the response variable for plot titling.

# Returns
- A `PlotlyJS.Plot` object formatted with academic styling.
"""
function ARTS_RenderSensitivityPlot_DDEF(Sens::AbstractVector{Float64}, InNames::AbstractVector{<:AbstractString}, OutName::AbstractString)
    return ARTS_Draw_DDEF(ARTS_PlotSensitivity_DDES(), Sens, InNames, OutName)
end

function ARTS_Draw_DDEF(::ARTS_PlotSensitivity_DDES, Sens::AbstractVector{Float64}, InNames::AbstractVector{<:AbstractString}, OutName::AbstractString)
    trace = bar(; x=InNames, y=Sens .* 100.0, text=[@sprintf("%.1f%%", s * 100) for s in Sens], textposition="auto",
        marker=attr(color=[ARTS_Theme_DDEC.SHAMAG, ARTS_Theme_DDEC.TONGRE, ARTS_Theme_DDEC.HUEYEL], line=attr(width=1.5, color=ARTS_Theme_DDEC.PURWHI)))

    layout = ARTS_BaseLayout_DDEF("Local Sensitivity Impact: $OutName")
    layout[:yaxis][:title], layout[:xaxis][:title] = "Contribution (%)", "Experimental Factor"
    return Plot(trace, layout)
end

# ==============================================================================
# PART E: SYSTEM DISPATCH & ORCHESTRATION
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 19: PARALLEL VISUAL DISPATCH ORCHESTRATOR
# ------------------------------------------------------------------------------

"""
    ARTS_Render_DDEF(Models, X, Y, InNames, OutNames, Goals, R2s, Q2s, Opts, Leaders_DF, Sens, Residuals) -> Vector{Dict}
"""
function ARTS_Render_DDEF(Models, X, Y, InNames, OutNames, Goals, R2s, Q2s, Opts,
    Leaders_DF::AbstractDataFrame=DataFrame(), Sens::AbstractVector=Vector{Vector{Float64}}[], Residuals::AbstractVector=Vector{Vector{Float64}}[])

    graphs, graphs_lock = Dict{String,Any}[], ReentrantLock()
    # Cleaner Error Reporting to prevent REPL overflows
    ARTS_SafeErrorLog_DDEF(tag, msg, e) = Main.Sys_Fast.FAST_Log_DDEF("ARTS", tag, "$msg: $(typeof(e)) -> $(sprint(showerror, e))", "WARN")
    Main.Sys_Fast.FAST_Log_DDEF("ARTS", "RENDER_INIT", "Parallel Visual Dispatch Initiated...", "WAIT")

    # Defensive conversion of JSON-deserialised or generic inputs
    X_f64 = ARTS_PrepareMatrix_DDEF(X)
    Y_f64 = ARTS_PrepareMatrix_DDEF(Y)
    InNames_str = ARTS_PrepareStringVector_DDEF(InNames)
    OutNames_str = ARTS_PrepareStringVector_DDEF(OutNames)
    R2s_f64 = ARTS_PrepareFloatVector_DDEF(R2s)
    Q2s_f64 = ARTS_PrepareFloatVector_DDEF(Q2s)
    Sens_f64 = ARTS_PrepareNestedVector_DDEF(Sens)
    Residuals_f64 = ARTS_PrepareNestedVector_DDEF(Residuals)

    Combos = ARTS_FactorPairs_DDEC
    tasks  = Task[]

    # ------------------------------------------------------------------------------
    # STAGED RENDERING ORCHESTRATOR (1-13 Scientific Order)
    # ------------------------------------------------------------------------------
    # Implementation of staged delivery to reduce initial feedback latency. 
    # Support for :Full, :Priority (1-5), :Deferred (6-13)
    Mode = get(Opts, "Mode", :Full) 
    
    # --- STAGE 1: PRIORITY GROUPS (1: Pareto, 2: Fit) ---
    if Mode == :Full || Mode == :Priority
        for m in eachindex(OutNames_str)
            Models[m]["Status"] != "OK" && continue
            name   = OutNames_str[m]
            y_pred = ARTS_Predict_DDEF(Models[m], X_f64)

            # [1] Pareto (QA)
            t1 = Threads.@spawn try
                p = ARTS_Draw_DDEF(ARTS_PlotPareto_DDES(), Models[m], name, R2s_f64[m], Q2s_f64[m])
                lock(graphs_lock) do
                    push!(graphs, Dict("Type"=>"Pareto", "Title"=>"Pareto: $name", "Plot"=>p, "OutputIdx"=>m, "SubIdx"=>0))
                end
            catch e; ARTS_SafeErrorLog_DDEF("ERR_P1_PARETO", "Pareto failed", e); end
            push!(tasks, t1)

            # [2] Fit Audit (QA)
            t2 = Threads.@spawn try
                p = ARTS_Draw_DDEF(ARTS_PlotFit_DDES(), Y_f64[:, m], y_pred, name)
                lock(graphs_lock) do
                    push!(graphs, Dict("Type"=>"Fit", "Title"=>"Fit Audit: $name", "Plot"=>p, "OutputIdx"=>m, "SubIdx"=>0))
                end
            catch e; ARTS_SafeErrorLog_DDEF("ERR_P2_FITAUDIT", "Fit failed", e); end
            push!(tasks, t2)
        end
        wait.(tasks)
        empty!(tasks)
        Main.Sys_Fast.FAST_Log_DDEF("ARTS", "RENDER_POLL", "Packet 1 of 2 (Priority) completed.", "OK")
    end

    # --- STAGE 2: DEFERRED GROUPS (3-13: RESP, SURFACE, DIAG, SPACE) ---
    if Mode == :Full || Mode == :Deferred
        for m in eachindex(OutNames_str)
            Models[m]["Status"] != "OK" && continue
            name   = OutNames_str[m]
            y_pred = ARTS_Predict_DDEF(Models[m], X_f64)

            # [3] Response Trends (RESP)
            for v in 1:3
                tv = Threads.@spawn try
                    p = ARTS_Draw_DDEF(ARTS_PlotTrend_DDES(), Models[m], X_f64, Y_f64[:, m], [v], [InNames_str[v]], name)
                    lock(graphs_lock) do
                        push!(graphs, Dict("Type"=>"Trend", "Title"=>"Trend: $name ($(InNames_str[v]))", "Plot"=>p, "OutputIdx"=>m, "SubIdx"=>v))
                    end
                catch e; ARTS_SafeErrorLog_DDEF("ERR_P3_TREND", "Trend failed", e); end
                push!(tasks, tv)
            end

            # [4] Interaction Slices (RESP)
            for (ix, c) in enumerate(Combos)
                ts = Threads.@spawn try
                    lbls_12 = [InNames_str[c[1]], InNames_str[c[2]]]
                    lbls_21 = [InNames_str[c[2]], InNames_str[c[1]]]
                    p1 = ARTS_Draw_DDEF(ARTS_PlotSlice_DDES(), Models[m], X_f64, [c[1], c[2]], lbls_12, name)
                    p2 = ARTS_Draw_DDEF(ARTS_PlotSlice_DDES(), Models[m], X_f64, [c[2], c[1]], lbls_21, name)
                    lock(graphs_lock) do
                        push!(graphs, Dict("Type"=>"Slice", "Title"=>"Interact: $name ($(lbls_12[1]) by $(lbls_12[2]))", "Plot"=>p1, "OutputIdx"=>m, "SubIdx"=>ix))
                        push!(graphs, Dict("Type"=>"Slice", "Title"=>"Interact: $name ($(lbls_21[1]) by $(lbls_21[2]))", "Plot"=>p2, "OutputIdx"=>m, "SubIdx"=>ix))
                    end
                catch e; ARTS_SafeErrorLog_DDEF("ERR_P4_SLICE", "Slice failed", e); end
                push!(tasks, ts)
            end

            # [5] Interaction Matrix (RESP)
            t5 = Threads.@spawn try
                p = ARTS_Draw_DDEF(ARTS_PlotInteractionMatrix_DDES(), Models[m], InNames_str, name)
                lock(graphs_lock) do
                    push!(graphs, Dict("Type"=>"IntMatrix", "Title"=>"Landscape: $name", "Plot"=>p, "OutputIdx"=>m, "SubIdx"=>0))
                end
            catch e; ARTS_SafeErrorLog_DDEF("ERR_P5_IMATRIX", "Landscape failed", e); end
            push!(tasks, t5)

            # [6 & 7] Surface & Contour (SURFACE)
            for (ix, c) in enumerate(Combos)
                tsury = Threads.@spawn try
                    lbls = [InNames_str[c[1]], InNames_str[c[2]]]
                    p1 = ARTS_Draw_DDEF(ARTS_PlotSurface_DDES(), Models[m], X_f64, [c[1], c[2]], lbls, name)
                    p2 = ARTS_Draw_DDEF(ARTS_PlotContour_DDES(), Models[m], X_f64, [c[1], c[2]], lbls, name)
                    lock(graphs_lock) do
                        push!(graphs, Dict("Type"=>"Surface", "Title"=>"RSM: $name ($(lbls[1])-$(lbls[2]))", "Plot"=>p1, "OutputIdx"=>m, "SubIdx"=>ix))
                        push!(graphs, Dict("Type"=>"Contour", "Title"=>"Contour: $name ($(lbls[1])-$(lbls[2]))", "Plot"=>p2, "OutputIdx"=>m, "SubIdx"=>ix))
                    end
                catch e; ARTS_SafeErrorLog_DDEF("ERR_P67_SURF", "Surface/Contour failed", e); end
                push!(tasks, tsury)
            end

            # [8, 9, 10] Diagnostics (QQ, Residuals, Sensitivity)
            t_diag = Threads.@spawn try
                if m <= length(Residuals_f64) && !isempty(Residuals_f64[m])
                    p_qq = ARTS_Draw_DDEF(ARTS_PlotQQ_DDES(), Residuals_f64[m], name)
                    p_res = ARTS_Draw_DDEF(ARTS_PlotResiduals_DDES(), y_pred, Residuals_f64[m], name)
                    lock(graphs_lock) do
                        push!(graphs, Dict("Type"=>"QQ", "Title"=>"Q-Q: $name", "Plot"=>p_qq, "OutputIdx"=>m, "SubIdx"=>0))
                        push!(graphs, Dict("Type"=>"Residuals", "Title"=>"Errors: $name", "Plot"=>p_res, "OutputIdx"=>m, "SubIdx"=>0))
                    end
                end
                if m <= length(Sens_f64) && !isempty(Sens_f64[m])
                    p_sens = ARTS_Draw_DDEF(ARTS_PlotSensitivity_DDES(), Sens_f64[m], InNames_str, name)
                    lock(graphs_lock) do
                        push!(graphs, Dict("Type"=>"Sensitivity", "Title"=>"Sensitivity: $name", "Plot"=>p_sens, "OutputIdx"=>m, "SubIdx"=>0))
                    end
                end
            catch e; ARTS_SafeErrorLog_DDEF("ERR_P810_DIAG", "Diagnostics failed", e); end
            push!(tasks, t_diag)
        end

        # [11, 12, 13] Design Space & Candidates & Optimal Zone (SPACE - Composite Viz)
        t_space = Threads.@spawn try
            # Critical Sanity Check: Ensure all constituent models are successfully trained.
            # Composite desirability maps require a complete model portfolio.
            if all(m -> get(m, "Status", "FAIL") == "OK", Models)
                if get(Opts, "DesignSpace", true) && !isempty(Combos)
                    for (ix, c) in enumerate(Combos)
                        lbls = [InNames_str[c[1]], InNames_str[c[2]], InNames_str[first(setdiff(1:3, c))]]
                        p_sp = ARTS_Draw_DDEF(ARTS_PlotDesignSpace_DDES(), Models, Goals, X_f64, [c[1], c[2]], lbls, Leaders_DF)
                        p_ca, _ = ARTS_Draw_DDEF(ARTS_PlotCandidates_DDES(), Models, Goals, X_f64, [c[1], c[2]], lbls, Leaders_DF)
                        lock(graphs_lock) do
                            push!(graphs, Dict("Type"=>"DesignSpace", "Title"=>"Space: $(lbls[1])-$(lbls[2])", "Plot"=>p_sp, "OutputIdx"=>length(OutNames_str)+1, "SubIdx"=>ix))
                            push!(graphs, Dict("Type"=>"Candidates", "Title"=>"Candidates: $(lbls[1])-$(lbls[2])", "Plot"=>p_ca, "OutputIdx"=>length(OutNames_str)+1, "SubIdx"=>ix))
                        end
                    end
                end
                if get(Opts, "OptimalZone", true)
                    p_gz, _ = ARTS_Draw_DDEF(ARTS_PlotOptimalZone_DDES(), Models, Goals, X_f64, InNames_str, Leaders_DF)
                    lock(graphs_lock) do
                        push!(graphs, Dict("Type"=>"OptimalZone", "Title"=>"Optimal Zone", "Plot"=>p_gz, "OutputIdx"=>length(OutNames_str)+1, "SubIdx"=>0))
                    end
                end
            else
                Main.Sys_Fast.FAST_Log_DDEF("ARTS", "RENDER_SKIP", "Composite visualisations bypassed due to training failure in one or more models.", "WARN")
            end
        catch e; ARTS_SafeErrorLog_DDEF("ERR_P1113_SPACE", "Space logic failed", e); end
        push!(tasks, t_space)

        wait.(tasks)
        Main.Sys_Fast.FAST_Log_DDEF("ARTS", "RENDER_POLL", "Packet 2 of 2 (Deferred) completed.", "OK")
    end

    # 6. Results Ordering Protocol (Scientific Workflow Architecture)
    # 1-2: QA | 3-5: RESP | 6-10: DIAG & SURFACE | 11-13: SPACE
    Priority = Dict(
        "Pareto"=>1, "Fit"=>2, "Trend"=>3, "Slice"=>4, "IntMatrix"=>5,
        "Surface"=>6, "Contour"=>7, "QQ"=>8, "Residuals"=>9, "Sensitivity"=>10,
        "DesignSpace"=>11, "Candidates"=>12, "OptimalZone"=>13
    )
    # Sort by Logic: Quality Assurance -> Response Analysis -> Surface Mapping -> Space Exploration
    sort!(graphs, by = x -> (get(Priority, x["Type"], 99), x["OutputIdx"], x["SubIdx"]))

    Main.Sys_Fast.FAST_Log_DDEF("ARTS", "RENDER_COMPLETE", "Portfolio of $(length(graphs)) units ready | Mode: $Mode", length(graphs) > 0 ? "OK" : "WARN")
    return graphs
end

end