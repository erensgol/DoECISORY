module Lib_Core

# ==============================================================================
# DAISHODOE PROJECT - LIB CORE
# ==============================================================================
# Description: Core engine for experimental design generation, coordinate mapping, 
#              and adaptive search algorithms (Zoom/Shift).
# Module Tag:  CORE
# ==============================================================================

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

export CORE_GenDesign_DDEF, CORE_MapLevels_DDEF,
    CORE_ExtractLeader_DDEF, CORE_GenerateOptimalDesign_DDEF,
    CORE_OptimiseDesirability_DDEF, CORE_ValidateDesign_DDEF,
    CORE_D_Efficiency_DDEF, CORE_CalcDesignMetrics_DDEF, CORE_CodeMatrix_DDEF

# ==============================================================================
# PART A: DESIGN MATRIX & COORDINATE GENERATION
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 1: CONSTANTS - Pre-allocated design matrices
# ------------------------------------------------------------------------------

const CORE_Bb15Design_DDEC = Int8[
    -1 -1 0; -1 1 0; 1 -1 0; 1 1 0;
    -1 0 -1; -1 0 1; 1 0 -1; 1 0 1;
    0 -1 -1; 0 -1 1; 0 1 -1; 0 1 1;
    0 0 0; 0 0 0; 0 0 0
]

const CORE_Tl09Design_DDEC = Int8[
    -1 -1 -1; -1 0 0; -1 1 1;
    0 -1 0; 0 0 1; 0 1 -1;
    1 -1 1; 1 0 -1; 1 1 0
]

"""
    CORE_GenDesign_DDEF(Method::String, FactorCount::Int) -> Matrix{Int8}
Generates a coded (-1, 0, 1) experimental design matrix for the specified method.
Supports Box-Behnken (BB15), Taguchi (TL09), and D-Optimal designs.
"""
function CORE_GenDesign_DDEF(Method::String, FactorCount::Int=3)
    C = Main.Sys_Fast.FAST_Data_DDEC
    Main.Sys_Fast.FAST_Log_DDEF("CORE", "DESIGN_GEN", "Generating matrix for $Method (Strict 3-Var Mode)", "WAIT")

    design = if Method == C.METHOD_BB15 || Method == "BB15"
        copy(CORE_Bb15Design_DDEC)
    elseif Method == C.METHOD_TL09 || Method == "TL09"
        copy(CORE_Tl09Design_DDEC)
    elseif Method == C.METHOD_DOPT15 || Method == "DOPT15"
        CORE_GenerateOptimalDesign_DDEF(FactorCount, 15)
    elseif Method == C.METHOD_DOPT09 || Method == "DOPT09"
        CORE_GenerateOptimalDesign_DDEF(FactorCount, 9)
    else
        Main.Sys_Fast.FAST_Log_DDEF("CORE", "METHOD_ERROR", "Undefined Method: $Method", "FAIL")
        Int8[;;]
    end

    R, C_dim = size(design)
    Main.Sys_Fast.FAST_Log_DDEF("CORE", "GEN_SUCCESS", "$R Runs x $C_dim Variables created.", "OK")
    return design
end

# ------------------------------------------------------------------------------
# SECTION 2: COORDINATE MAPPING (Coded -> Physical)
# ------------------------------------------------------------------------------

"""
    CORE_MapLevels_DDEF(CodedMatrix, Config) -> Matrix{Float64}
Maps coded entries (-1, 0, 1) to physical units based on factor level configurations.
"""
function CORE_MapLevels_DDEF(CodedMatrix::AbstractMatrix, Config::AbstractVector)
    rows = size(CodedMatrix, 1)
    cols = 3

    result = Matrix{Float64}(undef, rows, cols)
    @inbounds for i in 1:cols
        lvls    = get(Config[i], "Levels", zeros(3))
        length(lvls) < 3 && (lvls = zeros(3))
        indices = clamp.(round.(Int, view(CodedMatrix, :, i)) .+ 2, 1, 3)
        result[:, i] .= getindex.(Ref(lvls), indices)
    end
    return result
