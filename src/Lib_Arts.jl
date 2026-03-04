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
using Main.Sys_Fast

export ARTS_RenderPareto_DDEF, ARTS_RenderFit_DDEF, ARTS_RenderSurface_DDEF,
    ARTS_RenderContour_DDEF, ARTS_RenderSlice_DDEF, ARTS_RenderTrend_DDEF,
    ARTS_RenderSpace_DDEF, ARTS_RenderCandidates_DDEF, ARTS_Render_DDEF,
    ARTS_GetTheme_DDEF, ARTS_CalcDesirability_DDEF, ARTS_ExtractGoal_DDEF,
    ARTS_Downsample_DDEF, ARTS_RenderGoldenZone_DDEF, ARTS_RenderInteractionMatrix_DDEF,
    ARTS_BaseLayout_DDEF, ARTS_Predict_DDEF, ARTS_BuildGrid_DDEF,
    ARTS_AdaptiveGridN_DDEF, ARTS_RenderSpaceImpl_DDEF

# --------------------------------------------------------------------------------------
# --- INTERFACE LAYOUT & THEME ---
# --------------------------------------------------------------------------------------

# Theme as a module-level const for zero-alloc access
const THEME = (
    Magenta="#440154",
    Yellow="#FDE725",
    Green="#5EC962",
    Cyan="#21918C",
    Red="#FF0000",
    Blue="#3B528B",
    Purple="#440154",
    Text="#666666",
    TextBright="#000000",
    Grid="#E6E6E6",
    Bg="#FFFFFF",
    Font="Inter, sans-serif",
)

"""
    ARTS_GetTheme_DDEF() -> NamedTuple
Returns the global visual identity of the application.
"""
ARTS_GetTheme_DDEF() = THEME

# --- GRAPHICAL STANDARD SCALES ---

const _STANDARD_HEIGHT = 500
const _SCENE_HEIGHT = 550

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

# High-fidelity Viridis color mapping for surfaces and heatmaps
const VIRIDIS_SCALE = [
    [0.0, "#440154"], [0.25, "#3B528B"], [0.5, "#21918C"],
    [0.75, "#5EC962"], [1.0, "#FDE725"],
]

# --- SMART DOWNSAMPLING & GRID LIMITER ---

# Maximum safe grid points for browser rendering (N×N per plot)
const _MAX_GRID_POINTS = 2500   # 50×50 = 2500 points per surface
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
    Weight = Float64(get(Goal, "Weight", 1.0))
    is_max = occursin("Maximise", Type)
    is_min = occursin("Minimise", Type)
    return (G_Min, G_Max, G_Tgt, is_max, is_min, Weight)
end

