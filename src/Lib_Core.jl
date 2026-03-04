module Lib_Core

# ======================================================================================
# DAISHODOE - LIB CORE (EXPERIMENTAL DESIGN ENGINE)
# ======================================================================================
# Purpose: Core algorithms for matrix generation, coordinate mapping, and
#          adaptive search logic (Zoom/Shift).
# Module Tag: CORE
# ======================================================================================

using Random
using LinearAlgebra
using Printf
using Main.Sys_Fast
using ExperimentalDesign
using Distributions
using StatsModels
using DataFrames
using BlackBoxOptim
using Main.Lib_Arts

export CORE_GenDesign_DDEF, CORE_CalcNextRange_DDEF, CORE_MapLevels_DDEF,
    CORE_ExtractLeader_DDEF, CORE_GenerateOptimalDesign_DDEF,
    CORE_OptimizeDesirability_DDEF, CORE_ValidateDesign_DDEF,
    CORE_D_Efficiency_DDEF, CORE_CalcDesignMetrics_DDEF

# --------------------------------------------------------------------------------------
# --- EXPERIMENTAL DESIGN GENERATOR ---
# --------------------------------------------------------------------------------------

# Pre-allocated immutable design matrices (coded format)
const _BB_DESIGN = Int8[
    -1 -1 0; -1 1 0; 1 -1 0; 1 1 0;
    -1 0 -1; -1 0 1; 1 0 -1; 1 0 1;
    0 -1 -1; 0 -1 1; 0 1 -1; 0 1 1;
    0 0 0; 0 0 0; 0 0 0
]

const _TL9_DESIGN = Int8[
    -1 -1 -1; -1 0 0; -1 1 1;
    0 -1 0; 0 0 1; 0 1 -1;
    1 -1 1; 1 0 -1; 1 1 0
]

"""
    CORE_GenDesign_DDEF(Method::String, FactorCount::Int) -> Matrix{Int8}
Generates a coded (-1, 0, 1) experiment matrix for the specified method.
"""
function CORE_GenDesign_DDEF(Method::String, FactorCount::Int)
    CONST = Sys_Fast.FAST_Constants_DDEF()
    Sys_Fast.FAST_Log_DDEF("CORE", "DESIGN_GEN", "Generating matrix for $Method", "WAIT")

    design = if Method == CONST.METHOD_BB
        copy(_BB_DESIGN)
    elseif Method == CONST.METHOD_TL9
        FactorCount > 3 && Sys_Fast.FAST_Log_DDEF("CORE", "LIMIT_WARN", "Taguchi L9 limited to 3 variables. Truncating.", "WARN")
        _TL9_DESIGN[:, 1:min(FactorCount, 3)]
    else
        Sys_Fast.FAST_Log_DDEF("CORE", "METHOD_ERROR", "Undefined Method: $Method", "FAIL")
        Int8[;;]
    end

    R, C = size(design)
    Sys_Fast.FAST_Log_DDEF("CORE", "GEN_SUCCESS", "$R Runs x $C Variables created.", "OK")
    return design
end

# --------------------------------------------------------------------------------------
# --- COORDINATE MAPPING (CODED -> PHYSICAL) ---
# --------------------------------------------------------------------------------------

"""
    CORE_MapLevels_DDEF(CodedMatrix, Config) -> Matrix{Float64}
Maps coded entries (-1, 0, 1) to physical units based on factor level configurations.
"""
function CORE_MapLevels_DDEF(CodedMatrix::AbstractMatrix, Config::AbstractVector)
    rows, cols = size(CodedMatrix)

    if cols > length(Config)
        Sys_Fast.FAST_Log_DDEF("CORE", "MAP_ERROR", "Matrix columns exceed Config length.", "FAIL")
        return zeros(Float64, rows, cols)
    end

    # Pre-allocate result and fill via vectorised indexing for performance
    result = Matrix{Float64}(undef, rows, cols)
    @inbounds for i in 1:cols
        lvls = get(Config[i], "Levels", zeros(3))
        length(lvls) < 3 && (lvls = zeros(3))
        indices = clamp.(round.(Int, view(CodedMatrix, :, i)) .+ 2, 1, 3)
        result[:, i] .= getindex.(Ref(lvls), indices)
    end
    return result
