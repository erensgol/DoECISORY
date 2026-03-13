module Lib_Arts

# ======================================================================================
# DAISHODOE - LIB ARTS (VISUALISATION & GRAPHICS MOTOR)
# ======================================================================================
# Purpose: Visualisation and graphics logic for DaishoDoE.
# Module Tag: ARTS
# ======================================================================================

using Base.Threads
using PlotlyJS
using Printf
using Statistics
using Combinatorics
using Distributions
using DataFrames
using Main.Sys_Fast

export ARTS_RenderPareto_DDEF, ARTS_RenderFit_DDEF, ARTS_RenderSurface_DDEF,
    ARTS_RenderContour_DDEF, ARTS_RenderSlice_DDEF, ARTS_RenderTrend_DDEF,
    ARTS_RenderSpace_DDEF, ARTS_RenderCandidates_DDEF, ARTS_Render_DDEF,
    ARTS_CalcDesirability_DDEF, ARTS_ExtractGoal_DDEF,
    ARTS_Downsample_DDEF, ARTS_RenderOptimalZone_DDEF, ARTS_RenderInteractionMatrix_DDEF,
    ARTS_BaseLayout_DDEF, ARTS_Predict_DDEF, ARTS_BuildGrid_DDEF,
    ARTS_AdaptiveGridN_DDEF, ARTS_RenderSpaceImpl_DDEF

# --------------------------------------------------------------------------------------
# --- INTERFACE LAYOUT & THEME ---
# --------------------------------------------------------------------------------------

# Theme as a module-level const for zero-alloc access
# Theme linked to Sys_Fast constants for single-source-of-truth
const ARTS_Theme_DDEC = let C = Sys_Fast.FAST_Data_DDEC
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

# High-fidelity Viridis colour mapping for surfaces and heatmaps
const ARTS_ViridisScale_DDEC = let C = Sys_Fast.FAST_Data_DDEC
    [
        [0.00, C.COLOUR_SHAMAG],
        [0.25, C.COLOUR_SHABLU],
        [0.50, C.COLOUR_TONCYA],
        [0.75, C.COLOUR_TONGRE],
        [1.00, C.COLOUR_HUEYEL]
    ]
end

# --- GRAPHICAL STANDARD SCALES ---

const ARTS_StandardHeight_DDEC = 500
const ARTS_SceneHeight_DDEC = 500

