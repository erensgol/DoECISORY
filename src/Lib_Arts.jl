module Lib_Arts

# ======================================================================================
# DAISHODOE - LIB ARTS (VISUALISATION & GRAPHICS MOTOR)
# ======================================================================================
# Purpose: High-fidelity PlotlyJS rendering, light-theme configuration,
#          response surface mapping (RSM), and desirability calculations.
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
    ARTS_GetTheme_DDEF, ARTS_CalcDesirability_DDEF, ARTS_ExtractGoal_DDEF,
    ARTS_Downsample_DDEF, ARTS_RenderOptimalZone_DDEF, ARTS_RenderInteractionMatrix_DDEF,
    ARTS_BaseLayout_DDEF, ARTS_Predict_DDEF, ARTS_BuildGrid_DDEF,
    ARTS_AdaptiveGridN_DDEF, ARTS_RenderSpaceImpl_DDEF

# --------------------------------------------------------------------------------------
# --- INTERFACE LAYOUT & THEME ---
# --------------------------------------------------------------------------------------

# Theme as a module-level const for zero-alloc access
# Theme linked to Sys_Fast constants for single-source-of-truth
const THEME = let C = Sys_Fast.CONST_DATA
    # Mapping to British English Constants
    (
        Magenta    = C.COLOUR_MAGENTA,
        Yellow     = C.COLOUR_YELLOW,
        Green      = C.COLOUR_GREEN,
        Cyan       = C.COLOUR_CYAN,
        Red        = C.COLOUR_RED,
        Blue       = C.COLOUR_BLUE,
        Purple     = C.COLOUR_MAGENTA,
        Text       = C.COLOUR_GREY_D,
        TextBright = C.COLOUR_BLACK,
        Grid       = C.COLOUR_GREY_L,
        Bg         = C.COLOUR_WHITE,
        Font       = C.FONT_DEFAULT,
    )
end

"""
    ARTS_GetTheme_DDEF() -> NamedTuple
Returns the global visual identity of the application.
"""
ARTS_GetTheme_DDEF() = THEME

# --- GRAPHICAL STANDARD SCALES ---

const _STANDARD_HEIGHT = 500
const _SCENE_HEIGHT = 500

"""
    ARTS_BaseLayout_DDEF(title; [height]) -> Layout
Generates a standardised PlotlyJS layout with light theme support.
"""
function ARTS_BaseLayout_DDEF(title::String; height=_STANDARD_HEIGHT)
    TH = THEME
    return Layout(;
        title=attr(
            text=title,
            font=attr(size=12, family=TH.Font, color=TH.TextBright),
            x=0.02, y=0.98,
        ),
        paper_bgcolor=TH.Bg,
        plot_bgcolor=TH.Bg,
        font=attr(family=TH.Font, color=TH.Text, size=10),
        margin=attr(l=70, r=40, t=70, b=80),
        height=height,
        xaxis=attr(
            showline=true, showgrid=true,
            gridcolor=TH.Grid, gridwidth=1, griddash="dash",
            zeroline=false, linecolor=TH.Grid, linewidth=1, mirror=true, ticks="outside",
        ),
        yaxis=attr(
            showline=true, showgrid=true,
            gridcolor=TH.Grid, gridwidth=1, griddash="dash",
            zeroline=false, linecolor=TH.Grid, linewidth=1, mirror=true, ticks="outside",
        ),
        colorway=[TH.Blue, TH.Magenta, TH.Green, TH.Yellow, TH.Cyan],
        hovermode="closest",
        template="plotly_white",
    )
end

# High-fidelity Viridis colour mapping for surfaces and heatmaps
const VIRIDIS_SCALE = let C = Sys_Fast.CONST_DATA
    [
        [0.0,  C.COLOUR_MAGENTA], 
        [0.25, C.COLOUR_BLUE], 
        [0.5,  C.COLOUR_CYAN],
        [0.75, C.COLOUR_GREEN], 
        [1.0,  C.COLOUR_YELLOW],
    ]
end

# --- SMART DOWNSAMPLING & GRID LIMITER ---