end

# ------------------------------------------------------------------------------
# SECTION 3: OPTIMAL DESIGN GENERATION
# ------------------------------------------------------------------------------

"""
    CORE_GenerateOptimalDesign_DDEF(FactorCount::Int, RunCount::Int) -> Matrix{Int8}
Generates a D-Optimal design matrix for quadratic response surfaces via `ExperimentalDesign.jl`.
"""
function CORE_GenerateOptimalDesign_DDEF(FactorCount::Int=3, RunCount::Int=15)
    C           = Main.Sys_Fast.FAST_Data_DDEC
    FactorCount = 3
    Main.Sys_Fast.FAST_Log_DDEF("CORE", "OPTIMAL_GEN", "Generating D-Optimal design for strict 3-variable system ($RunCount runs).", "WAIT")

    try
        factor_dists = fill(DiscreteUniform(-1, 1), FactorCount)
        design_dist  = DesignDistribution(factor_dists)

        pool_size  = min(3^FactorCount, 1000)
        candidates = rand(design_dist, pool_size)

        term_syms = [Symbol("x", i) for i in 1:FactorCount]
        rename!(candidates.matrix, term_syms)

        # Utilise StatsModels terms to maintain structural formula integrity.
        main_terms  = [term(s) for s in term_syms]
        inter_terms = []
        for i in 1:FactorCount
            for j in (i+1):FactorCount
                push!(inter_terms, main_terms[i] & main_terms[j])
            end
        end
        quad_terms = [main_terms[i] & main_terms[i] for i in 1:FactorCount]

        # Aggregate terms ensuring intercept management is handled by the optimal design protocol.
        all_terms = reduce(+, [main_terms; inter_terms; quad_terms])
        f         = FormulaTerm(term(0), all_terms)

        Main.Sys_Fast.FAST_Log_DDEF("CORE", "OPTIMAL_GEN", "D-Optimal model structure established successfully.", "WAIT")

        # Invoke optimal design generation via dynamic dispatch for operational stability.
        opt_design = Base.invokelatest(OptimalDesign, candidates, f, RunCount)

        res_matrix = Matrix{Int8}(round.(Matrix(opt_design.matrix)))

        R, C_dim = size(res_matrix)
        Main.Sys_Fast.FAST_Log_DDEF("CORE", "GEN_SUCCESS", "$R Runs x $C_dim Variables D-Optimal created.", "OK")
        return res_matrix
    catch e
        Main.Sys_Fast.FAST_Log_DDEF("CORE", "GEN_FAIL", "Failed to generate optimal design: $e", "FAIL")
        return zeros(Int8, RunCount, FactorCount)
    end
end

# ==============================================================================
# PART B: ALGORITHMIC OPTIMISERS & METRICS
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 4: DESIRABILITY OPTIMISATION (BlackBoxOptim)
# ------------------------------------------------------------------------------