end

# --------------------------------------------------------------------------------------
# --- ADAPTIVE SEARCH LOGIC (ZOOM / SHIFT) ---
# --------------------------------------------------------------------------------------

"""
    CORE_CalcNextRange_DDEF(LeaderInfo) -> Vector{Dict}
Calculates the search space for the next phase using Zoom (reduction) or Shift (translation).
"""
function CORE_CalcNextRange_DDEF(LeaderInfo::Dict)
    CONST = Sys_Fast.FAST_Constants_DDEF()
    NewConf = deepcopy(LeaderInfo["OldConfig"])
    SelVals = LeaderInfo["Vals"]

    Sys_Fast.FAST_Log_DDEF("CORE", "SEARCH_SPACE", "Calculating adaptive design update...", "WAIT")

    vars = [(i, conf) for (i, conf) in enumerate(NewConf) if get(conf, "Role", "Variable") == CONST.ROLE_VAR]

    n_update = min(length(vars), length(SelVals))
    @inbounds for j in 1:n_update
        i, conf = vars[j]
        L_Old = conf["Levels"]
        Val = SelVals[j]
        Range = L_Old[3] - L_Old[1]

        Tol = Range * 0.05
        at_limit = abs(Val - L_Old[1]) < Tol || abs(Val - L_Old[3]) < Tol

        New_Mid = Val
        New_Range = at_limit ? Range : Range * 0.5
        action = at_limit ? "SHIFT" : "ZOOM"
        Sys_Fast.FAST_Log_DDEF("CORE", action,
            "Var $i -> $(action == "SHIFT" ? "Centre shifted" : "Range reduced")", "LIST")

        New_Min = New_Mid - New_Range / 2
        New_Max = New_Mid + New_Range / 2

        # Symmetrical boundary clamping: guard both lower and upper physical limits
        if New_Min < 0.0
            overshoot = -New_Min
            New_Min = 0.0
            New_Max += overshoot  # Compensate to preserve range width
            Sys_Fast.FAST_Log_DDEF("CORE", "CLAMP", "Var $i hit lower boundary. Range shifted upward.", "WARN")
        end

        # If upper limit is defined in old config, respect it as a hard ceiling
        org_max = L_Old[3] + Range * 0.1  # Allow 10% overshoot beyond original max
        if New_Max > org_max && org_max > 0.0
            New_Max = org_max
            Sys_Fast.FAST_Log_DDEF("CORE", "CLAMP", "Var $i hit upper boundary ceiling.", "WARN")
        end

        conf["Levels"] = [New_Min, New_Mid, New_Max]
    end

    Sys_Fast.FAST_Log_DDEF("CORE", "SEARCH_SPACE", "New space configured successfully.", "OK")
    return NewConf
end

# --------------------------------------------------------------------------------------
# --- EXPERIMENTAL DESIGN - OPTIMAL GENERATION ---
# --------------------------------------------------------------------------------------