# Maximum safe grid points for browser rendering (N×N per plot)
const _MAX_GRID_POINTS = 40000   # 200×200 = 40,000 points per surface
const _MAX_JSON_BYTES = 5_000_000  # ~5 MB per figure JSON

"""
    ARTS_AdaptiveGridN_DDEF(preferred, [max_total]) -> Int
Returns a grid resolution N such that N×N ≤ max_total.
"""
function ARTS_AdaptiveGridN_DDEF(preferred::Int, max_total::Int=_MAX_GRID_POINTS)
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
    G_Tgt = Float64(get(Goal, "Target", (G_Min + G_Max) / 2))
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
            res = denom > 1e-9 ? (Val - G_Min) / denom : 1.0
        end
    elseif is_min
        if Val <= G_Tgt
            res = 1.0
        elseif Val >= G_Max
            res = 0.0
        else
            denom = G_Max - G_Tgt
            res = denom > 1e-9 ? (G_Max - Val) / denom : 1.0
        end
    else # Nominal
        if Val <= G_Min || Val >= G_Max
            res = 0.0
        elseif abs(Val - G_Tgt) < 1e-12
            res = 1.0
        elseif Val < G_Tgt
            denom = G_Tgt - G_Min
            res = denom > 1e-9 ? (Val - G_Min) / denom : 1.0
        else # Val > G_Tgt
            denom = G_Max - G_Tgt
            res = denom > 1e-9 ? (G_Max - Val) / denom : 1.0
        end
    end
    
    # Scientific Safeguard: NaN or Inf should be 0.0, others clamped to [0, 1]
    return (isnan(res) || isinf(res)) ? 0.0 : clamp(res, 0.0, 1.0)
end

function ARTS_CalcDesirability_DDEF(Val::Float64, Goal::AbstractDict)
    return ARTS_CalcDesirability_DDEF(Val, ARTS_ExtractGoal_DDEF(Goal))
end

# --------------------------------------------------------------------------------------
# --- LINEAR PLOTS (PARETO, ACTUAL VS PRED) ---
# --------------------------------------------------------------------------------------

"""
    ARTS_RenderPareto_DDEF(Model, OutName, R2_Adj, Q2) -> Plot
Renders a horizontal bar chart showing standardised effects of factors.
"""
function ARTS_RenderPareto_DDEF(Model::Dict, OutName::String, R2_Adj::Float64, R2_Pred::Float64)
    TH = THEME
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
            x=sorted_mag[neg_idx],
            y=sorted_nms[neg_idx],
            orientation="h",
            name="Negative Effect",
            marker=attr(color=TH.Purple, line=attr(width=0)),
            text=[@sprintf("%.2f", m) for m in sorted_mag[neg_idx]],
            textposition="auto",
        ))
    end

    # Positive Effects
    pos_idx = findall(x -> x >= 0, sorted_sgn)
    if !isempty(pos_idx)
        push!(traces, bar(;
            x=sorted_mag[pos_idx],
            y=sorted_nms[pos_idx],
            orientation="h",
            name="Positive Effect",
            marker=attr(color=TH.Yellow, line=attr(width=0)),
            text=[@sprintf("%.2f", m) for m in sorted_mag[pos_idx]],
            textposition="auto",
        ))
    end

    r2_str = isnan(R2_Adj) ? "N/A" : @sprintf("%.3f", R2_Adj)
    q2_str = isnan(R2_Pred) ? "N/A" : @sprintf("%.3f", R2_Pred)

    layout = ARTS_BaseLayout_DDEF("Factor Importance: $OutName (R²Adj: $r2_str | Q²: $q2_str)")
    layout[:xaxis][:title] = "Magnitude of Standardised Effect (t-value)"
    layout[:barmode] = "stack"
    layout[:showlegend] = true
    layout[:legend] = attr(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1)

    # Bonferroni Limit (t-critical for alpha = 0.05 / n_terms)
    df = max(1, N_Samples - length(Coefs))
    alpha_corrected = 0.05 / length(clean_eff)
    t_crit = quantile(TDist(df), 1.0 - alpha_corrected / 2)

    limit_shape = attr(
        type="line", x0=t_crit, x1=t_crit, y0=0, y1=1,
        yref="paper", line=attr(color=TH.Red, width=2, dash="dash")
    )
    layout[:shapes] = [limit_shape]

    return Plot(traces, layout)