"""
    CORE_OptimiseDesirability_DDEF(Models, Goals, X_Bounds; MaxTime, PenaltyFn) -> Vector{Float64}
Globally optimises parameters by maximising composite desirability using BlackBoxOptim.
"""
function CORE_OptimiseDesirability_DDEF(Models::AbstractVector, Goals::AbstractVector, X_Bounds::AbstractMatrix{Float64};
    MaxTime::Float64=5.0, PenaltyFn::Union{Function,Nothing}=nothing)
    Dim       = 3
    NumModels = length(Models)

    parsed_goals = [Main.Lib_Arts.ARTS_ExtractGoal_DDEF(m <= length(Goals) ? Goals[m] : get(Models[m], "Goal", Dict{String, Any}())) for m in 1:NumModels]

    weight_sum = 0.0
    for m in 1:NumModels
        m_goal = m <= length(Goals) ? Goals[m] : get(Models[m], "Goal", Dict{String, Any}())
        weight_sum += Float64(get(m_goal, "Weight", 1.0))
    end
    pow_factor = weight_sum > 0.0 ? (1.0 / weight_sum) : 1.0

    closures = Any[nothing for _ in 1:NumModels]
    for m in 1:NumModels
        get(Models[m], "Status", "") != "OK" && continue

        beta     = collect(Float64, Models[m]["Coefs"])
        mod_type = lowercase(get(Models[m], "ModelType", "quadratic"))
        
        if occursin("linear", mod_type)
            closures[m] = (x) -> beta[1] + beta[2]*x[1] + beta[3]*x[2] + beta[4]*x[3]
        else
            # Order: Int, A, B, C, AB, AC, BC, A2, B2, C2
            # Indices: 1, 2, 3, 4, 5,  6,  7,  8,  9,  10
            closures[m] = (x) -> begin
                @inbounds (beta[1] + 
                 beta[2]*x[1] + beta[3]*x[2] + beta[4]*x[3] + 
                 beta[5]*x[1]*x[2] + beta[6]*x[1]*x[3] + beta[7]*x[2]*x[3] +
                 beta[8]*x[1]*x[1] + beta[9]*x[2]*x[2] + beta[10]*x[3]*x[3])
            end
        end
    end

    function CORE_CalcObjective_DDEF(x)
        s     = 1.0
        for m in 1:NumModels
            c = closures[m]
            isnothing(c) && continue
            val = c(x)
            if isnan(val) || isinf(val)
                return 0.0 
            end
            gtup = parsed_goals[m]
            d    = Main.Lib_Arts.ARTS_CalcDesirability_DDEF(val, gtup)
            s   *= (d^gtup[6])
        end
        score = clamp(s^pow_factor, 0.0, 1.0)

        if PenaltyFn !== nothing
            score *= PenaltyFn(x)
        end

        return -score
    end

    search_range = [(X_Bounds[i, 1], X_Bounds[i, 2]) for i in 1:Dim]

    Main.Sys_Fast.FAST_Log_DDEF("CORE", "BBO_START", "Initiating BlackBoxOptim for Global Desirability (MaxTime: $(MaxTime)s)...", "WAIT")

    try
        res = bboptimize(CORE_CalcObjective_DDEF;
            SearchRange       = search_range,
            NumDimensions     = Dim,
            MaxTime           = MaxTime,
            Method            = :adaptive_de_rand_1_bin_radiuslimited,
            TraceMode         = :silent
        )

        best_x     = best_candidate(res)
        best_score = -best_fitness(res)

        Main.Sys_Fast.FAST_Log_DDEF("CORE", "BBO_SUCCESS", "Global Optimum Found -> Score: $(round(best_score, digits=4))", "OK")
        return best_x, best_score
    catch e
        Main.Sys_Fast.FAST_Log_DDEF("CORE", "BBO_FAIL", "BlackBoxOptim encountered a critical failure: $e. Reverting to geometric centre.", "FAIL")
        return [ (X_Bounds[i, 1] + X_Bounds[i, 2]) / 2.0 for i in 1:Dim ], 0.0
    end
end

# ------------------------------------------------------------------------------
# SECTION 5: LEADER DATA EXTRACTION
# ------------------------------------------------------------------------------

