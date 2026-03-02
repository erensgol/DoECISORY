module Lib_Vise

# ======================================================================================
# DAISHODOE - LIB VISE (STATISTICAL ANALYSIS ENGINE)
# ======================================================================================
# Purpose: Advanced regression (OLS), cross-validation (Q²), and
#          multithreaded search for optimal experimental coordinates.
# Module Tag: VISE
# ======================================================================================

using GLM
using DataFrames
using Combinatorics
using Base.Threads
using LinearAlgebra
using Statistics
using Distributions
using Printf
using Dates
using Main.Sys_Fast
using Main.Lib_Arts

export VISE_Regress_DDEF, VISE_GridSearch_DDEF, VISE_ExpandDesign_DDEF,
    VISE_Predict_DDEF, VISE_Execute_DDEF, VISE_CrossValidate_DDEF,
    VISE_GetTermNames_DDEF, VISE_ClampIndex_DDEF, VISE_ApplyRadioDecay_DDEF

# --------------------------------------------------------------------------------------
# SECTION 1: PHYSICAL CORRECTIONS & MATH MODELS
# --------------------------------------------------------------------------------------

"""
    VISE_ApplyRadioDecay_DDEF(RawValue, HalfLife, HalfLifeUnit, DeltaTHours) -> Float64
Applies mathematical decay correction for radioactive elements.
Formula: N = N0 * exp(-lambda * t) where lambda = ln(2) / T_1/2.
We reverse-calculate the zero-time activity (N0 = N / exp(-lambda * t)).
"""
function VISE_ApplyRadioDecay_DDEF(RawValue::Float64, HalfLife::Float64, HalfLifeUnit::String, DeltaTHours::Float64)
    HalfLife <= 0.0 && return RawValue

    # Normalise Half-Life to Hours
    unit_upper = uppercase(strip(HalfLifeUnit))
    hl_hours = HalfLife
    if occursin("MIN", unit_upper)
        hl_hours = HalfLife / 60.0
    elseif occursin("DAY", unit_upper)
        hl_hours = HalfLife * 24.0
    elseif occursin("YEAR", unit_upper) || occursin("YR", unit_upper)
        hl_hours = HalfLife * 24.0 * 365.25
    end

    hl_hours <= 0.0 && return RawValue

    lambda = log(2) / hl_hours
    decay_factor = exp(-lambda * DeltaTHours)

    # Avoid extreme inflation
    decay_factor < 1e-6 && return RawValue

    return RawValue / decay_factor
end

# --------------------------------------------------------------------------------------
# SECTION 1: DESIGN MATRIX EXPANSION & NAMING
# --------------------------------------------------------------------------------------

"""
    VISE_GetTermNames_DDEF(InNames, ModelType) -> Vector{String}
Generates human-readable names for regression terms (e.g., "A × B", "A²").
"""
function VISE_GetTermNames_DDEF(InNames::Vector{String}, ModelType::String)
    K = length(InNames)
    names = Vector{String}(undef, 0)
    push!(names, "Intercept")
    append!(names, InNames)

    occursin("linear", lowercase(ModelType)) && return names

    # Quadratic: interactions then squared terms
    for (c1, c2) in combinations(1:K, 2)
        push!(names, "$(InNames[c1]) × $(InNames[c2])")
    end
    for n in InNames
        push!(names, "$(n)²")
    end
    return names
end

"""
    VISE_ExpandDesign_DDEF(X, ModelType) -> Matrix{Float64}
Expands raw factor matrix into a design matrix (intercept + linear + interactions + quadratic).
"""
function VISE_ExpandDesign_DDEF(X::AbstractMatrix{Float64}, ModelType::String)
    N, K = size(X)
    occursin("linear", lowercase(ModelType)) && return hcat(ones(N), X)

    combos = collect(combinations(1:K, 2))
    n_inter = length(combos)

    # Pre-allocate full design matrix: [1 | X | interactions | X²]
    Xd = Matrix{Float64}(undef, N, 1 + K + n_inter + K)
    fill!(view(Xd, :, 1), 1.0)
    copyto!(view(Xd, :, 2:K+1), X)

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

    return Xd
end

# --------------------------------------------------------------------------------------
# SECTION 2: REGRESSION ENGINE (OLS CORE + RIDGE FALLBACK)
# --------------------------------------------------------------------------------------