"""
    ARTS_BaseLayout_DDEF(title; [height]) -> Layout
Generates a standardised PlotlyJS layout with light theme support.
"""
function ARTS_BaseLayout_DDEF(title::String; height=ARTS_StandardHeight_DDEC)
    return Layout(;
        title=attr(
            text=title,
            font=attr(size=12, family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.PURBLA),
            x=0.02, 
            y=0.98
        ),
        paper_bgcolor=ARTS_Theme_DDEC.PURWHI,
        plot_bgcolor=ARTS_Theme_DDEC.PURWHI,
        font=attr(family=ARTS_Theme_DDEC.FONT, color=ARTS_Theme_DDEC.DARHIG, size=10),
        margin=attr(l=70, r=40, t=70, b=80),
        height=height,
        xaxis=attr(
            showline=true, 
            showgrid=true,
            gridcolor=ARTS_Theme_DDEC.LIGHIG, 
            gridwidth=1, 
            griddash="dash",
            zeroline=false, 
            linecolor=ARTS_Theme_DDEC.LIGHIG, 
            linewidth=1, 
            mirror=true, 
            ticks="outside"
        ),
        yaxis=attr(
            showline=true, 
            showgrid=true,
            gridcolor=ARTS_Theme_DDEC.LIGHIG, 
            gridwidth=1, 
            griddash="dash",
            zeroline=false, 
            linecolor=ARTS_Theme_DDEC.LIGHIG, 
            linewidth=1, 
            mirror=true, 
            ticks="outside"
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

# High-fidelity Viridis colour mapping for surfaces and heatmaps

# --- SMART DOWNSAMPLING & GRID LIMITER ---

# Maximum safe grid points for browser rendering (N×N per plot)
const ARTS_MaxGridPoints_DDEC = 40000   # 200×200 = 40,000 points per surface

"""
    ARTS_AdaptiveGridN_DDEF(preferred, [max_total]) -> Int
Returns a grid resolution N such that N×N ≤ max_total.
"""
function ARTS_AdaptiveGridN_DDEF(preferred::Int, max_total::Int=ARTS_MaxGridPoints_DDEC)
    N = preferred
    while N * N > max_total && N > 5
        N -= 1
    end
    return N
end

"""
    ARTS_Downsample_DDEF(Z, target_rows, target_cols) -> Matrix
Intelligent sub-sampling for oversized plot matrices using strided decimation.
"""
function ARTS_Downsample_DDEF(Z::Matrix{T}, target_rows::Int, target_cols::Int) where T
    nr, nc = size(Z)
    (nr ≤ target_rows && nc ≤ target_cols) && return Z

    row_stride = max(1, nr ÷ target_rows)
    col_stride = max(1, nc ÷ target_cols)

    row_idx = 1:row_stride:nr
    col_idx = 1:col_stride:nc

    # Preserve boundary behaviour
    row_idx = unique([collect(row_idx); nr])
    col_idx = unique([collect(col_idx); nc])

    Sys_Fast.FAST_Log_DDEF("ARTS", "DOWNSAMPLE",
        "Reduced $(nr)×$(nc) → $(length(row_idx))×$(length(col_idx))", "INFO")
    return Z[row_idx, col_idx]
end

"""
    ARTS_ExtractGoal_DDEF(Goal) -> Tuple
Extracts and normalises goal parameters from an objective dictionary.
"""
function ARTS_ExtractGoal_DDEF(Goal::AbstractDict)
    G_Min = Float64(get(Goal, "Min", -Inf))
    G_Max = Float64(get(Goal, "Max", Inf))
    # Safety: Handle cases where Min/Max are -Inf/Inf to avoid NaN Target
    G_Tgt_Raw = get(Goal, "Target", nothing)
    G_Tgt = if !isnothing(G_Tgt_Raw)
        Float64(G_Tgt_Raw)
    elseif isfinite(G_Min) && isfinite(G_Max)
        (G_Min + G_Max) / 2
    else
        0.0 # Default fallback
    end
    Type = string(get(Goal, "Type", "Nominal"))
    # Weight must be non-negative for mathematical stability
    Weight = max(0.0, Float64(get(Goal, "Weight", 1.0)))
    is_max = occursin("Maximise", Type)
    is_min = occursin("Minimise", Type)
    return (G_Min, G_Max, G_Tgt, is_max, is_min, Weight)
end

function ARTS_CalcDesirability_DDEF(Val::Float64, Goal::AbstractDict)
    return ARTS_CalcDesirability_DDEF(Val, ARTS_ExtractGoal_DDEF(Goal))
end

"""
    ARTS_CalcDesirability_DDEF(Val, GoalTup) -> Float64
Harrington's Desirability Function for multi-objective optimisation mapping.
"""
function ARTS_CalcDesirability_DDEF(Val::Float64, GoalTup::Tuple)
    G_Min, G_Max, G_Tgt, is_max, is_min, _ = GoalTup
    res = 0.0

    if is_max
        if Val >= G_Tgt
            res = 1.0
        elseif Val <= G_Min
            res = 0.0
        else
            denom = G_Tgt - G_Min
            res   = denom > 1e-9 ? (Val - G_Min) / denom : 1.0
        end
    elseif is_min
        if Val <= G_Tgt
            res = 1.0
        elseif Val >= G_Max
            res = 0.0
        else
            denom = G_Max - G_Tgt
            res   = denom > 1e-9 ? (G_Max - Val) / denom : 1.0
        end
    else # Nominal
        if Val <= G_Min || Val >= G_Max
            res = 0.0
        elseif abs(Val - G_Tgt) < 1e-12
            res = 1.0
        elseif Val < G_Tgt
            denom = G_Tgt - G_Min
            res   = denom > 1e-9 ? (Val - G_Min) / denom : 1.0
        else # Val > G_Tgt
            denom = G_Max - G_Tgt
            res   = denom > 1e-9 ? (G_Max - Val) / denom : 1.0
        end
    end

    # Scientific Safeguard: NaN or Inf should be 0.0, others clamped to [0, 1]
    return (isnan(res) || isinf(res)) ? 0.0 : clamp(res, 0.0, 1.0)
end
# --------------------------------------------------------------------------------------
# --- LINEAR PLOTS (PARETO, ACTUAL VS PRED) ---
# --------------------------------------------------------------------------------------

"""
    ARTS_RenderPareto_DDEF(Model, OutName, R2_Adj, Q2) -> Plot
Renders a horizontal bar chart showing standardised effects of factors.
"""
function ARTS_RenderPareto_DDEF(Model::Dict, OutName::String, R2_Adj::Float64, R2_Pred::Float64)
    Coefs = Model["Coefs"]
    Names = get(Model, "TermNames", ["T$i" for i in eachindex(Coefs)])
    t_Stats = get(Model, "t_Stats", Coefs) # Fallback to coefs if missing
    N_Samples = get(Model, "N_Samples", length(Coefs) + 5)

    # Exclude Intercept (Index 1)
    clean_eff = @view t_Stats[2:end]
    clean_nms = @view Names[2:end]
    clean_signs = any(isnan, clean_eff) ? sign.(@view Coefs[2:end]) : sign.(clean_eff)
    magnitudes = any(isnan, clean_eff) ? abs.(@view Coefs[2:end]) : abs.(clean_eff)

    perm = sortperm(magnitudes)
    sorted_mag = magnitudes[perm]
    sorted_nms = clean_nms[perm]
    sorted_sgn = clean_signs[perm]

    traces = GenericTrace[]

    # Negative Effects
    neg_idx = findall(x -> x < 0, sorted_sgn)
    if !isempty(neg_idx)
        push!(traces, bar(;
            x            = sorted_mag[neg_idx],
            y            = sorted_nms[neg_idx],
            orientation  = "h",
            name         = "Negative Effect",
            marker       = attr(color=ARTS_Theme_DDEC.SHAMAG, line=attr(width=0)),
            text         = [@sprintf("%.2f", m) for m in sorted_mag[neg_idx]],
            textposition = "auto"
        ))
    end

    # Positive Effects
    pos_idx = findall(x -> x >= 0, sorted_sgn)
    if !isempty(pos_idx)
        push!(traces, bar(;
            x            = sorted_mag[pos_idx],
            y            = sorted_nms[pos_idx],
            orientation  = "h",
            name         = "Positive Effect",
            marker       = attr(color=ARTS_Theme_DDEC.HUEYEL, line=attr(width=0)),
            text         = [@sprintf("%.2f", m) for m in sorted_mag[pos_idx]],
            textposition = "auto"
        ))
    end

    r2_str = isnan(R2_Adj)  ? "N/A" : @sprintf("%.3f", R2_Adj)
    q2_str = isnan(R2_Pred) ? "N/A" : @sprintf("%.3f", R2_Pred)

    layout = ARTS_BaseLayout_DDEF("Factor Importance: $OutName (R²Adj: $r2_str | Q²: $q2_str)")
    layout[:xaxis][:title] = "Magnitude of Standardised Effect (t-value)"
    layout[:barmode]       = "stack"
    layout[:showlegend]    = true
    layout[:legend]        = attr(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1)

    # Bonferroni Limit (t-critical for alpha = 0.05 / n_terms)
    df              = max(1, N_Samples - length(Coefs))
    alpha_corrected = 0.05 / length(clean_eff)
    t_crit          = quantile(TDist(df), 1.0 - alpha_corrected / 2)

    limit_shape = attr(
        type="line", 
        x0=t_crit, 
        x1=t_crit, 
        y0=0, 
        y1=1,
        yref="paper", 
        line=attr(color=ARTS_Theme_DDEC.HUERED, width=2, dash="dash")
    )
    layout[:shapes] = [limit_shape]

    return Plot(traces, layout)
end

"""
    ARTS_RenderFit_DDEF(Y_Real, Y_Pred, OutName) -> Plot
Compares experimental results with model predictions via scatter plot.
"""
function ARTS_RenderFit_DDEF(Y_Real::Vector{Float64}, Y_Pred::Vector{Float64}, OutName::String)
    mn     = min(minimum(Y_Real), minimum(Y_Pred))
    mx     = max(maximum(Y_Real), maximum(Y_Pred))
    margin = (mx - mn) * 0.05

    t_data = scatter(; 
        x      = Y_Real, 
        y      = Y_Pred, 
        mode   = "markers",
        marker = attr(size=8, color=ARTS_Theme_DDEC.TONGRE, line=attr(width=1, color=ARTS_Theme_DDEC.PURBLA)), 
        name   = "Data"
    )

    t_ideal = scatter(; 
        x    = [mn - margin, mx + margin], 
        y    = [mn - margin, mx + margin],
        mode = "lines", 
        line = attr(color=ARTS_Theme_DDEC.DARHIG, dash="dash", width=1), 
        name = "Ideal"
    )

    layout = ARTS_BaseLayout_DDEF("Prediction Accuracy: $OutName")
    layout[:xaxis][:title] = "Experimental (Recorded)"
    layout[:yaxis][:title] = "Predicted (Model)"
    layout[:showlegend]    = false
    
    return Plot([t_data, t_ideal], layout)
end

# --------------------------------------------------------------------------------------
# --- RSM VISUALISATION (SURFACE & CONTOUR) ---
# --------------------------------------------------------------------------------------

"""
    ARTS_Predict_DDEF(Model, X) -> Vector{Float64}
Internal evaluator for plotting grids (stateless design matrix expansion).
"""
function ARTS_Predict_DDEF(Model, X)
    ModelType = get(Model, "ModelType", "quadratic")

    Beta = Model["Coefs"]
    N    = size(X, 1)
    K    = 3 # Fixed 3-variable system
    if occursin("linear", ModelType)
        Xd = hcat(ones(N), X)
        return Xd * Beta
    else
        combos  = collect(combinations(1:K, 2))
        n_inter = length(combos)
        Xd      = Matrix{Float64}(undef, N, 1 + K + n_inter + K)
        fill!(view(Xd, :, 1), 1.0)
        copyto!(view(Xd, :, 2:K+1), X)

        # Vectorised expansion
        @inbounds for (i, (c1, c2)) in enumerate(combos)
            Xd[:, K+1+i] .= view(X, :, c1) .* view(X, :, c2)
        end
        @views @. Xd[:, K+n_inter+2:end] = abs2(X)
        return Xd * Beta
    end
end

"""
    ARTS_BuildGrid_DDEF(X, ix, iy, N_requested) -> (x1, x2, Grid)
Constructs a prediction grid for surface/contour plots centred on factor means.
"""
function ARTS_BuildGrid_DDEF(X::Matrix{Float64}, ix::Int, iy::Int, N_requested::Int)
    # Adaptive grid limiter
    N  = ARTS_AdaptiveGridN_DDEF(N_requested)
    x1 = range(minimum(view(X, :, ix)), maximum(view(X, :, ix)); length=N)
    x2 = range(minimum(view(X, :, iy)), maximum(view(X, :, iy)); length=N)

    Grid = repeat(mean(X; dims=1), N * N)
    @inbounds for (k, pt) in enumerate(Iterators.product(x1, x2))
        Grid[k, ix] = pt[1]
        Grid[k, iy] = pt[2]
    end
    return x1, x2, Grid
end

"""
    ARTS_RenderSurface_DDEF(Model, X_Train, Idx, Lbls, OutName) -> Plot
Renders a 3D Response Surface (RSM) for two selected variables.
"""
function ARTS_RenderSurface_DDEF(Model::Dict, X::Matrix{Float64}, Idx::Vector{Int},
    Lbls::Vector{String}, OutName::String)
    ix, iy = Idx[1], Idx[2]
    N_Grid = 100
    x1, x2, Grid = ARTS_BuildGrid_DDEF(X, ix, iy, N_Grid)

    Z = reshape(ARTS_Predict_DDEF(Model, Grid), N_Grid, N_Grid)'

    # Downsample safeguard for large JSON payloads
    if length(Z) > ARTS_MaxGridPoints_DDEC
        target_N = Int(sqrt(ARTS_MaxGridPoints_DDEC))
        Z        = ARTS_Downsample_DDEF(Z, target_N, target_N)
        r_str    = max(1, length(x1) ÷ target_N)
        x1       = x1[unique([collect(1:r_str:length(x1)); length(x1)])]
        x2       = x2[unique([collect(1:r_str:length(x2)); length(x2)])]
    end

    trace = surface(; 
        x          = collect(x1), 
        y          = collect(x2), 
        z          = Z, 
        colorscale = ARTS_ViridisScale_DDEC,
        contours   = attr(z=attr(show=true, usecolormap=true, project_z=true)),
        colorbar   = attr(len=0.6, thickness=15, x=1.02)
    )

    layout = ARTS_BaseLayout_DDEF("Response Surface: $OutName"; height=ARTS_SceneHeight_DDEC)
    layout[:scene] = attr(
        xaxis  = attr(title=Lbls[1]),
        yaxis  = attr(title=Lbls[2]),
        zaxis  = attr(title=OutName),
        domain = attr(x=[0.0, 0.88], y=[0.0, 1.0])
    )
    layout[:margin] = attr(l=10, r=80, b=10, t=40)
    
    return Plot(trace, layout)
end

"""
    ARTS_RenderContour_DDEF(Model, X_Train, Idx, Lbls, OutName) -> Plot
Renders a 2D Contour map (Heatmap) with labeled isolating lines.
"""
function ARTS_RenderContour_DDEF(Model::Dict, X::Matrix{Float64}, Idx::Vector{Int},
    Lbls::Vector{String}, OutName::String)
    ix, iy = Idx[1], Idx[2]
    N      = 100
    x1, x2, Grid = ARTS_BuildGrid_DDEF(X, ix, iy, N)

    Z = reshape(ARTS_Predict_DDEF(Model, Grid), N, N)'

    # Downsample safeguard for large JSON payloads
    if length(Z) > ARTS_MaxGridPoints_DDEC
        target_N = Int(sqrt(ARTS_MaxGridPoints_DDEC))
        Z        = ARTS_Downsample_DDEF(Z, target_N, target_N)
        r_str    = max(1, length(x1) ÷ target_N)
        x1       = x1[unique([collect(1:r_str:length(x1)); length(x1)])]
        x2       = x2[unique([collect(1:r_str:length(x2)); length(x2)])]
    end

    trace = contour(; 
        x          = collect(x1), 
        y          = collect(x2), 
        z          = Z, 
        colorscale = ARTS_ViridisScale_DDEC,
        contours   = attr(coloring="heatmap", showlabels=true),
        colorbar   = attr(len=0.6, thickness=15, x=1.02)
    )

    layout = ARTS_BaseLayout_DDEF("Contour Projection: $OutName")
    layout[:xaxis][:title] = Lbls[1]
    layout[:yaxis][:title] = Lbls[2]
    
    return Plot(trace, layout)
end

# --------------------------------------------------------------------------------------
# --- ADVANCED ANALYTICS (SLICES, TRENDS, DESIGN SPACE) ---
# --------------------------------------------------------------------------------------

"""
    ARTS_RenderSlice_DDEF(Model, X, Idx, Lbls, OutName) -> Plot
Renders interaction slices for two variables (Min/Mean/Max levels).
"""
function ARTS_RenderSlice_DDEF(Model::Dict, X::Matrix{Float64}, Idx::Vector{Int},
    Lbls::Vector{String}, OutName::String)
    ix, iy = Idx[1], Idx[2]
    K      = 3 # Fixed 3-variable system

    x1      = collect(range(minimum(view(X, :, ix)), maximum(view(X, :, ix)); length=100))
    y_vals  = (minimum(view(X, :, iy)), mean(view(X, :, iy)), maximum(view(X, :, iy)))
    y_names = ("Min", "Mean", "Max")
    styles  = ("solid", "dash", "solid")
    colours = (ARTS_Theme_DDEC.SHAMAG, ARTS_Theme_DDEC.TONCYA, ARTS_Theme_DDEC.HUEYEL)

    col_means = vec(mean(X; dims=1))
    traces    = GenericTrace[]

    for i in eachindex(y_vals)
        Grid      = repeat(col_means', length(x1))
        Grid[:, ix] .= x1
        Grid[:, iy] .= y_vals[i]

        z = ARTS_Predict_DDEF(Model, Grid)
        push!(traces, scatter(; 
            x    = x1, 
            y    = z, 
            mode = "lines",
            name = "$(Lbls[2]) = $(y_names[i])",
            line = attr(color=colours[i], dash=styles[i], width=2)
        ))
    end

    layout = ARTS_BaseLayout_DDEF("Interaction Slice: $OutName")
    layout[:xaxis][:title] = Lbls[1]
    layout[:yaxis][:title] = OutName
    
    return Plot(traces, layout)
end

"""
    ARTS_RenderTrend_DDEF(Model, X, Y_Real, Idx, Lbls, OutName) -> Plot
Renders main effect trend line with experimental scatter points.
"""
function ARTS_RenderTrend_DDEF(Model::Dict, X::Matrix{Float64}, Y_Real::Vector{Float64},
    Idx::Vector{Int}, Lbls::Vector{String}, OutName::String)
    ix = Idx[1]
    N  = 100

    xr   = collect(range(minimum(view(X, :, ix)), maximum(view(X, :, ix)); length=N))
    Grid = repeat(mean(X; dims=1), N)
    Grid[:, ix] .= xr

    y_trend = ARTS_Predict_DDEF(Model, Grid)

    t_line = scatter(; 
        x    = xr, 
        y    = y_trend, 
        mode = "lines", 
        name = "Model Trend",
        line = attr(color=ARTS_Theme_DDEC.DARHIG, dash="dash")
    )

    t_data = scatter(; 
        x      = X[:, ix], 
        y      = Y_Real, 
        mode   = "markers", 
        name   = "Experimental",
        marker = attr(color=ARTS_Theme_DDEC.TONGRE, size=8, line=attr(width=1, color=ARTS_Theme_DDEC.PURBLA))
    )

    layout = ARTS_BaseLayout_DDEF("Main Effect: $(Lbls[1]) -> $OutName")
    layout[:xaxis][:title] = Lbls[1]
    layout[:yaxis][:title] = OutName
    
    return Plot([t_line, t_data], layout)
end

"""
    ARTS_RenderSpace_DDEF(Models, Goals, X, Idx, Lbls, [Best_Point]) -> Plot
Visualises the multi-objective desirability space.
"""
function ARTS_RenderSpace_DDEF(Models, Goals, X::Matrix{Float64}, Idx::Vector{Int}, Lbls::Vector{String},
    Leaders_DF::AbstractDataFrame=DataFrame())
    return ARTS_RenderSpaceImpl_DDEF(Models, Goals, X, Idx, Lbls, Leaders_DF, false)[1]
end

"""
    ARTS_RenderCandidates_DDEF(Models, Goals, X, Idx, Lbls, [Best_Point]) -> (Plot, PctString)
Visualises the top quartile of the desirability space (Optimal Solution Space).
"""
function ARTS_RenderCandidates_DDEF(Models, Goals, X::Matrix{Float64}, Idx::Vector{Int}, Lbls::Vector{String},
    Leaders_DF::AbstractDataFrame=DataFrame())
    p, pct_str = ARTS_RenderSpaceImpl_DDEF(Models, Goals, X, Idx, Lbls, Leaders_DF, true)
    return p, pct_str
end

"""
    ARTS_RenderSpaceImpl_DDEF(Models, Goals, X, Idx, Lbls, Best_Point, is_candidate) -> (Plot, PctString)
Core rendering logic for desirability-based solution spaces.
"""
function ARTS_RenderSpaceImpl_DDEF(Models, Goals, X::Matrix{Float64}, Idx::Vector{Int}, Lbls::Vector{String},
    Leaders_DF::AbstractDataFrame, is_candidate::Bool)
    ix, iy = Idx[1], Idx[2]

    N = ARTS_AdaptiveGridN_DDEF(200, 40000)
    K = 3 # Fixed 3-variable system

    x1 = collect(range(minimum(view(X, :, ix)), maximum(view(X, :, ix)); length=N))
    x2 = collect(range(minimum(view(X, :, iy)), maximum(view(X, :, iy)); length=N))

    # --- CROSS-SECTION LOGIC (CENTRING) ---
    # Centering on top leader average (user request) instead of global mean
    col_ref = vec(mean(X; dims=1))
    if nrow(Leaders_DF) > 0
        C       = Sys_Fast.FAST_Data_DDEC
        in_cols = filter(n -> startswith(n, C.PRE_INPUT), names(Leaders_DF))
        if length(in_cols) == K
            # Average coordinates of top 8 leaders (or all if < 8)
            num_ref    = min(8, nrow(Leaders_DF))
            ref_matrix = Matrix{Float64}(Leaders_DF[1:num_ref, Symbol.(in_cols)])
            col_ref    = vec(mean(ref_matrix; dims=1))
        end
    end

    # iz is always the 3rd variable not being used for the 2D slice
    iz    = first(setdiff(1:3, Idx))
    z_min = minimum(view(X, :, iz))
    z_max = maximum(view(X, :, iz))

    # Use the iz-th component of our reference centre
    z_mid = col_ref[iz]

    # Scientific Safeguard: Ensure Z-dimension has depth even if variable is constant
    if abs(z_max - z_min) < 1e-4
        z_min -= 0.5
        z_max += 0.5
    end
    z_vals = [z_min, z_mid, z_max]

    traces     = GenericTrace[]
    global_max = 0.0
    global_min = 1.0
    all_scores = Vector{Matrix{Float64}}(undef, length(z_vals))

    col_means = col_ref # Use the calculated reference for naming consistency below

    # Prioritize goals attached to the models themselves for robustness
    parsed_goals = [ARTS_ExtractGoal_DDEF(get(Models[m], "Goal", Goals[m])) for m in eachindex(Models)]

    for (s, zv) in enumerate(z_vals)
        Grid = repeat(col_means', N * N)
        @inbounds for (k, pt) in enumerate(Iterators.product(x1, x2))
            Grid[k, ix] = pt[1]
            Grid[k, iy] = pt[2]
            iz > 0 && (Grid[k, iz] = zv)
        end

        Scores     = ones(N * N)
        weight_sum = sum([g[6] for g in parsed_goals])
        pow_factor = weight_sum > 0.0 ? (1.0 / weight_sum) : 1.0

        for m in eachindex(Models)
            preds    = ARTS_Predict_DDEF(Models[m], Grid)
            goal_tup = parsed_goals[m]

            Threads.@threads for i in eachindex(preds)
                d_val      = ARTS_CalcDesirability_DDEF(preds[i], goal_tup)
                Scores[i] *= (d_val^goal_tup[6])
            end
        end
        
        # Final ScoreMat Clamping & NaN-safe stats
        ScoreMat = clamp.(reshape(Scores .^ pow_factor, N, N)', 0.0, 1.0)
        ScoreMat[isnan.(ScoreMat)] .= 0.0
        all_scores[s] = ScoreMat

        # Robust min/max ignoring NaNs for colorbar stability
        valid_scores_mat = filter(!isnan, ScoreMat)
        if !isempty(valid_scores_mat)
            global_max = max(global_max, maximum(valid_scores_mat))
            global_min = min(global_min, minimum(valid_scores_mat))
        end
    end

    all_non_zero = Float64[]
    for s in eachindex(z_vals)
        for val in all_scores[s]
            val > 1e-6 && push!(all_non_zero, val)
        end
    end

    if isempty(all_non_zero)
        thresh = 1.0
        pct = 0.0
    else
        # Top quartile of scores
        thresh = quantile(all_non_zero, 0.75)
        total_pts = length(z_vals) * N * N
        pct = (0.25 * length(all_non_zero) / total_pts) * 100.0
    end
    pct_str = @sprintf("%.2f", pct)

    for (s, zv) in enumerate(z_vals)
        Masked = copy(all_scores[s])
        if is_candidate
            Masked[Masked .< thresh] .= NaN
        end

        Z_layer = fill(iz > 0 ? zv : 0.0, N, N)

        # Draw if there's data OR if it's a boundary layer (to preserve 3D volume structure)
        if any(!isnan, Masked) || s == 1 || s == 3
            # If a boundary layer is empty, show a ultra-faint ghost surface to avoid visual collapse
            is_empty_layer = !any(!isnan, Masked)
            if is_empty_layer
                Masked = fill(0.0, N, N) # Show as zero/min color
            end

            alpha_val = (s == 2 || iz == 0) ? (is_candidate ? 0.85 : 0.70) : (is_candidate ? 0.35 : 0.20)
            if is_empty_layer
                alpha_val = 0.05
            end # Ghost mode
            trace_name = (s == 2 && K > 2 && nrow(Leaders_DF) > 0) ? "Level: $(round(zv; digits=2))" : "Slice $s"

            push!(traces, surface(;
                x            = x1, 
                y            = x2, 
                z            = Z_layer,
                surfacecolor = Masked,
                colorscale   = ARTS_ViridisScale_DDEC,
                cmin         = 0.0, # Hard Lockdown
                cmax         = 1.0, # Hard Lockdown
                showscale    = (s == 1),
                opacity      = alpha_val,
                name         = trace_name,
                showlegend   = false,
                contours     = attr(z=attr(show=true, usecolormap=true, width=3)),
                colorbar     = attr(
                    title     = "Desirability",
                    len       = 0.6, 
                    thickness = 15, 
                    x         = 1.02,
                    tickvals  = [0, 0.2, 0.4, 0.6, 0.8, 1.0],
                    ticktext  = ["0.0", "0.2", "0.4", "0.6", "0.8", "1.0"]
                )
            ))
        end
    end

    if nrow(Leaders_DF) > 0
        C = Sys_Fast.FAST_Data_DDEC
        th = ARTS_Theme_DDEC
        # Extract variable columns (Case-Insensitive)
        in_cols = filter(n -> startswith(uppercase(string(n)), uppercase(C.PRE_INPUT)), names(Leaders_DF))
        id_col = findfirst(c -> uppercase(c) == "ID" || uppercase(c) == "EXP_ID", names(Leaders_DF))
        score_col = findfirst(c -> uppercase(c) == "SCORE", names(Leaders_DF))

        # Limits based on plot type: Candidates (14 mixed) vs Design Space (8 Top only)
        top_limit = 8
        inp_limit = is_candidate ? 3 : 0
        out_limit = is_candidate ? 3 : 0

        added_top, added_in, added_out = 0, 0, 0
        for r in 1:nrow(Leaders_DF)
            # Find candidate type from ID (using standardised prefixes)
            id_val = !isnothing(id_col) ? string(Leaders_DF[r, id_col]) : "L$r"
            id_upper = uppercase(id_val)

            is_top = occursin("TOP", id_upper)
            is_in = occursin("INP", id_upper)
            is_out = occursin("OUT", id_upper)

            marker_type = ""
            if is_top && added_top < top_limit
                added_top += 1
                marker_type = "TOP"
            elseif is_in && added_in < inp_limit
                added_in += 1
                marker_type = "INP"
            elseif is_out && added_out < out_limit
                added_out += 1
                marker_type = "OUT"
            else
                continue # Skip extra candidates
            end

            bx = Leaders_DF[r, Symbol(in_cols[ix])]
            by = Leaders_DF[r, Symbol(in_cols[iy])]
            bz = iz > 0 ? Leaders_DF[r, Symbol(in_cols[iz])] : 0.0

            # Colour coding: Red (Global), White (Input Diversity), Black (Output Diversity)
            marker_colour = marker_type == "TOP" ? th.HUERED : (marker_type == "INP" ? th.PURWHI : th.PURBLA)
            marker_name = marker_type == "TOP" ? "Global Leader ($id_val)" :
                          (marker_type == "INP" ? "Input-Based Leader ($id_val)" : "Output-Based Leader ($id_val)")

            push!(traces, scatter3d(;
                x         = [bx], 
                y         = [by], 
                z         = [bz],
                mode      = "markers",
                marker    = attr(size=2, color=marker_colour, symbol="diamond", line=attr(color=th.PURBLA, width=1)),
                showlegend = false,
                name      = marker_name,
                hovertext = ["$marker_name<br>Score: $(round(Leaders_DF[r, score_col], digits=3))"],
                hoverinfo = "text"
            ))
        end
    end

    plot_title = is_candidate ? "Candidates ($pct_str%)" : "Design Space: $(Lbls[1]) vs $(Lbls[2])"
    layout     = ARTS_BaseLayout_DDEF(plot_title; height=ARTS_SceneHeight_DDEC)
    
    layout[:scene] = attr(
        xaxis  = attr(title=Lbls[1]),
        yaxis  = attr(title=Lbls[2]),
        zaxis  = attr(
            title = iz > 0 ? (length(Lbls) > 2 ? Lbls[3] : "Z-Axis") : "Level",
            range = abs(z_vals[3] - z_vals[1]) < 1e-6 ? [z_vals[1] - 0.5, z_vals[1] + 0.5] : nothing
        ),
        camera     = attr(eye=attr(x=1.6, y=1.6, z=0.8)),
        aspectmode = "cube",
        domain     = attr(x=[0.0, 0.88], y=[0.0, 1.0])
    )
    layout[:margin] = attr(l=10, r=80, b=10, t=40)
    
    return Plot(traces, layout), pct_str
end

"""
    ARTS_RenderOptimalZone_DDEF(Models, Goals, X, InNames) -> (Plot, PctString)
Renders a 3D isometric volume of the 'Optimal Zone' (Top 10% Desirability).
"""
function ARTS_RenderOptimalZone_DDEF(Models, Goals, X::Matrix{Float64}, InNames::Vector{String})
    N      = 50 # High-fidelity grid for volume stability (50^3 = 125,000 pts)
    ranges = [range(minimum(view(X, :, i)), maximum(view(X, :, i)); length=N) for i in 1:3]
    Grid   = Matrix{Float64}(undef, N^3, 3)

    # Fill 3D Grid (Fixed 3-variable design)
    idx = 1
    for (x, y, z) in Iterators.product(ranges...)
        Grid[idx, 1] = x
        Grid[idx, 2] = y
        Grid[idx, 3] = z
        idx += 1
    end

    # Composite Desirability Calc
    Scores       = ones(N^3)
    # Prioritize goals attached to the models themselves for robustness
    parsed_goals = [ARTS_ExtractGoal_DDEF(get(Models[m], "Goal", Goals[m])) for m in eachindex(Models)]
    weight_sum   = sum([g[6] for g in parsed_goals])
    pow          = weight_sum > 0.0 ? (1.0 / weight_sum) : 1.0

    for m in eachindex(Models)
        preds = ARTS_Predict_DDEF(Models[m], Grid)
        for i in eachindex(preds)
            d          = ARTS_CalcDesirability_DDEF(preds[i], parsed_goals[m])
            Scores[i] *= (d^parsed_goals[m][6])
        end
    end
    Scores = clamp.(Scores .^ pow, 0.0, 1.0)

    # Target the top 10% desirable space (NaN-safe)
    valid_scores = filter(s -> !isnan(s) && s > 1e-6, Scores)
    thresh       = isempty(valid_scores) ? 0.9 : quantile(valid_scores, 0.90)

    # Calculate Volume Percentage for Optimal Zone
    pts_above = count(s -> !isnan(s) && s >= thresh, Scores)
    pct       = (pts_above / length(Scores)) * 100.0
    pct_str   = @sprintf("%.2f", pct)

    trace = volume(;
        x             = Grid[:, 1], 
        y             = Grid[:, 2], 
        z             = Grid[:, 3],
        value         = Scores,
        isomin        = thresh,
        isomax        = 1.0, # Hard Lockdown
        opacity       = 0.3,
        surface_count = 5,
        colorscale    = ARTS_ViridisScale_DDEC,
        cmin          = 0.0,
        cmax          = 1.0,
        colorbar      = attr(
            title    = "Quality Index",
            len      = 0.6,
            tickvals = [0, 0.2, 0.4, 0.6, 0.8, 1.0],
            ticktext = ["0.0", "0.2", "0.4", "0.6", "0.8", "1.0"]
        )
    )

    layout = ARTS_BaseLayout_DDEF("Optimal Solution Volume ($pct_str%)")
    layout[:scene] = attr(
        xaxis = attr(title=InNames[1]),
        yaxis = attr(title=InNames[2]),
        zaxis = attr(title=InNames[3]),
        camera = attr(eye=attr(x=1.8, y=1.8, z=0.9))
    )
    
    return Plot(trace, layout), pct_str
end

"""
    ARTS_RenderInteractionMatrix_DDEF(Model, InNames, OutName) -> Plot
Renders a Heatmap matrix illustrating factor interaction strengths (synergy/antagonism).
"""
function ARTS_RenderInteractionMatrix_DDEF(Model::Dict, InNames::Vector{String}, OutName::String)
    K = 3 # Fixed 3rd dimension
    M = zeros(K, K)

    ModelType = get(Model, "ModelType", "quadratic")
    if occursin("quadratic", ModelType) && haskey(Model, "Coefs") && length(Model["Coefs"]) >= 10
        Beta    = Model["Coefs"]
        M[1, 1] = Beta[8]
        M[2, 2] = Beta[9]
        M[3, 3] = Beta[10]
        M[1, 2] = M[2, 1] = Beta[5]
        M[1, 3] = M[3, 1] = Beta[6]
        M[2, 3] = M[3, 2] = Beta[7]
    end

    trace  = heatmap(; 
        z = M, 
        x = InNames, 
        y = InNames, 
        colorscale = [[0, ARTS_Theme_DDEC.SHAMAG], [0.5, ARTS_Theme_DDEC.PURWHI], [1, ARTS_Theme_DDEC.HUEYEL]], 
        zmid = 0
    )
    layout = ARTS_BaseLayout_DDEF("Interaction Landscape: $OutName")
    
    return Plot(trace, layout)
end

"""
    ARTS_RenderQQPlot_DDEF(Residuals::AbstractVector{Float64}, OutName::String) -> Plot
Renders a Q-Q Plot (Normal Probability Plot) for residual diagnostic analysis.
"""
function ARTS_RenderQQPlot_DDEF(Residuals::AbstractVector{Float64}, OutName::String)
    n          = length(Residuals)
    sorted_res = sort(Residuals)

    # Standardise residuals
    z_res = (sorted_res .- mean(sorted_res)) ./ std(sorted_res)

    # Theoretical quantiles for normal distribution
    p_vals      = [(i - 0.5) / n for i in 1:n]
    theoretical = quantile.(Normal(0, 1), p_vals)

    trace_pts = scatter(; 
        x      = theoretical, 
        y      = z_res, 
        mode   = "markers",
        marker = attr(color=ARTS_Theme_DDEC.SHAMAG, size=8, opacity=0.7, line=attr(width=1, color=ARTS_Theme_DDEC.PURBLA)),
        name   = "Residuals"
    )

    # Reference Line (y=x)
    lims       = [minimum([theoretical; z_res]), maximum([theoretical; z_res])]
    trace_line = scatter(; 
        x    = lims, 
        y    = lims, 
        mode = "lines",
        line = attr(color=ARTS_Theme_DDEC.HUEYEL, width=2, dash="dash"),
        name = "Normal Dist"
    )

    layout = ARTS_BaseLayout_DDEF("Normal Probability (Q-Q): $OutName")
    layout[:xaxis][:title] = "Theoretical Quantiles"
    layout[:yaxis][:title] = "Standardised Residuals"

    return Plot([trace_pts, trace_line], layout)
end

"""
    ARTS_RenderResidualsVsPred_DDEF(Y_Pred::AbstractVector{Float64}, Residuals::AbstractVector{Float64}, OutName::String) -> Plot
Renders Residuals vs. Predicted plot to check for homoscedasticity.
"""
function ARTS_RenderResidualsVsPred_DDEF(Y_Pred::AbstractVector{Float64}, Residuals::AbstractVector{Float64}, OutName::String)
    trace_pts = scatter(; 
        x      = Y_Pred, 
        y      = Residuals, 
        mode   = "markers",
        marker = attr(color = ARTS_Theme_DDEC.SHAMAG, size = 9, opacity = 0.7, line = attr(width = 1, color = ARTS_Theme_DDEC.PURWHI)),
        name   = "Residuals"
    )

    # zero line
    trace_zero = scatter(; 
        x          = [minimum(Y_Pred), maximum(Y_Pred)], 
        y          = [0, 0], 
        mode       = "lines",
        line       = attr(color = ARTS_Theme_DDEC.HUEYEL, width = 2, dash = "solid"),
        showlegend = false
    )

    layout = ARTS_BaseLayout_DDEF("Residuals vs. Predicted: $OutName")
    layout[:xaxis][:title] = "Predicted Value"
    layout[:yaxis][:title] = "Residual"

    return Plot([trace_pts, trace_zero], layout)
end

"""
    ARTS_RenderSensitivityPlot_DDEF(Sens::AbstractVector{Float64}, InNames::Vector{String}, OutName::String) -> Plot
Renders localized factor sensitivity percentage contribution at the optimal point.
"""
function ARTS_RenderSensitivityPlot_DDEF(Sens::AbstractVector{Float64}, InNames::Vector{String}, OutName::String)
    trace = bar(; 
        x      = InNames, 
        y      = Sens .* 100.0,
        marker = attr(
            color = [ARTS_Theme_DDEC.SHAMAG, ARTS_Theme_DDEC.TONGRE, ARTS_Theme_DDEC.HUEYEL], # High-fidelity palette
            line  = attr(width = 1.5, color = ARTS_Theme_DDEC.PURWHI)
        ),
        textposition = "auto",
        text         = [@sprintf("%.1f%%", s * 100) for s in Sens]
    )

    layout = ARTS_BaseLayout_DDEF("Local Sensitivity Index: $OutName")
    layout[:yaxis][:title] = "Contribution (%)"
    layout[:xaxis][:title] = "Experimental Factor"

    return Plot(trace, layout)
end

# --------------------------------------------------------------------------------------
# --- MASTER RENDERER DISPATCHER ---
# --------------------------------------------------------------------------------------

"""
    ARTS_Render_DDEF(Models, X, Y, InNames, OutNames, Goals, R2s, Q2s, Opts, Leaders_DF, Sens, Residuals) -> Vector{Dict}
Primary output orchestrator for generating all selected plot types.
"""
function ARTS_Render_DDEF(Models, X, Y, InNames, OutNames, Goals, R2s, Q2s, Opts,
    Leaders_DF::AbstractDataFrame=DataFrame(),
    Sens::Vector{Vector{Float64}}=Vector{Float64}[],
    Residuals::Vector{Vector{Float64}}=Vector{Float64}[])

    graphs      = Dict{String,Any}[]
    graphs_lock = ReentrantLock()
    NumVars     = 3 # Fixed 3-variable system
    NumOut      = length(OutNames)

    Combos = NumVars >= 2 ? collect(combinations(1:NumVars, 2)) : Vector{Int}[]

    tasks = []

    for m in 1:NumOut
        Models[m]["Status"] != "OK" && continue
        name = OutNames[m]

        # 1. Statistical Diagnostics
        if get(Opts, "Pareto", true)
            push!(tasks, Threads.@spawn begin
                try
                    p1     = ARTS_RenderPareto_DDEF(Models[m], name, R2s[m], Q2s[m])
                    y_pred = ARTS_Predict_DDEF(Models[m], X)
                    p2     = ARTS_RenderFit_DDEF(Y[:, m], y_pred, name)

                    lock(graphs_lock) do
                        push!(graphs, Dict("Type" => "Pareto", "Title" => "Pareto: $name",      "Plot" => p1))
                        push!(graphs, Dict("Type" => "Fit",    "Title" => "Fit: $name",         "Plot" => p2))
                    end

                    # New Academic Diagnostics
                    if m <= length(Residuals) && !isempty(Residuals[m])
                        p_qq  = ARTS_RenderQQPlot_DDEF(Residuals[m], name)
                        p_res = ARTS_RenderResidualsVsPred_DDEF(y_pred, Residuals[m], name)
                        lock(graphs_lock) do
                            push!(graphs, Dict("Type" => "QQ",        "Title" => "Q-Q Plot: $name", "Plot" => p_qq))
                            push!(graphs, Dict("Type" => "Residuals", "Title" => "Residuals: $name", "Plot" => p_res))
                        end
                    end

                    # Sensitivity bar chart
                    if m <= length(Sens) && !isempty(Sens[m])
                        p_sens = ARTS_RenderSensitivityPlot_DDEF(Sens[m], InNames, name)
                        lock(graphs_lock) do
                            push!(graphs, Dict("Type" => "Sensitivity", "Title" => "Sensitivity: $name", "Plot" => p_sens))
                        end
                    end
                catch e
                    Sys_Fast.FAST_Log_DDEF("ARTS", "RENDER_ERR", "Diagnostic plot failed for $name: $e", "WARN")
                end
            end)
        end

        # 2. Variable Interactions & Surface Mapping
        for c in Combos
            lbls = [InNames[c[1]], InNames[c[2]]]
            tag  = "$(lbls[1])-$(lbls[2])"

            if get(Opts, "Surface", true)
                push!(tasks, Threads.@spawn begin
                    try
                        p1 = ARTS_RenderSurface_DDEF(Models[m], X, c, lbls, name)
                        p2 = ARTS_RenderContour_DDEF(Models[m], X, c, lbls, name)
                        lock(graphs_lock) do
                            push!(graphs, Dict("Type" => "Surface", "Title" => "RSM: $name ($tag)",     "Plot" => p1))
                            push!(graphs, Dict("Type" => "Contour", "Title" => "Contour: $name ($tag)",   "Plot" => p2))
                        end
                    catch e
                         Sys_Fast.FAST_Log_DDEF("ARTS", "RENDER_ERR", "Surface/Contour plot failed for $name: $e", "WARN")
                    end
                end)
            end

            if get(Opts, "Interaction", true)
                push!(tasks, Threads.@spawn begin
                    try
                        p1 = ARTS_RenderSlice_DDEF(Models[m], X, c, lbls, name)
                        p2 = ARTS_RenderTrend_DDEF(Models[m], X, Y[:, m], c, lbls, name)
                        lock(graphs_lock) do
                            push!(graphs, Dict("Type" => "Slice", "Title" => "Interact: $name ($tag)", "Plot" => p1))
                            push!(graphs, Dict("Type" => "Trend", "Title" => "Trend: $name ($tag)",    "Plot" => p2))
                        end
                    catch e
                        Sys_Fast.FAST_Log_DDEF("ARTS", "RENDER_ERR", "Interaction plot failed for $name: $e", "WARN")
                    end
                end)
            end
        end
    end

    # 3. Composite Sustainability & Design Space
    if get(Opts, "DesignSpace", true) && !isempty(Combos)
        for c in Combos
            lbls = [InNames[c[1]], InNames[c[2]]]
            # 3 variables means iz is always the one not in c
            iz = first(setdiff(1:3, c))
            push!(lbls, InNames[iz])

            push!(tasks, Threads.@spawn begin
                try
                    p1                  = ARTS_RenderSpace_DDEF(Models, Goals, X, c, lbls, Leaders_DF)
                    cand_plot, cand_pct = ARTS_RenderCandidates_DDEF(Models, Goals, X, c, lbls, Leaders_DF)
                    lock(graphs_lock) do
                        push!(graphs, Dict("Type" => "DesignSpace", "Title" => "Design Space: $(lbls[1])-$(lbls[2])", "Plot" => p1))
                        push!(graphs, Dict("Type" => "Candidates",  "Title" => "Candidates: $(lbls[1])-$(lbls[2])",  "Plot" => cand_plot))
                    end
                catch e
                    Sys_Fast.FAST_Log_DDEF("ARTS", "RENDER_ERR", "Design Space plot failed for $(lbls[1])-$(lbls[2]): $e", "WARN")
                end
            end)
        end

        # --- THE OPTIMAL ZONE ---
        if get(Opts, "GoldenZone", true) && NumVars >= 3
            push!(tasks, Threads.@spawn begin
                try
                    p_gz, gz_pct = ARTS_RenderOptimalZone_DDEF(Models, Goals, X, InNames)
                    lock(graphs_lock) do
                        push!(graphs, Dict("Type" => "OptimalZone", "Title" => "Optimal Zone", "Plot" => p_gz))
                    end
                catch e
                    Sys_Fast.FAST_Log_DDEF("ARTS", "RENDER_ERR", "Optimal Zone plot failed: $e", "WARN")
                end
            end)
        end
    end

    # Wait for all plotting threads to compute
    for t in tasks
        wait(t)
    end

    TypePriority = Dict(
        "Pareto"      => 1,
        "Fit"         => 2,
        "QQ"          => 3,
        "Residuals"   => 4,
        "Surface"     => 5,
        "Contour"     => 6,
        "Slice"       => 7,
        "Trend"       => 8,
        "IntMatrix"   => 9,
        "Sensitivity" => 10,
        "DesignSpace" => 11,
        "Candidates"  => 12,
        "OptimalZone" => 13
    )
    sort!(graphs, by=g -> get(TypePriority, g["Type"], 99))

    return graphs
end

end # module Lib_Arts