end

"""
    ARTS_RenderFit_DDEF(Y_Real, Y_Pred, OutName) -> Plot
Compares experimental results with model predictions via scatter plot.
"""
function ARTS_RenderFit_DDEF(Y_Real::Vector{Float64}, Y_Pred::Vector{Float64}, OutName::String)
    TH = THEME
    mn = min(minimum(Y_Real), minimum(Y_Pred))
    mx = max(maximum(Y_Real), maximum(Y_Pred))
    margin = (mx - mn) * 0.05

    t_data = scatter(; x=Y_Real, y=Y_Pred, mode="markers",
        marker=attr(size=8, color=TH.Green, line=attr(width=1, color=TH.TextBright)), name="Data")

    t_ideal = scatter(; x=[mn - margin, mx + margin], y=[mn - margin, mx + margin],
        mode="lines", line=attr(color=TH.Text, dash="dash", width=1), name="Ideal")

    layout = ARTS_BaseLayout_DDEF("Prediction Accuracy: $OutName")
    layout[:xaxis][:title] = "Experimental (Recorded)"
    layout[:yaxis][:title] = "Predicted (Model)"
    layout[:showlegend] = false
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

    # Handle Surrogate Models (Kriging/RBF) if applicable
    if ModelType == "kriging" || ModelType == "rbf"
        # Closures should be used if available, otherwise return NaNs for plotting skip
        return fill(NaN, size(X, 1))
    end

    Beta = Model["Coefs"]
    N, K = size(X)
    if occursin("linear", ModelType)
        Xd = hcat(ones(N), X)
        return Xd * Beta
    else
        combos = collect(combinations(1:K, 2))
        n_inter = length(combos)
        Xd = Matrix{Float64}(undef, N, 1 + K + n_inter + K)
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
    N = ARTS_AdaptiveGridN_DDEF(N_requested)
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

    trace = surface(; x=collect(x1), y=collect(x2), z=Z, colorscale=VIRIDIS_SCALE,
        contours=attr(z=attr(show=true, usecolormap=true, project_z=true)),
        colorbar=attr(len=0.6, thickness=15, x=1.02))

    layout = ARTS_BaseLayout_DDEF("Response Surface: $OutName"; height=_SCENE_HEIGHT)
    layout[:scene] = attr(
        xaxis=attr(title=Lbls[1]),
        yaxis=attr(title=Lbls[2]),
        zaxis=attr(title=OutName),
        domain=attr(x=[0.0, 0.88], y=[0.0, 1.0]),
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
    N = 100
    x1, x2, Grid = ARTS_BuildGrid_DDEF(X, ix, iy, N)

    Z = reshape(ARTS_Predict_DDEF(Model, Grid), N, N)'

    trace = contour(; x=collect(x1), y=collect(x2), z=Z, colorscale=VIRIDIS_SCALE,
        contours=attr(coloring="heatmap", showlabels=true),
        colorbar=attr(len=0.6, thickness=15, x=1.02))

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
    TH = THEME
    ix, iy = Idx[1], Idx[2]
    K = size(X, 2)

    x1 = collect(range(minimum(view(X, :, ix)), maximum(view(X, :, ix)); length=100))
    y_vals = (minimum(view(X, :, iy)), mean(view(X, :, iy)), maximum(view(X, :, iy)))
    y_names = ("Min", "Mean", "Max")
    styles = ("solid", "dash", "solid")
    colours = (TH.Magenta, TH.Cyan, TH.Yellow)

    col_means = vec(mean(X; dims=1))
    traces = GenericTrace[]

    for i in eachindex(y_vals)
        Grid = repeat(col_means', length(x1))
        Grid[:, ix] .= x1
        Grid[:, iy] .= y_vals[i]

        z = ARTS_Predict_DDEF(Model, Grid)
        push!(traces, scatter(; x=x1, y=z, mode="lines",
            name="$(Lbls[2])=$(y_names[i])",
            line=attr(color=colours[i], dash=styles[i], width=2)))
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
    TH = THEME
    ix = Idx[1]
    N = 100

    xr = collect(range(minimum(view(X, :, ix)), maximum(view(X, :, ix)); length=N))
    Grid = repeat(mean(X; dims=1), N)
    Grid[:, ix] .= xr

    y_trend = ARTS_Predict_DDEF(Model, Grid)

    t_line = scatter(; x=xr, y=y_trend, mode="lines", name="Model Trend",
        line=attr(color=TH.Text, dash="dash"))

    t_data = scatter(; x=X[:, ix], y=Y_Real, mode="markers", name="Experimental",
        marker=attr(color=TH.Green, size=8, line=attr(width=1, color=TH.TextBright)))

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
    K = size(X, 2)

    x1 = collect(range(minimum(view(X, :, ix)), maximum(view(X, :, ix)); length=N))
    x2 = collect(range(minimum(view(X, :, iy)), maximum(view(X, :, iy)); length=N))

    iz = 0
    z_vals = [0.0]
    if K > 2
        iz = first(setdiff(1:K, Idx))
        z_min = minimum(view(X, :, iz))
        z_max = maximum(view(X, :, iz))
        
        # Determine z_mid from first leader or mean
        z_mid = mean(view(X, :, iz))
        if is_candidate && nrow(Leaders_DF) > 0
            C = Sys_Fast.FAST_Constants_DDEF()
            in_cols = filter(n -> startswith(n, C.PRE_INPUT), names(Leaders_DF))
            if iz <= length(in_cols)
                z_mid = Leaders_DF[1, Symbol(in_cols[iz])]
            end
        end

        # Scientific Safeguard: Ensure Z-dimension has depth even if variable is constant
        if abs(z_max - z_min) < 1e-4
            z_min -= 0.5
            z_max += 0.5
        end
        z_vals = [z_min, z_mid, z_max]
    end

    traces = GenericTrace[]
    global_max, global_min = 0.0, 1.0
    all_scores = Vector{Matrix{Float64}}(undef, length(z_vals))

    col_means = vec(mean(X; dims=1))

    parsed_goals = [ARTS_ExtractGoal_DDEF(Goals[m]) for m in eachindex(Models)]

    for (s, zv) in enumerate(z_vals)
        Grid = repeat(col_means', N * N)
        @inbounds for (k, pt) in enumerate(Iterators.product(x1, x2))
            Grid[k, ix] = pt[1]
            Grid[k, iy] = pt[2]
            iz > 0 && (Grid[k, iz] = zv)
        end

        Scores = ones(N * N)
        weight_sum = sum([g[6] for g in parsed_goals])
        pow_factor = weight_sum > 0.0 ? (1.0 / weight_sum) : 1.0

        for m in eachindex(Models)
            preds = ARTS_Predict_DDEF(Models[m], Grid)
            goal_tup = parsed_goals[m]

            Threads.@threads for i in eachindex(preds)
                d_val = ARTS_CalcDesirability_DDEF(preds[i], goal_tup)
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
            Masked[Masked.<thresh] .= NaN
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
            if is_empty_layer; alpha_val = 0.05; end # Ghost mode
            trace_name = (s == 2 && K > 2 && nrow(Leaders_DF) > 0) ? "Level: $(round(zv; digits=2))" : "Slice $s"

            push!(traces, surface(;
                x=x1, y=x2, z=Z_layer,
                surfacecolor=Masked,
                colorscale=VIRIDIS_SCALE,
                cmin=0.0, # Hard Lockdown
                cmax=1.0, # Hard Lockdown
                showscale=(s == 1),
                opacity=alpha_val,
                name=trace_name,
                showlegend=false,
                contours=attr(z=attr(show=true, usecolormap=true, width=3)),
                colorbar=attr(
                    title="Desirability",
                    len=0.6, thickness=15, x=1.02,
                    tickvals=[0, 0.2, 0.4, 0.6, 0.8, 1.0],
                    ticktext=["0.0", "0.2", "0.4", "0.6", "0.8", "1.0"]
                )
            ))
        end
    end

    if is_candidate && nrow(Leaders_DF) > 0
        C = Sys_Fast.FAST_Constants_DDEF()
        th = THEME
        in_cols = filter(n -> startswith(n, C.PRE_INPUT), names(Leaders_DF))
        id_col = findfirst(c -> uppercase(c) == "ID" || uppercase(c) == "EXP_ID", names(Leaders_DF))
        score_col = findfirst(c -> uppercase(c) == "SCORE", names(Leaders_DF))

        # Extract top 9 candidates for visualization
        # Type 1: Global TOP (1-3)
        # Type 2: Input-Diversity (first 3)
        # Type 3: Output-Diversity (first 3)
        
        added_top, added_in, added_out = 0, 0, 0
        for r in 1:nrow(Leaders_DF)
            # Find candidate type from ID (using standardized prefixes)
            id_val = !isnothing(id_col) ? string(Leaders_DF[r, id_col]) : "L$r"
            id_upper = uppercase(id_val)
            
            is_top = occursin("TOP", id_upper)
            is_in = occursin("INP", id_upper)
            is_out = occursin("OUT", id_upper)

            marker_type = ""
            if is_top && added_top < 3
                added_top += 1
                marker_type = "TOP"
            elseif is_in && added_in < 3
                added_in += 1
                marker_type = "INP"
            elseif is_out && added_out < 3
                added_out += 1
                marker_type = "OUT"
            else
                continue # Skip extra candidates
            end

            bx = Leaders_DF[r, Symbol(in_cols[ix])]
            by = Leaders_DF[r, Symbol(in_cols[iy])]
            bz = iz > 0 ? Leaders_DF[r, Symbol(in_cols[iz])] : 0.0
            
            # Colour shifting: Pure Red -> Pinkish-Red (INP) -> Orange-Red (OUT)
            marker_colour = marker_type == "TOP" ? th.Red : (marker_type == "INP" ? "#C2185B" : "#F4511E")
            marker_name = marker_type == "TOP" ? "Global Leader ($id_val)" : 
                          (marker_type == "INP" ? "Input-Based Leader ($id_val)" : "Output-Based Leader ($id_val)")
            
            push!(traces, scatter3d(;
                x=[bx], y=[by], z=[bz],
                mode="markers",
                marker=attr(size=4.0, color=marker_colour, symbol="diamond", 
                           line=attr(color=th.Bg, width=1)),
                showlegend=false,
                name=marker_name,
                hovertext=["$marker_name<br>Score: $(round(Leaders_DF[r, score_col], digits=3))"],
                hoverinfo="text"
            ))
        end
    end

    plotTitle = is_candidate ? "Candidates ($pct_str% of Total Space)" : "Design Space: $(Lbls[1]) vs $(Lbls[2])"
    layout = ARTS_BaseLayout_DDEF(plotTitle; height=_SCENE_HEIGHT)
    layout[:scene] = attr(
        xaxis=attr(title=Lbls[1]),
        yaxis=attr(title=Lbls[2]),
        zaxis=attr(title=iz > 0 ? (length(Lbls) > 2 ? Lbls[3] : "Z-Axis") : "Level", 
                   range=abs(z_vals[3]-z_vals[1]) < 1e-6 ? [z_vals[1]-0.5, z_vals[1]+0.5] : nothing),
        camera=attr(eye=attr(x=1.6, y=1.6, z=0.8)),
        aspectmode="cube",
        domain=attr(x=[0.0, 0.88], y=[0.0, 1.0]),
    )
    layout[:margin] = attr(l=10, r=80, b=10, t=40)
    return Plot(traces, layout), pct_str
end

"""
    ARTS_RenderOptimalZone_DDEF(Models, Goals, X, InNames) -> (Plot, PctString)
Renders a 3D isometric volume of the 'Optimal Zone' (Top 10% Desirability).
"""
function ARTS_RenderOptimalZone_DDEF(Models, Goals, X::Matrix{Float64}, InNames::Vector{String})
    TH = THEME
    N = 50 # High-fidelity grid for volume stability (50^3 = 125,000 pts)
    Dim = size(X, 2)
    Dim < 3 && return Plot([], ARTS_BaseLayout_DDEF("Visualisation requires at least 3 variables."))

    ranges = [range(minimum(view(X, :, i)), maximum(view(X, :, i)); length=N) for i in 1:3]
    Grid = Matrix{Float64}(undef, N^3, Dim)

    # Fill 3D Grid
    idx = 1
    for (x, y, z) in Iterators.product(ranges...)
        Grid[idx, 1] = x
        Grid[idx, 2] = y
        Grid[idx, 3] = z
        if Dim > 3
            for d in 4:Dim
                Grid[idx, d] = mean(view(X, :, d))
            end
        end
        idx += 1
    end

    # Composite Desirability Calc
    Scores = ones(N^3)
    parsed_goals = [ARTS_ExtractGoal_DDEF(g) for g in Goals]
    weight_sum = sum([g[6] for g in parsed_goals])
    pow = weight_sum > 0.0 ? (1.0 / weight_sum) : 1.0

    for m in eachindex(Models)
        preds = ARTS_Predict_DDEF(Models[m], Grid)
        for i in eachindex(preds)
            d = ARTS_CalcDesirability_DDEF(preds[i], parsed_goals[m])
            Scores[i] *= (d^parsed_goals[m][6])
        end
    end
    Scores = clamp.(Scores .^ pow, 0.0, 1.0)

    # Target the top 10% desirable space (NaN-safe)
    valid_scores = filter(s -> !isnan(s) && s > 1e-6, Scores)
    thresh = isempty(valid_scores) ? 0.9 : quantile(valid_scores, 0.90)

    # Calculate Volume Percentage for Optimal Zone
    pts_above = count(s -> !isnan(s) && s >= thresh, Scores)
    pct = (pts_above / length(Scores)) * 100.0
    pct_str = @sprintf("%.2f", pct)

    trace = volume(;
        x=Grid[:, 1], y=Grid[:, 2], z=Grid[:, 3],
        value=Scores,
        isomin=thresh,
        isomax=1.0, # Hard Lockdown
        opacity=0.3,
        surface_count=5,
        colorscale=VIRIDIS_SCALE,
        cmin=0.0,
        cmax=1.0,
        colorbar=attr(
            title="Quality Index", 
            len=0.6, 
            tickvals=[0, 0.2, 0.4, 0.6, 0.8, 1.0],
            ticktext=["0.0", "0.2", "0.4", "0.6", "0.8", "1.0"]
        )
    )

    layout = ARTS_BaseLayout_DDEF("Optimal Zone ($pct_str% of Total Space)"; height=_SCENE_HEIGHT)
    layout[:scene] = attr(
        xaxis=attr(title=InNames[1]),
        yaxis=attr(title=InNames[2]),
        zaxis=attr(title=InNames[3]),
        aspectmode="cube"
    )
    return Plot(trace, layout), pct_str
end

# --------------------------------------------------------------------------------------
# --- MASTER RENDERER DISPATCHER ---
# --------------------------------------------------------------------------------------

"""
    ARTS_Render_DDEF(Models, X, Y, InNames, OutNames, Goals, R2s, Q2s, Opts, [Leaders_DF]) -> Vector{Dict}
Primary output orchestrator for generating all selected plot types.
"""
function ARTS_Render_DDEF(Models, X, Y, InNames, OutNames, Goals, R2s, Q2s, Opts, Leaders_DF::AbstractDataFrame=DataFrame())
    graphs = Dict{String,Any}[]
    graphs_lock = ReentrantLock()
    NumVars = size(X, 2)
    NumOut = length(OutNames)

    Combos = NumVars >= 2 ? collect(combinations(1:NumVars, 2)) : Vector{Int}[]

    tasks = []

    for m in 1:NumOut
        Models[m]["Status"] != "OK" && continue
        name = OutNames[m]

        # 1. Statistical Diagnostics
        if get(Opts, "Pareto", true)
            push!(tasks, Threads.@spawn begin
                p1 = ARTS_RenderPareto_DDEF(Models[m], name, R2s[m], Q2s[m])
                p2 = ARTS_RenderFit_DDEF(Y[:, m], ARTS_Predict_DDEF(Models[m], X), name)
                lock(graphs_lock) do
                    push!(graphs, Dict("Type" => "Pareto", "Title" => "Pareto: $name", "Plot" => p1))
                    push!(graphs, Dict("Type" => "Fit", "Title" => "Fit: $name", "Plot" => p2))
                end
            end)

        end

        # 2. Variable Interactions & Surface Mapping
        for c in Combos
            lbls = [InNames[c[1]], InNames[c[2]]]
            tag = "$(lbls[1])-$(lbls[2])"

            if get(Opts, "Surface", true)
                push!(tasks, Threads.@spawn begin
                    p1 = ARTS_RenderSurface_DDEF(Models[m], X, c, lbls, name)
                    p2 = ARTS_RenderContour_DDEF(Models[m], X, c, lbls, name)
                    lock(graphs_lock) do
                        push!(graphs, Dict("Type" => "Surface", "Title" => "RSM: $name ($tag)", "Plot" => p1))
                        push!(graphs, Dict("Type" => "Contour", "Title" => "Contour: $name ($tag)", "Plot" => p2))
                    end
                end)
            end

            if get(Opts, "Interaction", true)
                push!(tasks, Threads.@spawn begin
                    p1 = ARTS_RenderSlice_DDEF(Models[m], X, c, lbls, name)
                    p2 = ARTS_RenderTrend_DDEF(Models[m], X, Y[:, m], c, lbls, name)
                    lock(graphs_lock) do
                        push!(graphs, Dict("Type" => "Slice", "Title" => "Interact: $name ($tag)", "Plot" => p1))
                        push!(graphs, Dict("Type" => "Trend", "Title" => "Trend: $name ($tag)", "Plot" => p2))
                    end
                end)
            end
        end
    end

    # 3. Composite Sustainability & Design Space
    if get(Opts, "DesignSpace", true) && !isempty(Combos)
        for c in Combos
            lbls = [InNames[c[1]], InNames[c[2]]]
            if NumVars > 2
                iz = first(setdiff(1:NumVars, c))
                push!(lbls, InNames[iz])
            end

            push!(tasks, Threads.@spawn begin
                p1 = ARTS_RenderSpace_DDEF(Models, Goals, X, c, lbls, Leaders_DF)
                cand_plot, cand_pct = ARTS_RenderCandidates_DDEF(Models, Goals, X, c, lbls, Leaders_DF)
                lock(graphs_lock) do
                    push!(graphs, Dict("Type" => "DesignSpace", "Title" => "Design Space: $(lbls[1])-$(lbls[2])", "Plot" => p1))
                    push!(graphs, Dict("Type" => "Candidates", "Title" => "Candidates: $(lbls[1])-$(lbls[2])", "Plot" => cand_plot))
                end
            end)
        end
 
         # --- THE OPTIMAL ZONE ---
         if get(Opts, "GoldenZone", true) && NumVars >= 3
             push!(tasks, Threads.@spawn begin
                 p_gz, gz_pct = ARTS_RenderOptimalZone_DDEF(Models, Goals, X, InNames)
                 lock(graphs_lock) do
                     push!(graphs, Dict("Type" => "OptimalZone", "Title" => "Optimal Zone", "Plot" => p_gz))
                 end
             end)
         end
    end

    # Wait for all plotting threads to compute
    for t in tasks
        wait(t)
    end

    TypePriority = Dict(
        "Pareto" => 1,
        "Fit" => 2,
        "Surface" => 3,
        "Contour" => 4,
        "Slice" => 5,
        "Trend" => 6,
        "DesignSpace" => 7,
        "Candidates" => 8,
        "OptimalZone" => 9
    )
    sort!(graphs, by=g -> get(TypePriority, g["Type"], 99))

    return graphs
end


end # module Lib_Arts