"""
    CORE_ExtractLeader_DDEF(FilePath, PhaseCode, [SelectedID], [VarNames]) -> Dict
Retrieves experiment data for the optimal (leader) run from a previous phase record.
"""
function CORE_ExtractLeader_DDEF(FilePath::String, PhaseCode::String, SelectedID::String="", VarNames::Vector{String}=String[])
    C     = Main.Sys_Fast.FAST_Data_DDEC
    sheet = C.PREFIX_LEADERS * PhaseCode

    df = Main.Sys_Fast.FAST_ReadExcel_DDEF(FilePath, sheet)
    if isempty(df)
        Main.Sys_Fast.FAST_Log_DDEF("CORE", "EXTRACTION_FAIL", "Sheet '$sheet' not found or empty.", "FAIL")
        return Dict{String,Any}()
    end

    cols      = names(df)
    col_score = findfirst(c -> occursin("SCORE", uppercase(strip(string(c)))), cols)
    col_id    = findfirst(c -> occursin("ID", uppercase(strip(string(c)))), cols)

    isnothing(col_score) && return Dict{String,Any}()

    idx = 0
    if !isempty(SelectedID) && !isnothing(col_id)
        idx = findfirst(==(SelectedID), string.(df[!, col_id]))
        if isnothing(idx)
            Main.Sys_Fast.FAST_Log_DDEF("CORE", "LEADER_WARN", "ID '$SelectedID' not found. Defaulting to Best.", "WARN")
        else
            Main.Sys_Fast.FAST_Log_DDEF("CORE", "LEADER_FETCH", "Manual selection: $SelectedID", "OK")
        end
    end

    if isnothing(idx) || idx == 0
        _, idx = findmax(df[!, col_score])
        Main.Sys_Fast.FAST_Log_DDEF("CORE", "LEADER_FETCH", "Automatic selection: Global Best", "OK")
    end

    row = df[idx, :]

    vals = Float64[]
    if !isempty(VarNames)
        for v_name in VarNames
            v_key_pfx = startswith(uppercase(v_name), uppercase(C.PRE_INPUT)) ? v_name : "$(C.PRE_INPUT)$v_name"
            
            actual_key = Main.Sys_Fast.FAST_GetCol_DDEF(df, v_key_pfx)
            actual_alt = isempty(actual_key) ? Main.Sys_Fast.FAST_GetCol_DDEF(df, v_name) : ""
            
            val = !isempty(actual_key) ? row[Symbol(actual_key)] : (!isempty(actual_alt) ? row[Symbol(actual_alt)] : 0.0)
            push!(vals, Main.Sys_Fast.FAST_SafeNum_DDEF(val))
        end
    else
        input_cols = filter(n -> startswith(uppercase(string(n)), uppercase(C.PRE_INPUT)), cols)
        vals       = Main.Sys_Fast.FAST_SafeNum_DDEF.(values(row[input_cols]))
    end

    id_str = isnothing(col_id) ? "N/A" : string(row[col_id])
    Main.Sys_Fast.FAST_Log_DDEF("CORE", "LEADER_DATA",
        "ID: $id_str | Score: $(round(row[col_score]; digits=4))", "OK")

    return Dict{String,Any}(
        "ID"         => id_str,
        "Score"      => row[col_score],
        "Vals"       => collect(vals),
        "InputNames" => isempty(VarNames) ? filter(n -> startswith(uppercase(string(n)), uppercase(C.PRE_INPUT)), cols) : VarNames,
        "OldConfig"  => Any[]
    )
end

# ------------------------------------------------------------------------------
# SECTION 6: DESIGN MATRIX VALIDATION
# ------------------------------------------------------------------------------