"""
    CORE_GenerateOptimalDesign_DDEF(FactorCount::Int, RunCount::Int) -> Matrix{Int8}
Generates a D-Optimal design matrix for quadratic response surfaces via `ExperimentalDesign.jl`.
"""
function CORE_GenerateOptimalDesign_DDEF(FactorCount::Int, RunCount::Int)
    CONST = Sys_Fast.FAST_Constants_DDEF()
    Sys_Fast.FAST_Log_DDEF("CORE", "OPTIMAL_GEN", "Generating D-Optimal design for $FactorCount factors and $RunCount runs.", "WAIT")

    try
        # Define the parameter space: each factor has 3 levels (-1, 0, 1)
        factor_dists = fill(DiscreteUniform(-1, 1), FactorCount)
        design_dist = DesignDistribution(factor_dists)

        # Generate a large candidate pool (e.g. 500 or 3^FactorCount)
        pool_size = min(3^FactorCount, 1000)
        candidates = rand(design_dist, pool_size)

        # Build terms dynamically: Main effects + Interactions + Quadratics
        term_syms = [Symbol("x", i) for i in 1:FactorCount]
        rename!(candidates.matrix, term_syms)

        # Construct formula using StatsModels Term objects to avoid eval()
        main_terms = [term(s) for s in term_syms]
        inter_terms = []
        for i in 1:FactorCount
            for j in (i+1):FactorCount
                push!(inter_terms, main_terms[i] & main_terms[j])
            end
        end
        quad_terms = [main_terms[i] & main_terms[i] for i in 1:FactorCount]

        # Combine all terms: intercept is handled by OptimalDesign if not specified otherwise
        all_terms = reduce(+, [main_terms; inter_terms; quad_terms])
        f = FormulaTerm(term(0), all_terms)

        Sys_Fast.FAST_Log_DDEF("CORE", "OPTIMAL_GEN", "D-Optimal model structure established via safe Terms.", "WAIT")

        # OptimalDesign(candidates, formula, run_count)
        opt_design = Base.invokelatest(OptimalDesign, candidates, f, RunCount)

        res_matrix = Matrix{Int8}(round.(opt_design.matrix))

        R, C = size(res_matrix)
        Sys_Fast.FAST_Log_DDEF("CORE", "GEN_SUCCESS", "$R Runs x $C Variables D-Optimal created.", "OK")
        return res_matrix
    catch e
        Sys_Fast.FAST_Log_DDEF("CORE", "GEN_FAIL", "Failed to generate optimal design: $e", "FAIL")
        return zeros(Int8, RunCount, FactorCount)
    end
end

# --------------------------------------------------------------------------------------
# --- DESIRABILITY OPTIMISATION (BLACKBOXOPTIM) ---
# --------------------------------------------------------------------------------------

"""
    CORE_OptimizeDesirability_DDEF(Models, Goals, X_Bounds; MaxTime, PenaltyFn) -> Vector{Float64}
Globally optimises parameters by maximising composite desirability using BlackBoxOptim.
"""
function CORE_OptimizeDesirability_DDEF(Models::AbstractVector, Goals::AbstractVector, X_Bounds::AbstractMatrix{Float64};
    MaxTime::Float64=3.0, PenaltyFn::Union{Function,Nothing}=nothing)
    Dim = size(X_Bounds, 1)
    NumModels = length(Models)

    # Pre-parse goals for fast execution
    parsed_goals = [Main.Lib_Arts.ARTS_ExtractGoal_DDEF(Models[m]["Goal"]) for m in 1:NumModels]

    weight_sum = 0.0
    for m in 1:NumModels
        weight_sum += Float64(get(Models[m]["Goal"], "Weight", 1.0))
    end
    pow_factor = weight_sum > 0.0 ? (1.0 / weight_sum) : 1.0

    # Build predictive closures
    closures = Any[nothing for _ in 1:NumModels]
    for m in 1:NumModels
        m_type = lowercase(get(Models[m], "ModelType", ""))
        if m_type == "kriging" || m_type == "rbf"
            closures[m] = Main.Lib_Vise.VISE_BuildSurrogateClosure_DDEF(Models[m])
        else
            # For Linear/Quadratic GLM models
            beta = Models[m]["Coefs"]::Vector{Float64}
            closures[m] = (x_tup) -> begin
                # Single point expansion
                x_vec = collect(x_tup)
                X_mat = reshape(x_vec, 1, Dim)
                Xd = Main.Lib_Vise.VISE_ExpandDesign_DDEF(X_mat, Models[m]["ModelType"])
                return (Xd*beta)[1]
            end
        end
    end

    # Define the Objective Function (BBO Minimises, so we return -Score)
    function objective(x)
        s = 1.0
        x_tup = ntuple(i -> x[i], Dim)
        for m in 1:NumModels
            val = closures[m](x_tup)
            if isnan(val) || isinf(val)
                return 0.0 # Extreme penalty, Desirability 0.0
            end
            gtup = parsed_goals[m]
            d = Lib_Arts.ARTS_CalcDesirability_DDEF(val, gtup)
            s *= d^gtup[6]
        end
        score = s^pow_factor

        # Apply external scientific constraints (Penalties)
        if PenaltyFn !== nothing
            score *= PenaltyFn(x_tup)
        end

        return -score
    end

    search_range = [(X_Bounds[i, 1], X_Bounds[i, 2]) for i in 1:Dim]

    Main.Sys_Fast.FAST_Log_DDEF("CORE", "BBO_START", "Initiating BlackBoxOptim for Global Desirability (MaxTime: $(MaxTime)s)...", "WAIT")

    # Suppress BBO prints via TraceMode=:silent
    res = bboptimize(objective;
        SearchRange=search_range,
        NumDimensions=Dim,
        MaxTime=MaxTime,
        Method=:adaptive_de_rand_1_bin_radiuslimited,
        TraceMode=:silent
    )

    best_x = best_candidate(res)
    best_score = -best_fitness(res)

    Main.Sys_Fast.FAST_Log_DDEF("CORE", "BBO_SUCCESS", "Global Optimum Found -> Score: $(round(best_score, digits=4))", "OK")

    return best_x