"""
    ARTS_CalcDesirability_DDEF(Val, GoalTup) -> Float64
Harrington's Desirability Function for multi-objective optimisation mapping.
"""
function ARTS_CalcDesirability_DDEF(Val::Float64, GoalTup::Tuple)
    G_Min, G_Max, G_Tgt, is_max, is_min, _ = GoalTup
    if is_max
        return Val >= G_Tgt ? 1.0 : Val <= G_Min ? 0.0 : (Val - G_Min) / (G_Tgt - G_Min)
    elseif is_min
        return Val <= G_Tgt ? 1.0 : Val >= G_Max ? 0.0 : (G_Max - Val) / (G_Max - G_Tgt)
    else  # Nominal
        (Val < G_Min || Val > G_Max) && return 0.0
        return Val < G_Tgt ? (Val - G_Min) / (G_Tgt - G_Min) : (G_Max - Val) / (G_Max - G_Tgt)
    end
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
Constructs a prediction grid for surface/contour plots centered on factor means.
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
    N_Grid = 35
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
    N = 35
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

    x1 = collect(range(minimum(view(X, :, ix)), maximum(view(X, :, ix)); length=35))
    y_vals = (minimum(view(X, :, iy)), mean(view(X, :, iy)), maximum(view(X, :, iy)))
    y_names = ("Min", "Mean", "Max")
    styles = ("solid", "dash", "solid")
    colors = (TH.Magenta, TH.Cyan, TH.Yellow)

    col_means = vec(mean(X; dims=1))
    traces = GenericTrace[]

    for i in eachindex(y_vals)
        Grid = repeat(col_means', length(x1))
        Grid[:, ix] .= x1
        Grid[:, iy] .= y_vals[i]

        z = ARTS_Predict_DDEF(Model, Grid)
        push!(traces, scatter(; x=x1, y=z, mode="lines",
            name="$(Lbls[2])=$(y_names[i])",
            line=attr(color=colors[i], dash=styles[i], width=2)))
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
    N = 35

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
function ARTS_RenderSpace_DDEF(Models, Goals, X::Matrix{Float64}, Idx::Vector{Int}, Lbls::Vector{String}, Best_Point::Vector{Float64}=Float64[])
    return ARTS_RenderSpaceImpl_DDEF(Models, Goals, X, Idx, Lbls, Best_Point, false)[1]
end

"""
    ARTS_RenderCandidates_DDEF(Models, Goals, X, Idx, Lbls, [Best_Point]) -> (Plot, PctString)
Visualises the top quartile of the desirability space (Optimal Solution Space).
"""
function ARTS_RenderCandidates_DDEF(Models, Goals, X::Matrix{Float64}, Idx::Vector{Int}, Lbls::Vector{String}, Best_Point::Vector{Float64}=Float64[])
    p, pct_str = ARTS_RenderSpaceImpl_DDEF(Models, Goals, X, Idx, Lbls, Best_Point, true)
    return p, pct_str
end

"""
    ARTS_RenderSpaceImpl_DDEF(Models, Goals, X, Idx, Lbls, Best_Point, is_candidate) -> (Plot, PctString)
Core rendering logic for desirability-based solution spaces.
"""
function ARTS_RenderSpaceImpl_DDEF(Models, Goals, X::Matrix{Float64}, Idx::Vector{Int}, Lbls::Vector{String}, Best_Point::Vector{Float64}, is_candidate::Bool)
    ix, iy = Idx[1], Idx[2]

    N = ARTS_AdaptiveGridN_DDEF(80, 10000)
    K = size(X, 2)

    x1 = collect(range(minimum(view(X, :, ix)), maximum(view(X, :, ix)); length=N))
    x2 = collect(range(minimum(view(X, :, iy)), maximum(view(X, :, iy)); length=N))

    iz = 0
    z_vals = [0.0]
    if K > 2
        iz = first(setdiff(1:K, Idx))
        if !isempty(Best_Point)
            z_vals = [minimum(view(X, :, iz)), Best_Point[iz], maximum(view(X, :, iz))]
        else
            z_vals = [minimum(view(X, :, iz)), mean(view(X, :, iz)), maximum(view(X, :, iz))]
        end
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
        ScoreMat = reshape(Scores .^ pow_factor, N, N)'
        all_scores[s] = ScoreMat

        global_max = max(global_max, maximum(ScoreMat))
        global_min = min(global_min, minimum(ScoreMat))
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

        if any(!isnan, Masked)
            alpha_val = (s == 2 || iz == 0) ? (is_candidate ? 0.85 : 0.70) : (is_candidate ? 0.35 : 0.20)
            trace_name = (s == 2 && K > 2 && !isempty(Best_Point)) ? "Level: $(round(zv; digits=2))" : "Slice $s"

            push!(traces, surface(;
                x=x1, y=x2, z=Z_layer,
                surfacecolor=Masked,
                colorscale=VIRIDIS_SCALE,
                cmin=is_candidate ? thresh : global_min,
                cmax=global_max,
                showscale=(s == 1),
                opacity=alpha_val,
                name=trace_name,
                showlegend=false,
                contours=attr(z=attr(show=true, usecolormap=true, width=3)),
            ))
        end
    end

    if !isempty(Best_Point)
        bx, by = Best_Point[ix], Best_Point[iy]
        bz = iz > 0 ? Best_Point[iz] : 0.0
        th = THEME
        push!(traces, scatter3d(;
            x=[bx], y=[by], z=[bz],
            mode="markers+text",
            marker=attr(size=3, color=th.Red, symbol="diamond", line=attr(color=th.Bg, width=1)),
            name="Leader",
            text=[" Leader "],
            textposition="top center",
            textfont=attr(color=th.TextBright, size=11, family=th.Font)
        ))
    end

    plotTitle = is_candidate ? "Optimal Solution Space ($pct_str% of Total Space)" : "Design Space: $(Lbls[1]) vs $(Lbls[2])"
    layout = ARTS_BaseLayout_DDEF(plotTitle; height=_SCENE_HEIGHT)
    layout[:scene] = attr(
        xaxis=attr(title=Lbls[1]),
        yaxis=attr(title=Lbls[2]),
        zaxis=attr(title=iz > 0 ? (length(Lbls) > 2 ? Lbls[3] : "Slice Domain") : "Level"),
        camera=attr(eye=attr(x=1.5, y=1.5, z=0.5)),
        aspectmode="cube",
        domain=attr(x=[0.0, 0.88], y=[0.0, 1.0]),
    )
    layout[:margin] = attr(l=10, r=80, b=10, t=40)
    return Plot(traces, layout), pct_str
end

"""
    ARTS_RenderGoldenZone_DDEF(Models, Goals, X, InNames) -> Plot
Renders a 3D isometric volume of the 'Golden Zone' (Top 10% Desirability).
"""
function ARTS_RenderGoldenZone_DDEF(Models, Goals, X::Matrix{Float64}, InNames::Vector{String})
    TH = THEME
    N = 25 # Coarser grid for volume stability
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
    Scores = Scores .^ pow

    # Target the top 10% desirable space
    valid_scores = Scores[Scores.>1e-6]
    thresh = isempty(valid_scores) ? 0.9 : quantile(valid_scores, 0.90)

    trace = volume(;
        x=Grid[:, 1], y=Grid[:, 2], z=Grid[:, 3],
        value=Scores,
        isomin=thresh,
        isomax=maximum(Scores),
        opacity=0.3,
        surface_count=5,
        colorscale=VIRIDIS_SCALE,
        colorbar=attr(title="Quality Index", len=0.6)
    )

    layout = ARTS_BaseLayout_DDEF("The Golden Zone (Top 10% Composite Desirability)"; height=_SCENE_HEIGHT)
    layout[:scene] = attr(
        xaxis=attr(title=InNames[1]),
        yaxis=attr(title=InNames[2]),
        zaxis=attr(title=InNames[3]),
        aspectmode="cube"
    )
    return Plot(trace, layout)
end

# --------------------------------------------------------------------------------------
# --- MASTER RENDERER DISPATCHER ---
# --------------------------------------------------------------------------------------

"""
    ARTS_Render_DDEF(Models, X, Y, InNames, OutNames, Goals, R2s, Q2s, Opts, [Best_Point]) -> Vector{Dict}
Primary output orchestrator for generating all selected plot types.
"""
function ARTS_Render_DDEF(Models, X, Y, InNames, OutNames, Goals, R2s, Q2s, Opts, Best_Point=Float64[])
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

            # 1.5. Factor Synergy Matrix (Interaction Heatmap)
            push!(tasks, Threads.@spawn begin
                p_synergy = ARTS_RenderInteractionMatrix_DDEF(Models[m], InNames)
                lock(graphs_lock) do
                    push!(graphs, Dict("Type" => "Synergy", "Title" => "Synergy: $name", "Plot" => p_synergy))
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
                p1 = ARTS_RenderSpace_DDEF(Models, Goals, X, c, lbls, Best_Point)
                cand_plot, cand_pct = ARTS_RenderCandidates_DDEF(Models, Goals, X, c, lbls, Best_Point)
                lock(graphs_lock) do
                    push!(graphs, Dict("Type" => "DesignSpace", "Title" => "Design Space: $(lbls[1])-$(lbls[2])", "Plot" => p1))
                    push!(graphs, Dict("Type" => "Candidates", "Title" => "Optimal Solution Space: $(cand_pct)% of Total, $(lbls[1])-$(lbls[2])", "Plot" => cand_plot))
                end
            end)
        end

        # --- THE GOLDEN ZONE ---
        if get(Opts, "GoldenZone", true) && NumVars >= 3
            push!(tasks, Threads.@spawn begin
                p_gz = ARTS_RenderGoldenZone_DDEF(Models, Goals, X, InNames)
                lock(graphs_lock) do
                    push!(graphs, Dict("Type" => "GoldenZone", "Title" => "The Golden Zone (3D Landscape)", "Plot" => p_gz))
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
        "GoldenZone" => 0 # Primary highlight
    )
    sort!(graphs, by=g -> get(TypePriority, g["Type"], 99))

    return graphs
end

"""
    ARTS_RenderInteractionMatrix_DDEF(Model, InNames) -> Plot
Renders a synergistic heatmap showing the magnitude of interaction effects.
"""
function ARTS_RenderInteractionMatrix_DDEF(Model::Dict, InNames::Vector{String})
    TH = THEME
    K = length(InNames)
    K < 2 && return Plot([], ARTS_BaseLayout_DDEF("Visualisation requires at least 2 variables."))

    coefs = Model["Coefs"]
    names = Model["TermNames"]
    Mat = zeros(K, K)

    # Diagonal: Linear components
    for i in 1:K
        idx = findfirst(==(InNames[i]), names)
        !isnothing(idx) && (Mat[i, i] = abs(coefs[idx]))
    end

    # Off-diagonal: Interaction components (A × B)
    for i in 1:K, j in (i+1):K
        term = "$(InNames[i]) × $(InNames[j])"
        rev_term = "$(InNames[j]) × $(InNames[i])"
        idx = findfirst(n -> n == term || n == rev_term, names)
        if !isnothing(idx)
            val = abs(coefs[idx])
            Mat[i, j] = val
            Mat[j, i] = val
        end
    end

    trace = heatmap(; z=Mat, x=InNames, y=InNames, colorscale=VIRIDIS_SCALE, showscale=true)

    layout = ARTS_BaseLayout_DDEF("Inter-Factor Synergistic Landscape")
    layout[:xaxis][:title] = "Factor A"
    layout[:yaxis][:title] = "Factor B"
    return Plot(trace, layout)
end

end # module Lib_Arts