"""
    CORE_ValidateDesign_DDEF(DesignMatrix::Matrix, Config::AbstractVector) -> (Bool, String)
Pre-flight integrity check for generated designs (detects singular matrices/degeneracy).
"""
function CORE_ValidateDesign_DDEF(DesignMatrix::AbstractMatrix, Config::AbstractVector=[])
    R, C   = size(DesignMatrix)
    issues = String[]

    R < 3 && push!(issues, "Design has fewer than 3 runs ($R). Regression will fail.")

    @inbounds for j in 1:C
        col = view(DesignMatrix, :, j)
        if all(==(col[1]), col)
            push!(issues, "Column $j has zero variance (all values = $(col[1])).")
        end
    end

    seen      = Set{Vector{Float64}}()
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

    if R >= C
        X_sc    = DesignMatrix ./ max.(maximum(abs, DesignMatrix; dims=1), 1e-9)
        det_val = det(X_sc' * X_sc)
        if det_val < 1e-8
            push!(issues, "Design is near-singular (Det ≈ $(round(det_val; digits=4))). Regression may fail.")
        end
    end

    is_valid = isempty(issues)
    if is_valid
        Main.Sys_Fast.FAST_Log_DDEF("CORE", "VALIDATE", "Design matrix OK ($R×$C, $(R-dup_count) unique).", "OK")
    else
        Main.Sys_Fast.FAST_Log_DDEF("CORE", "VALIDATE", "Design issues: $(join(issues, " | "))", "WARN")
    end

    return (is_valid, join(issues, "\n"))
end

# ------------------------------------------------------------------------------
# SECTION 7: DESIGN QUALITY METRICS (D, A, G, I Efficiency)
# ------------------------------------------------------------------------------

"""
    CORE_D_Efficiency_DDEF(X::Matrix) -> Float64

Calculates D-Efficiency as a design quality metric representing the spread of points.
"""
function CORE_D_Efficiency_DDEF(X::AbstractMatrix)
    R, C = size(X)
    R < C && return 0.0
    try
        # Automated coding of the matrix to [-1, 1] range to ensure scale-invariant efficiency.
        X_sc = CORE_CodeMatrix_DDEF(X)
        # Normalised Fisher Information Determinant: (det(X'X) / R^p)^(1/p)
        det_val = det(X_sc' * X_sc)
        return (max(det_val, 0.0) / (R^C))^(1 / C)
    catch
        return 0.0
    end
end

"""
    CORE_CodeMatrix_DDEF(X::Matrix, [Bounds]) -> Matrix{Float64}

Codes a physical matrix into the [-1, 1] interval for scale-invariant mathematical analysis.
"""
function CORE_CodeMatrix_DDEF(X::AbstractMatrix, Bounds::Union{AbstractMatrix, Nothing}=nothing)
    R, C = size(X)
    X_coded = Matrix{Float64}(undef, R, C)
    
    for j in 1:C
        col = X[:, j]
        c_min, c_max = minimum(col), maximum(col)
        
        if Bounds !== nothing
            b_min, b_max = Bounds[j, 1], Bounds[j, 2]
        else
            b_min, b_max = c_min, c_max
        end
        
        range_val = b_max - b_min
        
        if range_val < 1e-9
            # Preserve constant columns (e.g. intercept) instead of zeroing them.
            X_coded[:, j] .= col
        elseif b_min >= -1.0001 && b_max <= 1.0001 && abs(b_min + b_max) < 1e-3
            # Already coded to [-1, 1], preserve.
            X_coded[:, j] .= col
        else
            # Linear transformation: x_coded = 2 * (x - min) / (max - min) - 1
            X_coded[:, j] .= 2.0 .* (col .- b_min) ./ range_val .- 1.0
        end
    end
    return X_coded
end

"""
    CORE_CalcDesignMetrics_DDEF(X::Matrix) -> Dict

Calculates a comprehensive suite of design quality metrics including D, A, G, and I efficiency.
"""
function CORE_CalcDesignMetrics_DDEF(X::AbstractMatrix)
    R, C = size(X)
    res  = Dict("D" => 0.0, "A" => 0.0, "G" => 0.0, "I" => 0.0, "Condition" => Inf)
    R < C && return res

    try
        # Automated coding to [-1, 1] to ensure metrics adhere to standard DoE benchmarks.
        X_sc = CORE_CodeMatrix_DDEF(X)
        XtX  = X_sc' * X_sc
        
        res["Condition"] = cond(XtX)

        # D-Efficiency representing the determinant-based design quality metric.
        det_val  = det(XtX)
        res["D"] = (max(det_val, 0.0) / (R^C))^(1 / C)

        # A-Efficiency representing the average variance-based design quality metric.
        # Stabilised inversion via pseudo-inverse for near-singular designs.
        inv_XtX  = pinv(XtX)
        res["A"] = C / (R * tr(inv_XtX))

        # G-Efficiency representing the maximum variance-based design quality metric.
        lev      = diag(X_sc * inv_XtX * X_sc')
        max_var  = maximum(lev)
        res["G"] = C / (R * max_var)

        # I-Efficiency representing the integrated variance-based design quality metric.
        res["I"] = C / (R * mean(lev))

    catch e
        Main.Sys_Fast.FAST_Log_DDEF("CORE", "METRICS_ERR", "Stability error in design metrics: $e", "WARN")
    end
    return res
end

end