end

# --------------------------------------------------------------------------------------
# --- LEADER EXTRACTION ---
# --------------------------------------------------------------------------------------

"""
    CORE_ExtractLeader_DDEF(FilePath, PhaseCode, [SelectedID]) -> Dict
Retrieves experiment data for the optimal (leader) run from a previous phase record.
"""
function CORE_ExtractLeader_DDEF(FilePath::String, PhaseCode::String, SelectedID::String="")
    CONST = Sys_Fast.FAST_Constants_DDEF()
    sheet = CONST.PREFIX_LEADERS * PhaseCode

    df = Sys_Fast.FAST_ReadExcel_DDEF(FilePath, sheet)
    if isempty(df)
        Sys_Fast.FAST_Log_DDEF("CORE", "EXTRACTION_FAIL", "Sheet '$sheet' not found or empty.", "FAIL")
        return Dict{String,Any}()
    end

    cols = names(df)
    col_score = findfirst(c -> occursin("SCORE", uppercase(c)), cols)
    col_id = findfirst(c -> occursin("ID", uppercase(c)), cols)

    isnothing(col_score) && return Dict{String,Any}()

    idx = 0
    if !isempty(SelectedID) && !isnothing(col_id)
        idx = findfirst(==(SelectedID), string.(df[!, col_id]))
        if isnothing(idx)
            Sys_Fast.FAST_Log_DDEF("CORE", "LEADER_WARN", "ID '$SelectedID' not found. Defaulting to Best.", "WARN")
        else
            Sys_Fast.FAST_Log_DDEF("CORE", "LEADER_FETCH", "Manual selection: $SelectedID", "OK")
        end
    end

    if isnothing(idx) || idx == 0
        _, idx = findmax(df[!, col_score])
        Sys_Fast.FAST_Log_DDEF("CORE", "LEADER_FETCH", "Automatic selection: Global Best", "OK")
    end

    row = df[idx, :]
    input_cols = filter(n -> startswith(n, CONST.PRE_INPUT), cols)
    vals = Sys_Fast.FAST_SafeNum_DDEF.(values(row[input_cols]))

    id_str = isnothing(col_id) ? "N/A" : string(row[col_id])
    Sys_Fast.FAST_Log_DDEF("CORE", "LEADER_DATA",
        "ID: $id_str | Score: $(round(row[col_score]; digits=4))", "OK")

    return Dict{String,Any}(
        "ID" => id_str,
        "Score" => row[col_score],
        "Vals" => collect(vals),
        "InputNames" => input_cols,
        "OldConfig" => Any[],
    )
