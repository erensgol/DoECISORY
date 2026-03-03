module Lib_Arts

# ======================================================================================
# DAISHODOE - LIB ARTS (VISUALIZATION & GRAPHICS MOTOR)
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
    ARTS_Downsample_DDEF

# --------------------------------------------------------------------------------------
# SECTION 1: THEME & VISUAL HELPERS
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

"""
    _base_layout(title; width, height) -> Layout
Internal helper to generate a standardized PlotlyJS layout with light theme support.
"""
function _base_layout(title::String; height=500)
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
        autosize=true,
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

# ── Smart Downsampling & Grid Limiter ──────────────────────────────────────

# Maximum safe grid points for browser rendering (N×N per plot)
const _MAX_GRID_POINTS = 2500   # 50×50 = 2500 points per surface
const _MAX_JSON_BYTES = 5_000_000  # ~5 MB per figure JSON

"""
    _adaptive_grid_N(preferred, max_total) -> Int
Returns a grid resolution N such that N×N ≤ max_total.
Preserves the user's preference when it fits.
"""
function _adaptive_grid_N(preferred::Int, max_total::Int=_MAX_GRID_POINTS)
    N = preferred
    while N * N > max_total && N > 5
        N -= 1
    end
    return N
end

"""
    ARTS_Downsample_DDEF(Z::Matrix, target_rows, target_cols) -> Matrix
Intelligent sub-sampling for oversized plot matrices.
Uses strided decimation to evenly sample the grid while preserving extrema.
"""
function ARTS_Downsample_DDEF(Z::Matrix{T}, target_rows::Int, target_cols::Int) where T
    nr, nc = size(Z)
    (nr ≤ target_rows && nc ≤ target_cols) && return Z

    row_stride = max(1, nr ÷ target_rows)
    col_stride = max(1, nc ÷ target_cols)

    row_idx = 1:row_stride:nr
    col_idx = 1:col_stride:nc

    # Always include the last row/col to preserve boundary behaviour
    row_idx = unique([collect(row_idx); nr])
    col_idx = unique([collect(col_idx); nc])

    Sys_Fast.FAST_Log_DDEF("ARTS", "DOWNSAMPLE",
        "Reduced $(nr)×$(nc) → $(length(row_idx))×$(length(col_idx))", "INFO")
    return Z[row_idx, col_idx]
end

"""
    ARTS_ExtractGoal_DDEF(Goal) -> Tuple
Extracts and normalises goal parameters from an objective dictionary.
Returns a tuple of (Min, Max, Target, is_max, is_min, Weight).
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
Implements Harrington's Desirability Function for multi-objective optimisation.
Maps physical response values to a dimensionless quality score (0.0 to 1.0).
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
# SECTION 2: LINEAR PLOTS (PARETO, ACTUAL VS PRED)
# --------------------------------------------------------------------------------------

"""
    ARTS_RenderPareto_DDEF(Model, OutName, R2_Adj, Q2) -> Plot
Renders a horizontal bar chart showing standardized effects of factors.
"""
function ARTS_RenderPareto_DDEF(Model::Dict, OutName::String, R2_Adj::Float64, R2_Pred::Float64)
    TH = THEME
    Coefs = Model["Coefs"]
    Names = get(Model, "TermNames", ["T$i" for i in eachindex(Coefs)])
    t_Stats = get(Model, "t_Stats", Coefs) # Fallback to coefs if t-stats missing for any reason
    N_Samples = get(Model, "N_Samples", length(Coefs) + 5)

    # Exclude Intercept (Index 1)
    clean_eff = @view t_Stats[2:end]
    clean_nms = @view Names[2:end]
    # Check if we should fallback to Coefs signs if t_Stats is NaN 
    clean_signs = any(isnan, clean_eff) ? sign.(@view Coefs[2:end]) : sign.(clean_eff)

    # Use standard effect magnitudes 
    magnitudes = any(isnan, clean_eff) ? abs.(@view Coefs[2:end]) : abs.(clean_eff)

    perm = sortperm(magnitudes)
    sorted_mag = magnitudes[perm]
    sorted_nms = clean_nms[perm]
    sorted_sgn = clean_signs[perm]

    # Separate traces for Positive / Negative 
    pos_idx = findall(x -> x >= 0, sorted_sgn)
    neg_idx = findall(x -> x < 0, sorted_sgn)

    traces = GenericTrace[]

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

    layout = _base_layout("Factor Importance: $OutName (R²Adj: $r2_str | Q²: $q2_str)")
    layout[:xaxis][:title] = "Magnitude of Standardized Effect (t-value)"
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
Generates a scatter plot comparing experimental results with model predictions.
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

    layout = _base_layout("Prediction Accuracy: $OutName")
    layout[:xaxis][:title] = "Experimental (Recorded)"
    layout[:yaxis][:title] = "Predicted (Model)"
    layout[:showlegend] = false
    return Plot([t_data, t_ideal], layout)
end

# --------------------------------------------------------------------------------------
# SECTION 3: RSM VISUALIZATION (SURFACE & CONTOUR)
# --------------------------------------------------------------------------------------

"""
    _predict_internal(Model, X) -> Vector{Float64}