"""
    VISE_ClampIndex_DDEF(idx, len) -> Int
Clamps an index to the valid range [1, len].
Prevents BoundsError from floating-point index drift.
"""
VISE_ClampIndex_DDEF(idx::Integer, len::Integer) = clamp(Int(idx), 1, Int(len))
VISE_ClampIndex_DDEF(idx::AbstractFloat, len::Integer) = clamp(round(Int, idx), 1, Int(len))

"""
    VISE_Regress_DDEF(X, Y, ModelType; InNames) -> Dict
Strict OLS regression without data manipulation techniques. 
Fails explicitly and mathematically correctly if data is rank-deficient or collinear.
Returns a model dictionary containing Coefs, R², Adjusted R², and RMSE.
"""
function VISE_Regress_DDEF(X_Raw::AbstractMatrix{Float64}, Y::AbstractVector{Float64},
    ModelType::String; InNames::Vector{String}=String[])
    X_Design = VISE_ExpandDesign_DDEF(X_Raw, ModelType)

    try
        # ── Strict Scientific OLS Regression ───────────────────────────────────
        n, p = size(X_Design)

        # Condition Number Check (Matrix Health)
        if cond(X_Design) > 1e10
            return Dict("Status" => "FAIL", "Error" => "Pre-Flight Matrix Health Check Failed: Design matrix condition number > 1e10. There may be perfect correlation between inputs or a flawed experimental design.")
        end

        if n < p
            throw(ArgumentError("Insufficient experimental data: Number of observations (\$n) is less than the number of model parameters (\$p)."))
        end

        # Explicit rank check to prevent data manipulation via pseudo-inverse
        if rank(X_Design) < p
            throw(ArgumentError("Experimental design matrix is linearly dependent (Singular/Collinear). Model cannot be established."))
        end

        Beta = X_Design \ Y

        Y_Pred = X_Design * Beta
        Resid = Y .- Y_Pred
        SSE = sum(abs2, Resid)
        SST = var(Y) * (length(Y) - 1)

        R2 = SST > 1e-9 ? 1.0 - SSE / SST : 0.0
        isnan(R2) && (R2 = 0.0)

        n, p = size(X_Design)
        R2_Adj = n > p ? 1.0 - (1.0 - R2) * ((n - 1) / (n - p)) : 0.0
        RMSE = n > p ? sqrt(SSE / (n - p)) : 0.0

        F_Stat, P_Value = NaN, NaN
        P_Coefs = fill(NaN, p)
        SE_Coefs = fill(NaN, p)

        t_Stats = fill(NaN, p)

        try
            if n > p && SST > 1e-9 && SSE > 1e-9
                MSR = (SST - SSE) / max(1, p - 1)

                MSE = SSE / (n - p)
                if MSE > 0.0
                    F_Stat = MSR / MSE
                    P_Value = 1.0 - cdf(FDist(max(1, p - 1), n - p), F_Stat)

                    # Strict Matrix Inversion for Standard Errors
                    Var_Beta = MSE * inv(X_Design' * X_Design)
                    SE_Coefs = sqrt.(max.(0.0, diag(Var_Beta)))
                    t_Stats = Beta ./ max.(SE_Coefs, 1e-15)   # Guard /0
                    P_Coefs = 2.0 .* (1.0 .- cdf.(TDist(n - p), abs.(t_Stats)))
                end
            end
        catch
            Sys_Fast.FAST_Log_DDEF("VISE", "ANOVA_WARN", "Failed to compute exact p-values", "WARN")
        end

        TNames = isempty(InNames) ?
                 ["Term $i" for i in 1:length(Beta)] :
                 VISE_GetTermNames_DDEF(InNames, ModelType)

        return Dict(
            "Coefs" => Beta, "TermNames" => TNames,
            "R2" => R2, "R2_Adj" => R2_Adj,
            "RMSE" => RMSE, "F_Stat" => F_Stat,
            "P_Value" => P_Value, "P_Coefs" => P_Coefs,
            "SE_Coefs" => SE_Coefs, "t_Stats" => t_Stats,
            "ModelType" => ModelType, "N_Samples" => n,
            "Status" => "OK",
        )
    catch e
        Sys_Fast.FAST_Log_DDEF("VISE", "REGRESS_ERROR", sprint(showerror, e, catch_backtrace()), "FAIL")
        return Dict("Status" => "FAIL", "Error" => string(e))
    end
end

"""
    VISE_Predict_DDEF(Model, X_New) -> Vector{Float64}
Evaluates the fitted regression model on a new set of data points.
"""
function VISE_Predict_DDEF(Model::Dict, X_New::AbstractMatrix{Float64})
    get(Model, "Status", "FAIL") != "OK" && return zeros(size(X_New, 1))
    return VISE_ExpandDesign_DDEF(X_New, Model["ModelType"]) * Model["Coefs"]
end

# --------------------------------------------------------------------------------------
# SECTION 3: VALIDATION (CROSS-VALIDATION & Q²)
# --------------------------------------------------------------------------------------

"""
    VISE_CrossValidate_DDEF(X, Y, ModelType) -> Float64
Calculates Predicted R² (Q²) using the PRESS statistic.
Uses the Hat Matrix shortcut: e_press(i) = Resid_i / (1 - h_ii).
"""
function VISE_CrossValidate_DDEF(X_Raw::AbstractMatrix{Float64}, Y::AbstractVector{Float64},
    ModelType::String)
    N = length(Y)
    N < 4 && return NaN

    X_Design = VISE_ExpandDesign_DDEF(X_Raw, ModelType)

    try
        F = qr(X_Design)
        Beta = F \ Y
        Resid = Y .- (X_Design * Beta)
        h_ii = vec(sum(abs2, Matrix(F.Q); dims=2))

        denom = max.(1.0 .- h_ii, 1e-6)
        PRESS = sum(abs2, Resid ./ denom)

        SST = var(Y) * (N - 1)
        return SST < 1e-9 ? 0.0 : 1.0 - PRESS / SST
    catch
        return NaN
    end
end

# --------------------------------------------------------------------------------------
# SECTION 4: MULTITHREADED GRID SEARCH OPTIMISATION
# --------------------------------------------------------------------------------------

"""
    VISE_GridSearch_DDEF(Models, Goals, Bounds; Steps=21) -> (X, Y_Pred, Scores)
Performs a high-density grid search across the factor space to find the 'Sweet Spot'.
Uses multithreading for desirability function evaluation.
"""
function VISE_GridSearch_DDEF(Models::AbstractVector, Goals::AbstractVector,
    X_Bounds::AbstractMatrix{Float64}; Steps::Int=21)
    Dim = size(X_Bounds, 1)

    # Thread-aware density balancing
    compute_threads = Sys_Fast.FAST_GetComputeThreads_DDEF()
    max_pts = compute_threads >= 4 ? 2_000_000 : 500_000  # Smaller grids on fewer threads

    eff_steps = Steps
    while eff_steps^Dim > max_pts && eff_steps > 3
        eff_steps -= 2
    end
    Sys_Fast.FAST_Log_DDEF("VISE", "GRID_CONFIG",
        "Grid: $(eff_steps)^$Dim = $(eff_steps^Dim) pts | Compute threads: $compute_threads", "INFO")

    # Generate coordinate ranges
    Ranges = [range(X_Bounds[i, 1], X_Bounds[i, 2]; length=eff_steps) for i in 1:Dim]

    # 1. Point Collection (vectorized via product iterator)
    Iter = Iterators.product(Ranges...)
    NumPoints = length(Iter)
    Candidates = Matrix{Float64}(undef, NumPoints, Dim)

    @inbounds for (i, pt) in enumerate(Iter)
        for d in 1:Dim
            Candidates[i, d] = pt[d]
        end
    end

    # 2. Design Matrix (computed once for the reference model type)
    RefType = isempty(Models) ? "quadratic" : get(Models[1], "ModelType", "quadratic")
    X_Design = VISE_ExpandDesign_DDEF(Candidates, RefType)

    NumModels = length(Models)
    Predictions = zeros(Float64, NumPoints, NumModels)
    Active_Flags = falses(NumModels)

    # 3. Parallel Prediction (BLAS + thread-level)
    # Use capped compute thread pool
    Threads.@threads for m in 1:NumModels
        Mod = Models[m]
        Goal = Goals[m]
        Mod["Status"] != "OK" && continue

        Beta = Mod["Coefs"]::Vector{Float64}
        local_pred = zeros(Float64, NumPoints)

        if get(Mod, "ModelType", "quadratic") != RefType
            Xd_Local = VISE_ExpandDesign_DDEF(Candidates, Mod["ModelType"])
            mul!(local_pred, Xd_Local, Beta)
        else
            mul!(local_pred, X_Design, Beta)
        end
        Predictions[:, m] = local_pred

        Active_Flags[m] = true
    end

    # 4. Multi-threaded Composite Scoring (Point-level Parallelism)
    active_idx = findall(Active_Flags)
    if isempty(active_idx)
        Scores = ones(NumPoints)
    else
        Scores = Vector{Float64}(undef, NumPoints)

        weight_sum = 0.0
        for m_idx in active_idx
            weight_sum += Float64(get(Models[m_idx]["Goal"], "Weight", 1.0))
        end
        pow = weight_sum > 0.0 ? (1.0 / weight_sum) : 1.0

        parsed_goals = [Lib_Arts.ARTS_ExtractGoal_DDEF(Models[m]["Goal"]) for m in 1:NumModels]

        Threads.@threads for i in 1:NumPoints
            s = 1.0
            @inbounds for m_idx in active_idx
                val = Predictions[i, m_idx]
                gtup = parsed_goals[m_idx]
                d = Lib_Arts.ARTS_CalcDesirability_DDEF(val, gtup)
                s *= d^gtup[6]
            end
            Scores[i] = s^pow
        end
    end

    # Clamp best-point index to valid range before returning
    best_idx = VISE_ClampIndex_DDEF(argmax(Scores), NumPoints)

    return Candidates, Predictions, Scores
end

# --------------------------------------------------------------------------------------
# SECTION 5: EXECUTION ORCHESTRATOR
# --------------------------------------------------------------------------------------

"""
    VISE_Execute_DDEF(DataFile, Phase, Goals, [ModelType]) -> Dict
Higher-level entry point for experimental analysis.
"""
function VISE_Execute_DDEF(DataFile::String, Phase::String, Goals::AbstractVector,
    ModelType::String="Auto"; Opts=Dict{String,Any}())
    C = Sys_Fast.FAST_Constants_DDEF()
    Log = Sys_Fast.FAST_Log_DDEF

    Log("VISE", "EXECUTION_START", "Analyzing Phase: $Phase", "WAIT")

    df_raw = Sys_Fast.FAST_ReadExcel_DDEF(DataFile, C.SHEET_DATA)
    isempty(df_raw) && (df_raw = Sys_Fast.FAST_ReadExcel_DDEF(DataFile, "VERI_KAYITLARI"))
    isempty(df_raw) && return Dict("Status" => "FAIL", "Message" => "Source data is unreadable or empty.")

    col_phase = Symbol(C.COL_PHASE)
    df_train = hasproperty(df_raw, col_phase) ?
               filter(r -> string(r[col_phase]) == Phase, df_raw) :
               copy(df_raw)
    nrow(df_train) < 3 && return Dict("Status" => "FAIL", "Message" => "Insufficient data points (N < 3).")

    in_cols = filter(n -> startswith(n, C.PRE_INPUT), names(df_train))
    out_cols = filter(n -> startswith(n, C.PRE_RESULT), names(df_train))

    # Construct numeric matrices from DataFrame
    nr = nrow(df_train)
    X_Raw = Matrix{Float64}(undef, nr, length(in_cols))
    Y_Raw = Matrix{Float64}(undef, nr, length(out_cols))
    @inbounds for (ci, c) in enumerate(in_cols), r in 1:nr
        X_Raw[r, ci] = Sys_Fast.FAST_SafeNum_DDEF(df_train[r, c])
    end
    @inbounds for (ci, c) in enumerate(out_cols), r in 1:nr
        Y_Raw[r, ci] = Sys_Fast.FAST_SafeNum_DDEF(df_train[r, c])
    end

    valid_mask = vec(all(!isnan, Y_Raw; dims=2))
    X_Clean = X_Raw[valid_mask, :]
    Y_Clean = Y_Raw[valid_mask, :]
    N, K = size(X_Clean)

    InNames = replace.(in_cols, C.PRE_INPUT => "")
    OutNames = replace.(out_cols, C.PRE_RESULT => "")

    # --- RADIOACTIVITY DECAY CORRECTION ---
    radio_opts = get(Opts, "RadioOpts", Dict("Apply" => false, "t_cal" => "", "t_exp" => ""))
    if get(radio_opts, "Apply", false)
        t_cal_str = get(radio_opts, "t_cal", "")
        t_exp_str = get(radio_opts, "t_exp", "")

        if !isempty(t_cal_str) && !isempty(t_exp_str)
            try
                # Parse HTML5 datetime-local (yyyy-mm-ddThh:mm)
                dt_cal = Dates.DateTime(t_cal_str, "yyyy-mm-dd\\THH:MM")
                dt_exp = Dates.DateTime(t_exp_str, "yyyy-mm-dd\\THH:MM")

                # Delta t in Hours
                delta_t_ms = Dates.value(dt_exp - dt_cal) # Milliseconds
                delta_t_hours = delta_t_ms / (1000.0 * 60.0 * 60.0)

                if delta_t_hours > 0
                    config = Sys_Fast.FAST_ReadConfig_DDEF(DataFile)
                    if haskey(config, "Global")
                        glb = config["Global"]

                        # Correct Inputs (X) if radioactive
                        in_meta = get(glb, "Inputs", [])
                        for (ci, name) in enumerate(InNames)
                            idx = findfirst(x -> get(x, "Name", "") == name, in_meta)
                            if !isnothing(idx) && get(in_meta[idx], "IsRadioactive", false)
                                hl = Float64(get(in_meta[idx], "HalfLife", 0.0))
                                hlu = string(get(in_meta[idx], "HalfLifeUnit", "Hours"))
                                for r in 1:N
                                    X_Clean[r, ci] = VISE_ApplyRadioDecay_DDEF(X_Clean[r, ci], hl, hlu, delta_t_hours)
                                end
                                Sys_Fast.FAST_Log_DDEF("VISE", "DECAY_CORRECT", "Input \$(name) corrected (Δt = \$(round(delta_t_hours; digits=2))h)", "WARN")
                            end
                        end

                        # Correct Outputs (Y) if radioactive
                        out_meta = get(glb, "Outputs", [])
                        for (ci, name) in enumerate(OutNames)
                            idx = findfirst(x -> get(x, "Name", "") == name, out_meta)
                            if !isnothing(idx) && get(out_meta[idx], "IsRadioactive", false)
                                hl = Float64(get(out_meta[idx], "HalfLife", 0.0))
                                hlu = string(get(out_meta[idx], "HalfLifeUnit", "Hours"))
                                for r in 1:N
                                    Y_Clean[r, ci] = VISE_ApplyRadioDecay_DDEF(Y_Clean[r, ci], hl, hlu, delta_t_hours)
                                end
                                Sys_Fast.FAST_Log_DDEF("VISE", "DECAY_CORRECT", "Output \$(name) corrected (Δt = \$(round(delta_t_hours; digits=2))h)", "WARN")
                            end
                        end
                    end
                end
            catch e
                Sys_Fast.FAST_Log_DDEF("VISE", "DECAY_ERROR", "Failed to parse dates or apply correction: \$e", "FAIL")
            end
        end
    end

    # Zero Variance Check (Flat Line Detector)
    for m in eachindex(out_cols)
        if std(Y_Clean[:, m]) < 1e-6
            return Dict("Status" => "FAIL", "Message" => "Zero Variance Trap Detected: All experimental results for the output ($(out_cols[m])) appear to be identical. Optimisation and regression modelling cannot be performed on data with zero variance.")
        end
    end

    P_quad = 1 + 2K + K * (K - 1) ÷ 2
    eff_model = ModelType == "Auto" ? (N > P_quad + 2 ? "quadratic" : "linear") : lowercase(ModelType)

    Log("VISE", "MODEL_SETUP", "Using '$eff_model' model for $N samples.", "OK")

    InNames = replace.(in_cols, C.PRE_INPUT => "")
    OutNames = replace.(out_cols, C.PRE_RESULT => "")

    models = map(eachindex(out_cols)) do m
        mod = VISE_Regress_DDEF(X_Clean, view(Y_Clean, :, m), eff_model; InNames)
        mod["Goal"] = Goals[m]
        mod
    end

    r2_vec = [get(m, "R2_Adj", NaN) for m in models]
    r2_pred_vec = [VISE_CrossValidate_DDEF(X_Clean, view(Y_Clean, :, m), eff_model)
                   for m in eachindex(out_cols)]

    valid_r2 = filter(!isnan, r2_vec)
    !isempty(valid_r2) && Log("VISE", "TRAINING_SUMMARY",
        "Average Model R²_Adj: $(round(mean(valid_r2); digits=3))", "OK")

    Best_Point = Float64[]
    Leaders_DF = DataFrame()

    if get(Opts, "Optim", true) && K >= 2
        bounds = hcat(minimum(X_Clean; dims=1)', maximum(X_Clean; dims=1)')
        XT, YP, SC = VISE_GridSearch_DDEF(models, Goals, bounds)

        # Safe index clamping for leader extraction
        num_candidates = length(SC)
        best_idx = VISE_ClampIndex_DDEF(argmax(SC), num_candidates)
        Best_Point = XT[best_idx, :]

        # --- Leader Candidate Selection (Diversity-Focused) ---
        used_indices = Int[]
        cand_indices = Int[]
        cand_tags = String[]
        cand_count = 0

        top_indices = partialsortperm(SC, 1:num_candidates; rev=true)

        # 1. Top 8 Global Leaders
        for k in 1:min(8, length(top_indices))
            p_idx = VISE_ClampIndex_DDEF(top_indices[k], num_candidates)
            cand_count += 1
            push!(cand_indices, p_idx)
            push!(cand_tags, @sprintf("TOP-%02d", k))
            push!(used_indices, p_idx)
        end

        # 2. Input-Based Diversity (best score in the lowest 10% quantile)
        for i in 1:min(3, size(XT, 2))
            tag_pre = i <= length(InNames) ? uppercase(first(InNames[i] * "   ", 3)) : "IN$i"

            s_i = sortperm(XT[:, i])
            slice_len = max(1, round(Int, length(s_i) * 0.1))
            slice_indices = s_i[1:slice_len]

            slice_scores = SC[slice_indices]
            best_in_slice_local = sortperm(slice_scores; rev=true)
            sorted_slice_global = slice_indices[best_in_slice_local]

            selected_idx = -1
            for m in eachindex(sorted_slice_global)
                idx_val = VISE_ClampIndex_DDEF(sorted_slice_global[m], num_candidates)
                if !(idx_val in used_indices)
                    selected_idx = idx_val
                    break
                end
            end

            if selected_idx == -1
                selected_idx = VISE_ClampIndex_DDEF(sorted_slice_global[1], num_candidates)
                tag_str = "$(tag_pre)-01(D)"
            else
                tag_str = "$(tag_pre)-01"
                push!(used_indices, selected_idx)
            end

            cand_count += 1
            push!(cand_indices, selected_idx)
            push!(cand_tags, tag_str)
        end

        # 3. Output-Based Diversity (respecting sensor limits, highest values)
        valid_mask = SC .> 1e-4

        for i in 1:min(3, size(YP, 2))
            tag_pre = i <= length(OutNames) ? uppercase(first(OutNames[i] * "   ", 3)) : "OUT$i"

            sorted_desc = sortperm(YP[:, i]; rev=true)
            valid_sorted = filter(idx -> valid_mask[idx], sorted_desc)
            if isempty(valid_sorted)
                valid_sorted = sorted_desc
            end

            selected_idx = -1
            for m in eachindex(valid_sorted)
                idx_val = VISE_ClampIndex_DDEF(valid_sorted[m], num_candidates)
                if !(idx_val in used_indices)
                    selected_idx = idx_val
                    break
                end
            end

            if selected_idx == -1
                selected_idx = VISE_ClampIndex_DDEF(valid_sorted[1], num_candidates)
                tag_str = "$(tag_pre)-01(D)"
            else
                tag_str = "$(tag_pre)-01"
                push!(used_indices, selected_idx)
            end

            cand_count += 1
            push!(cand_indices, selected_idx)
            push!(cand_tags, tag_str)
        end

        Leaders_DF = DataFrame(
            Symbol(C.COL_ID) => cand_tags,
            :Score => round.(SC[cand_indices]; digits=4),
        )

        for (k, n) in enumerate(InNames)
            Leaders_DF[!, Symbol(C.PRE_INPUT * n)] = round.(XT[cand_indices, k]; digits=3)
        end
        for (k, n) in enumerate(OutNames)
            Leaders_DF[!, Symbol(C.PRE_PRED * n)] = round.(YP[cand_indices, k]; digits=3)
        end

        # Write candidate sets to the transient file for FLOW leader extraction
        Sys_Fast.FAST_WriteLeaders_DDEF(DataFile, Phase, Leaders_DF)
        Log("VISE", "OPTIMISATION", "Candidate pool (N=14 Diversity-Focussed) generated and saved.", "OK")
    end

    graphs = Lib_Arts.ARTS_Render_DDEF(models, X_Clean, Y_Clean, InNames, OutNames,
        Goals, r2_vec, r2_pred_vec, Opts, Best_Point)

    return Dict(
        "Status" => "OK", "Graphs" => graphs,
        "Models" => models, "R2_Adj" => r2_vec,
        "R2_Pred" => r2_pred_vec, "BestPoint" => Best_Point,
        "Leaders" => Leaders_DF, "OutNames" => OutNames,
        "BestScore" => isempty(Leaders_DF) ? 0.0 : maximum(Leaders_DF.Score),
    )
end

end # module