end

# --------------------------------------------------------------------------------------
# --- DESIGN MATRIX VALIDATION ---
# --------------------------------------------------------------------------------------

"""
    CORE_ValidateDesign_DDEF(DesignMatrix::Matrix, Config::AbstractVector) -> (Bool, String)
Pre-flight integrity check for generated designs (detects singular matrices/degeneracy).
"""
function CORE_ValidateDesign_DDEF(DesignMatrix::AbstractMatrix, Config::AbstractVector=[])
    R, C = size(DesignMatrix)
    issues = String[]

    R < 3 && push!(issues, "Design has fewer than 3 runs ($R). Regression will fail.")

    # Check for zero-variance columns (all same value)
    @inbounds for j in 1:C
        col = view(DesignMatrix, :, j)
        if all(==(col[1]), col)
            push!(issues, "Column $j has zero variance (all values = $(col[1])).")
        end
    end

    # Check for duplicate rows
    seen = Set{Vector{Float64}}()
    dup_count = 0
    @inbounds for i in 1:R
        row = Float64.(DesignMatrix[i, :])
        if row in seen
            dup_count += 1
        else
            push!(seen, row)
        end
    end
    dup_count > R ÷ 2 && push!(issues, "Design has $dup_count duplicate rows out of $R total.")

    # Det-Check (Mathematical Health)
    if R >= C
        # Scale to [-1, 1] for stable determinant
        X_sc = DesignMatrix ./ max.(maximum(abs, DesignMatrix; dims=1), 1e-9)
        det_val = det(X_sc' * X_sc)
        if det_val < 1e-8
            push!(issues, "Design is near-singular (Det ≈ $(round(det_val; digits=4))). Regression may fail.")
        end
    end

    is_valid = isempty(issues)
    if is_valid
        Sys_Fast.FAST_Log_DDEF("CORE", "VALIDATE", "Design matrix OK ($R×$C, $(R-dup_count) unique).", "OK")
    else
        Sys_Fast.FAST_Log_DDEF("CORE", "VALIDATE", "Design issues: $(join(issues, " | "))", "WARN")
    end

    return (is_valid, join(issues, "\n"))
end

"""
    CORE_D_Efficiency_DDEF(X::Matrix) -> Float64
Calculates D-Efficiency as a design quality metric (spread of points).
"""
function CORE_D_Efficiency_DDEF(X::AbstractMatrix)
    R, C = size(X)
    R < C && return 0.0
    try
        # Normalised Fisher Information Determinant: (det(X'X) / R^p)^(1/p)
        return (det(X' * X) / (R^C))^(1 / C)
    catch
        return 0.0
    end
end

"""
    CORE_CalcDesignMetrics_DDEF(X::Matrix) -> Dict
Calculates a suite of design quality metrics (D, A, G, I efficiency).
"""
function CORE_CalcDesignMetrics_DDEF(X::AbstractMatrix)
    R, C = size(X)
    res = Dict("D" => 0.0, "A" => 0.0, "G" => 0.0, "I" => 0.0, "Condition" => Inf)
    R < C && return res

    try
        XtX = X' * X
        res["Condition"] = cond(XtX)

        # 1. D-Efficiency (Determinant-based)
        res["D"] = (det(XtX) / (R^C))^(1 / C)

        # 2. A-Efficiency (Average Variance-based)
        inv_XtX = inv(XtX)
        res["A"] = C / (R * tr(inv_XtX))

        # 3. G-Efficiency (Max Variance-based proxy)
        lev = diag(X * inv_XtX * X')
        max_var = maximum(lev)
        res["G"] = C / (R * max_var)

        # 4. I-Efficiency (Integrated variance proxy)
        res["I"] = C / (R * mean(lev))

    catch e
        Sys_Fast.FAST_Log_DDEF("CORE", "METRICS_ERR", "Stability error in design metrics: $e", "WARN")
    end
    return res
end

end # module Lib_Core