Internal evaluator to avoid circular module dependencies with Lib_Vise.
"""
function _predict_internal(Model, X)
    Beta = Model["Coefs"]
    Type = get(Model, "ModelType", "quadratic")

    N, K = size(X)
    if occursin("linear", Type)
        Xd = hcat(ones(N), X)
        return Xd * Beta
    else
        combos = collect(combinations(1:K, 2))
        n_inter = length(combos)
        Xd = Matrix{Float64}(undef, N, 1 + K + n_inter + K)
        fill!(view(Xd, :, 1), 1.0)
        copyto!(view(Xd, :, 2:K+1), X)

        # Parallelise expansion if large enough
        if N > 1000
            Threads.@threads for i in 1:n_inter
                c1, c2 = combos[i]
                @views @. Xd[:, K+1+i] = X[:, c1] * X[:, c2]
            end
        else
            @inbounds for (i, (c1, c2)) in enumerate(combos)
                Xd[:, K+1+i] .= view(X, :, c1) .* view(X, :, c2)
            end
        end

        @views @. Xd[:, K+n_inter+2:end] = abs2(X)
        return Xd * Beta
    end
end

"""
    _build_grid(X, ix, iy, N) -> (x1, x2, Grid)
Shared helper to construct a prediction grid for surface/contour plots.
"""
function _build_grid(X::Matrix{Float64}, ix::Int, iy::Int, N_requested::Int)
    # Adaptive grid limiter
    N = _adaptive_grid_N(N_requested)
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
    x1, x2, Grid = _build_grid(X, ix, iy, N_Grid)

    Z = reshape(_predict_internal(Model, Grid), N_Grid, N_Grid)'

    trace = surface(; x=collect(x1), y=collect(x2), z=Z, colorscale=VIRIDIS_SCALE,
        contours=attr(z=attr(show=true, usecolormap=true, project_z=true)))

    layout = _base_layout("Response Surface: $OutName")
    layout[:scene] = attr(xaxis=attr(title=Lbls[1]), yaxis=attr(title=Lbls[2]), zaxis=attr(title=OutName))
    layout[:margin] = attr(l=0, r=0, b=0, t=40)
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
    x1, x2, Grid = _build_grid(X, ix, iy, N)

    Z = reshape(_predict_internal(Model, Grid), N, N)'

    trace = contour(; x=collect(x1), y=collect(x2), z=Z, colorscale=VIRIDIS_SCALE,
        contours=attr(coloring="heatmap", showlabels=true))

    layout = _base_layout("Contour Projection: $OutName")
    layout[:xaxis][:title] = Lbls[1]
    layout[:yaxis][:title] = Lbls[2]
    return Plot(trace, layout)
end

# --------------------------------------------------------------------------------------
# SECTION 4: ADVANCED ANALYTICS (SLICES, TRENDS, DESIGN SPACE)
# --------------------------------------------------------------------------------------

"""
    ARTS_RenderSlice_DDEF(Model, X, Idx, Lbls, OutName) -> Plot
Renders interaction slices for two variables.
Shows how Response vs Var1 changes at Min/Mean/Max levels of Var2.
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

        z = _predict_internal(Model, Grid)
        push!(traces, scatter(; x=x1, y=z, mode="lines",
            name="$(Lbls[2])=$(y_names[i])",
            line=attr(color=colors[i], dash=styles[i], width=2)))
    end

    layout = _base_layout("Interaction Slice: $OutName")
    layout[:xaxis][:title] = Lbls[1]
    layout[:yaxis][:title] = OutName
    return Plot(traces, layout)
end

"""
    ARTS_RenderTrend_DDEF(Model, X, Y_Real, Idx, Lbls, OutName) -> Plot
Renders main effect trend line alongside raw experimental scatter points.
"""
function ARTS_RenderTrend_DDEF(Model::Dict, X::Matrix{Float64}, Y_Real::Vector{Float64},
    Idx::Vector{Int}, Lbls::Vector{String}, OutName::String)
    TH = THEME
    ix = Idx[1]
    N = 35

    xr = collect(range(minimum(view(X, :, ix)), maximum(view(X, :, ix)); length=N))
    Grid = repeat(mean(X; dims=1), N)
    Grid[:, ix] .= xr

    y_trend = _predict_internal(Model, Grid)

    t_line = scatter(; x=xr, y=y_trend, mode="lines", name="Model Trend",
        line=attr(color=TH.Text, dash="dash"))

    t_data = scatter(; x=X[:, ix], y=Y_Real, mode="markers", name="Experimental",
        marker=attr(color=TH.Green, size=8, line=attr(width=1, color=TH.TextBright)))

    layout = _base_layout("Main Effect: $(Lbls[1]) -> $OutName")
    layout[:xaxis][:title] = Lbls[1]
    layout[:yaxis][:title] = OutName
    return Plot([t_line, t_data], layout)
end

"""
    ARTS_RenderSpace_DDEF(...) and ARTS_RenderCandidates_DDEF(...)
Visualises the optimisation space with and without thresholding.
"""
function ARTS_RenderSpace_DDEF(Models, Goals, X::Matrix{Float64}, Idx::Vector{Int}, Lbls::Vector{String}, Best_Point::Vector{Float64}=Float64[])
    return _render_space_impl(Models, Goals, X, Idx, Lbls, Best_Point, false)[1]
end

function ARTS_RenderCandidates_DDEF(Models, Goals, X::Matrix{Float64}, Idx::Vector{Int}, Lbls::Vector{String}, Best_Point::Vector{Float64}=Float64[])
    p, pct_str = _render_space_impl(Models, Goals, X, Idx, Lbls, Best_Point, true)
    return p, pct_str
end

function _render_space_impl(Models, Goals, X::Matrix{Float64}, Idx::Vector{Int}, Lbls::Vector{String}, Best_Point::Vector{Float64}, is_candidate::Bool)
    ix, iy = Idx[1], Idx[2]

    N = _adaptive_grid_N(80, 10000)
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
            preds = _predict_internal(Models[m], Grid)
            goal_tup = parsed_goals[m]

            # Use multi-threading for grid pixel evaluation
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
            if val > 1e-6
                push!(all_non_zero, val)
            end
        end
    end

    if isempty(all_non_zero)
        thresh = 1.0
        pct = 0.0
    else
        # Top quartile of scores (Top 25% of non-zero values)
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
    layout = _base_layout(plotTitle)
    layout[:height] = 500
    layout[:scene] = attr(
        xaxis=attr(title=Lbls[1]),
        yaxis=attr(title=Lbls[2]),
        zaxis=attr(title=iz > 0 ? (length(Lbls) > 2 ? Lbls[3] : "Slice Domain") : "Level"),
        camera=attr(eye=attr(x=1.5, y=1.5, z=0.5)),
        aspectmode="cube"
    )
    return Plot(traces, layout), pct_str
end

# --------------------------------------------------------------------------------------
# SECTION 5: MASTER RENDERER DISPATCHER
# --------------------------------------------------------------------------------------

"""
    ARTS_Render_DDEF(Models, X, Y, InNames, OutNames, Goals, R2s, Q2s, Opts, Best_Point) -> Vector{Dict}
The primary output generator. Orchestrates the creation of all selected plot types.
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
                p2 = ARTS_RenderFit_DDEF(Y[:, m], _predict_internal(Models[m], X), name)
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
                p1 = ARTS_RenderSpace_DDEF(Models, Goals, X, c, lbls, Best_Point)
                cand_plot, cand_pct = ARTS_RenderCandidates_DDEF(Models, Goals, X, c, lbls, Best_Point)
                lock(graphs_lock) do
                    push!(graphs, Dict("Type" => "DesignSpace", "Title" => "Design Space: $(lbls[1])-$(lbls[2])", "Plot" => p1))
                    push!(graphs, Dict("Type" => "Candidates", "Title" => "Optimal Solution Space: $(cand_pct)% of Total, $(lbls[1])-$(lbls[2])", "Plot" => cand_plot))
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
        "Candidates" => 8
    )
    sort!(graphs, by=g -> get(TypePriority, g["Type"], 99))

    return graphs
end

end # module
