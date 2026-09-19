module Lib_Vise

# ==============================================================================
# DOECISORY - LIB VISE (STATISTICAL ANALYSIS)
# ==============================================================================
# Description: Statistical analysis module for modelling (OLS), sensitivity 
#              analysis, and multi-objective optimisation tasks.
# Module Tag:  VISE
# ==============================================================================

using DataFrames
using JSON3
using Base.Threads
using LinearAlgebra
using Statistics
using Distributions
using Printf
using Dates
using XLSX
using Main.Sys_Fast
using Main.Lib_Mole
using Main.Lib_Core
using Main.Sys_Flow
using HypothesisTests
import HypothesisTests: pvalue

export VISE_Regress_DDEF, VISE_GridSearch_DDEF, VISE_ExpandDesign_DDEF,
    VISE_Predict_DDEF, VISE_Execute_DDEF, VISE_CrossValidate_DDEF,
    VISE_GetTermNames_DDEF, VISE_ClampIndex_DDEF,
    VISE_SelectBestModel_DDEF, VISE_CalcMetrics_DDEF,
    VISE_SensitivityAnalysis_DDEF, VISE_GenerateScientificReport_DDEF,
    VISE_CalcVIF_DDEF, VISE_LackOfFit_DDEF, VISE_GenerateAnovaTable_DDEF,
    VISE_PerformNormalityTest_DDEF, VISE_ExportToExcel_DDEF,
    VISE_ExtractDecayModifiers_DDEF

struct VISE_RegressionResult_DDES
    Beta::Vector{Float64}
    TermNames::Vector{String}
    R2::Float64
    R2_Adj::Float64
    RMSE::Float64
    AIC::Float64
    F_Stat::Float64
    P_Value::Float64
    P_Coefs::Vector{Float64}
    SE_Coefs::Vector{Float64}
    t_Stats::Vector{Float64}
    VIFs::Vector{Float64}
    Leverage::Vector{Float64}
    Outliers::Vector{Int}
    Condition::Float64
    ModelType::String
    N_Samples::Int
    Status::String
end

Base.Dict(r::VISE_RegressionResult_DDES) = Dict{String, Any}(
    "Coefs" => r.Beta, "TermNames" => r.TermNames, "R2" => r.R2, "R2_Adj" => r.R2_Adj,
    "RMSE" => r.RMSE, "AIC" => r.AIC, "F_Stat" => r.F_Stat, "P_Value" => r.P_Value,
    "P_Coefs" => r.P_Coefs, "SE_Coefs" => r.SE_Coefs, "t_Stats" => r.t_Stats,
    "VIFs" => r.VIFs, "Leverage" => r.Leverage, "Outliers" => r.Outliers,
    "Condition" => r.Condition, "ModelType" => r.ModelType, "N_Samples" => r.N_Samples, "Status" => r.Status
)

# ==============================================================================
# PART A: MODELLING ARCHITECTURE & DESIGN EXPANSION
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 1: REGRESSION TERM GENERATOR
# ------------------------------------------------------------------------------

"""
    VISE_GetTermNames_DDEF(InNames, ModelType) -> Vector{String}
Generates human-readable names for regression terms (Factor Interactions and Polynomials).
"""
function VISE_GetTermNames_DDEF(InNames::AbstractVector{<:AbstractString}, ModelType::Any)
    m_type = Main.Lib_Core.CORE_GetModelType_DDEF(ModelType)
    return VISE_GetTerms_DDEF(m_type, InNames)
end

const VISE_FactorPairs_DDEC = ((1, 2), (1, 3), (2, 3))

VISE_GetTerms_DDEF(::Main.Lib_Core.CORE_ModelLinear_DDES, InNames) = ["Intercept"; InNames]
function VISE_GetTerms_DDEF(::Main.Lib_Core.CORE_ModelQuadratic_DDES, InNames)
    names = ["Intercept"; InNames]
    for (c1, c2) in VISE_FactorPairs_DDEC
        push!(names, "$(InNames[c1]) × $(InNames[c2])")
    end
    for n in InNames
        push!(names, "$(n)²")
    end
    return names
end

VISE_GetParamCount_DDEF(::Main.Lib_Core.CORE_ModelLinear_DDES) = 4
VISE_GetParamCount_DDEF(::Main.Lib_Core.CORE_ModelQuadratic_DDES) = 10
VISE_GetParamCount_DDEF(m) = VISE_GetParamCount_DDEF(Main.Lib_Core.CORE_GetModelType_DDEF(m))

# ------------------------------------------------------------------------------
# SECTION 2: DESIGN MATRIX EXPANSION ENGINE
# ------------------------------------------------------------------------------

"""
    VISE_ExpandDesign_DDEF(X, ModelType) -> Matrix{Float64}
Expands raw factor matrix into a design matrix (intercept + linear + interactions + quadratic).
"""
function VISE_ExpandDesign_DDEF(X::AbstractMatrix{Float64}, ModelType::AbstractString)
    m_type = Main.Lib_Core.CORE_GetModelType_DDEF(ModelType)
    return VISE_ExpandMatrix_DDEF(m_type, X)
end

VISE_ExpandMatrix_DDEF(::Main.Lib_Core.CORE_ModelLinear_DDES, X) = hcat(ones(size(X, 1)), X)
function VISE_ExpandMatrix_DDEF(::Main.Lib_Core.CORE_ModelQuadratic_DDES, X)
    N = size(X, 1)
    Xd = Matrix{Float64}(undef, N, 10)
    fill!(view(Xd, :, 1), 1.0)
    copyto!(view(Xd, :, 2:4), X)
    
    @inbounds @views begin
        @. Xd[:, 5] = X[:, 1] * X[:, 2]
        @. Xd[:, 6] = X[:, 1] * X[:, 3]
        @. Xd[:, 7] = X[:, 2] * X[:, 3]
        # Squared Terms (8, 9, 10)
        @. Xd[:, 8:10] = abs2(X)
    end
    return Xd
end

# ------------------------------------------------------------------------------
# SECTION 3: UNIVERSAL PREDICTION GATEWAY
# ------------------------------------------------------------------------------

"""
    VISE_Predict_DDEF(Model::Dict, X_Raw) -> Vector{Float64}
Universal prediction gateway for OLS models (Linear / Quadratic).
"""
function VISE_Predict_DDEF(Model::AbstractDict, X_Raw::Any)
    X = VISE_PrepareMatrix_DDEF(X_Raw)
    m_type = get(Model, "ModelType", "linear")
    Xd = VISE_ExpandDesign_DDEF(X, m_type)
    Beta = collect(Float64, get(Model, "Coefs", zeros(size(Xd, 2))))
    return Xd * Beta
end

VISE_PrepareMatrix_DDEF(X::AbstractMatrix) = Float64.(collect(X))
VISE_PrepareMatrix_DDEF(X::AbstractVector{<:AbstractVector}) = Float64.(reduce(vcat, transpose.(collect.(X))))
function VISE_PrepareMatrix_DDEF(X::AbstractVector)
    length(X) % 3 == 0 && return reshape(Float64.(collect(X)), :, 3)
    return Float64.(collect(X))
end

# ==============================================================================
# PART B: SCIENTIFIC REGRESSION KERNEL (OLS)
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 4: REGRESSION ENGINE & NUMERICAL CLAMPING
# ------------------------------------------------------------------------------

"""
    VISE_ClampIndex_DDEF(idx, len) -> Int
Clamps an index to valid range [1, len] to prevent BoundsError.
"""
VISE_ClampIndex_DDEF(idx::Integer, len::Integer) = clamp(Int(idx), 1, Int(len))
VISE_ClampIndex_DDEF(idx::AbstractFloat, len::Integer) = clamp(round(Int, idx), 1, Int(len))

"""
    VISE_Regress_DDEF(X, Y, ModelType; [InNames]) -> Dict
Strict OLS regression for experimental data analysis and modelling.
"""
function VISE_Regress_DDEF(X_Raw::AbstractMatrix{Float64}, Y::AbstractVector{Float64}, ModelType::AbstractString; InNames::AbstractVector{<:AbstractString}=String[])
    Xd = VISE_ExpandDesign_DDEF(X_Raw, ModelType)
    try
        n, p = size(Xd)
        c = cond(Xd)
        c > 1e11 && return Dict{String, Any}("Status" => "FAIL", "Error" => Printf.@sprintf("[SENTRY] Ill-conditioned matrix (cond: %.2e). Numeric stability compromised.", c))
        n < p && throw(ArgumentError("Underdetermined system (N < P). More parameters ($p) than samples ($n)."))
        
        F = qr(Xd)
        rank_val = rank(F.R)
        rank_val < p && throw(ArgumentError("Rank deficient design matrix (Rank: $rank_val / Need: $p). Collinearity detected."))

        Beta = F \ Y
        Yp = Xd * Beta
        Resid = Y .- Yp
        R2, R2a, RMSE, AIC = VISE_CalcMetrics_DDEF(Y, Yp, p)
        fs, pv = NaN, NaN
        pc, sec, ts = fill(NaN, p), fill(NaN, p), fill(NaN, p)
        sst = var(Y) * (n - 1)
        sse = sum(abs2, Resid)

        # Implementation of Hat Matrix for leverage diagnostics (h_ii)
        h_ii = vec(sum(abs2, Matrix(F.Q); dims=2))
        out_idx = findall(r -> abs(r) > 3 * RMSE, Resid)

        if n > p && sst > 1e-9 && sse > 1e-9
            msr, mse = (sst - sse) / max(1, p - 1), sse / (n - p)
            if mse > 1e-15
                fs = msr / mse
                pv = 1.0 - cdf(FDist(max(1, p - 1), n - p), fs)
                vb = mse * inv(Xd' * Xd)
                sec = sqrt.(max.(0.0, diag(vb)))
                ts = Beta ./ max.(sec, 1e-15)
                pc = 2.0 .* (1.0 .- cdf.(TDist(n - p), abs.(ts)))
            end
        end

        X_Coded_Raw = Main.Lib_Core.CORE_CodeMatrix_DDEF(X_Raw)
        Xd_Vif      = VISE_ExpandDesign_DDEF(X_Coded_Raw, ModelType)
        v           = VISE_CalcVIF_DDEF(Xd_Vif)
        tn          = VISE_GetTermNames_DDEF(InNames, ModelType)
        
        res = VISE_RegressionResult_DDES(
            Beta, tn, 
            Float64(R2), Float64(R2a), Float64(RMSE), Float64(AIC), 
            Float64(fs), Float64(pv), pc, sec, ts, v, h_ii, out_idx, 
            Float64(c), string(ModelType), n, "OK"
        )
        return Dict(res)
    catch e
        Main.Sys_Fast.FAST_Log_DDEF("VISE", "MODELLING", "Diagnostics Failure: $(string(e))", "FAIL")
        return Dict{String, Any}("Status" => "FAIL", "Error" => string(e))
    end
end

# ------------------------------------------------------------------------------
# SECTION 5: MULTICOLLINEARITY DIAGNOSTICS (VIF)
# ------------------------------------------------------------------------------

"""
    VISE_CalcVIF_DDEF(X_Design) -> Vector{Float64}
Calculates Variance Inflation Factors (VIF) to detect multicollinearity.
"""
function VISE_CalcVIF_DDEF(X_Design::AbstractMatrix)
    n, p = size(X_Design)
    p <= 1 && return Float64[]

    # Isolate independent variables and initialize variance inflation vector.
    X     = X_Design[:, 2:end]
    p_eff = p - 1
    vifs  = fill(1.0, p)
    try
        C = cor(X)
        if cond(C) > 1e12
            # Apply Tikhonov-style regularisation to maintain stability in degenerate designs.
            C += I * 1e-6
        end
        v_diag       = diag(inv(C))
        vifs[2:end] .= v_diag
    catch
        # Assign extreme fallback values for non-invertible or ill-conditioned matrices.
        vifs[2:end] .= 999.0 
    end
    return vifs
end

# ------------------------------------------------------------------------------
# SECTION 6: LACK-OF-FIT STATISTICAL TEST
# ------------------------------------------------------------------------------

"""
    VISE_LackOfFit_DDEF(X_Design, Y) -> (F_Stat, P_Value)
Performs Lack-of-Fit test to determine if model structure is adequate (requires replicates).
"""
function VISE_LackOfFit_DDEF(X_Design::AbstractMatrix, Y::AbstractVector)
    n, p = size(X_Design)
    unique_rows = Dict{Vector{Float64},Vector{Float64}}()
    for i in 1:n
        row = round.(Float64.(X_Design[i, :]); digits=5)
        push!(get!(unique_rows, row, Float64[]), Y[i])
    end
    ss_pe, df_pe = 0.0, 0
    for vals in values(unique_rows)
        if length(vals) > 1
            ss_pe += sum(abs2, vals .- mean(vals))
            df_pe += (length(vals) - 1)
        end
    end
    df_pe == 0 && return (NaN, NaN)
    Beta = X_Design \ Y
    ss_res = sum(abs2, Y .- (X_Design * Beta))
    df_res = n - p
    ss_lof, df_lof = max(0.0, ss_res - ss_pe), df_res - df_pe
    df_lof <= 0 && return (NaN, NaN)
    ms_pe = ss_pe / df_pe
    ms_pe < 1e-12 && return (999.0, 0.0)
    f_stat = (ss_lof / df_lof) / ms_pe
    return (f_stat, 1.0 - cdf(FDist(df_lof, df_pe), f_stat))
end

# ==============================================================================
# PART C: ACADEMIC VALIDATION & ANOVA
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 7: ANOVA TABLE CONSTRUCTOR
# ------------------------------------------------------------------------------

"""
    VISE_GenerateAnovaTable_DDEF(Model::Dict, X::AbstractMatrix, Y::AbstractVector) -> DataFrame
Constructs a comprehensive ANOVA table for experimental validation.
"""
function VISE_GenerateAnovaTable_DDEF(Model::AbstractDict, X_Raw::Any, Y_Raw::Any)
    X = VISE_PrepareMatrix_DDEF(X_Raw)
    Y = (Y_Raw isa AbstractVector) ? Float64.(collect(Y_Raw)) : Y_Raw
    n = length(Y)
    
    m_type = Main.Lib_Core.CORE_GetModelType_DDEF(string(get(Model, "ModelType", "linear")))
    p      = VISE_GetParamCount_DDEF(m_type)

    Y_Pred = VISE_Predict_DDEF(Model, convert(Matrix{Float64}, X))
    Resid  = Y .- Y_Pred

    # Execution of Sum of Squares (SS) partitions for variance analysis.
    SS_Total = var(Y) * (n - 1)
    SS_Resid = sum(abs2, Resid)
    SS_Reg   = max(0.0, SS_Total - SS_Resid)

    # Determination of degrees of freedom across structural model components.
    DF_Total = n - 1
    DF_Reg   = max(1, p - 1)
    DF_Resid = max(0, n - p)

    # Implementation of Lack-of-Fit verification logic based on coordinate replicates.
    unique_rows = Dict{Vector{Float64},Vector{Float64}}()
    for i in 1:n
        row = X[i, :]
        if haskey(unique_rows, row)
            push!(unique_rows[row], Y[i])
        else
            unique_rows[row] = [Y[i]]
        end
    end

    SS_PE = 0.0
    DF_PE = 0
    for (r, vals) in unique_rows
        if length(vals) > 1
            SS_PE += sum(abs2, vals .- mean(vals))
            DF_PE += (length(vals) - 1)
        end
    end

    SS_LOF = max(0.0, SS_Resid - SS_PE)
    DF_LOF = DF_Resid - DF_PE

    # Integration of partitioned variance components into a final summary table.
    sources = ["Model", "Residual", "Total"]
    ss_vals = [SS_Reg, SS_Resid, SS_Total]
    df_vals = [DF_Reg, DF_Resid, DF_Total]

    if DF_PE > 0 && DF_LOF > 0
        insert!(sources, 2, "Lack of Fit")
        insert!(ss_vals, 2, SS_LOF)
        insert!(df_vals, 2, DF_LOF)

        insert!(sources, 3, "Pure Error")
        insert!(ss_vals, 3, SS_PE)
        insert!(df_vals, 3, DF_PE)
    end

    df_anova = DataFrame(
        Source = sources,
        SS     = round.(ss_vals; digits=4),
        df     = df_vals,
        MS     = fill(NaN, length(sources)),
        F      = fill(NaN, length(sources)),
        P      = fill(NaN, length(sources))
    )

    # Resolve derived metrics including Mean Squares, F-Statistics, and P-Values.
    for i in 1:nrow(df_anova)
        if df_anova.df[i] > 0
            df_anova.MS[i] = round(df_anova.SS[i] / df_anova.df[i]; digits=4)
        end
    end

    # Execution of model significance F-Test.
    idx_mod = findfirst(==("Model"), sources)
    idx_res = findfirst(==("Residual"), sources)

    if !isnothing(idx_mod) && !isnothing(idx_res)
        if df_anova.MS[idx_res] > 1e-12
            f                   = df_anova.MS[idx_mod] / df_anova.MS[idx_res]
            df_anova.F[idx_mod] = round(f; digits=2)
            df_anova.P[idx_mod] = round(1.0 - cdf(FDist(df_anova.df[idx_mod], df_anova.df[idx_res]), f); digits=4)
        end
    end

    # Execution of Lack-of-Fit significance verification.
    idx_lof = findfirst(==("Lack of Fit"), sources)
    idx_pe = findfirst(==("Pure Error"), sources)
    if !isnothing(idx_lof) && !isnothing(idx_pe)
        if df_anova.MS[idx_pe] > 1e-12
            f_lof               = df_anova.MS[idx_lof] / df_anova.MS[idx_pe]
            df_anova.F[idx_lof] = round(f_lof; digits=2)
            df_anova.P[idx_lof] = round(1.0 - cdf(FDist(df_anova.df[idx_lof], df_anova.df[idx_pe]), f_lof); digits=4)
        end
    end

    return df_anova
end

# ------------------------------------------------------------------------------
# SECTION 8: RESIDUAL NORMALITY ASSESSMENT (Shapiro-Wilk)
# ------------------------------------------------------------------------------

"""
    VISE_PerformNormalityTest_DDEF(Model, X, Y) -> Dict
Executes the Shapiro-Wilk test on model residuals for normality assessment.
"""
function VISE_PerformNormalityTest_DDEF(Model::AbstractDict, X_Raw::Any, Y_Raw::Any)
    X      = VISE_PrepareMatrix_DDEF(X_Raw)
    Y      = (Y_Raw isa AbstractVector) ? Float64.(collect(Y_Raw)) : Y_Raw
    m_type = get(Model, "ModelType", "linear")
    Xd     = VISE_ExpandDesign_DDEF(X, m_type)
    Beta   = get(Model, "Coefs", Float64[])
    
    isempty(Beta) && return Dict("p" => NaN, "IsNormal" => false)

    Resid = Y .- (Xd * Beta)

    try
        sw = HypothesisTests.ShapiroWilkTest(Resid)
        p  = pvalue(sw)::Float64
        return Dict(
            "p"        => round(p; digits=4), 
            "IsNormal" => p > 0.05, 
            "Test"     => "Shapiro-Wilk"
        )
    catch
        return Dict("p" => NaN, "IsNormal" => false, "Test" => "Fail")
    end
end

# ------------------------------------------------------------------------------
# SECTION 9: CORE STATISTICAL METRICS (R2, AIC, RMSE)
# ------------------------------------------------------------------------------

"""
    VISE_CalcMetrics_DDEF(Y_Real, Y_Pred, p) -> (R2, R2_Adj, RMSE, AIC)
Calculates core statistical metrics (R², Adjusted R², RMSE, AIC).
"""
function VISE_CalcMetrics_DDEF(Y_Real::AbstractVector{Float64}, Y_Pred::AbstractVector{Float64}, p::Int)
    n     = length(Y_Real)
    Resid = Y_Real .- Y_Pred
    SSE   = sum(abs2, Resid)
    SST   = var(Y_Real) * (n - 1)

    R2     = SST > 1e-9 ? 1.0 - SSE / SST : 0.0
    R2_Adj = n > p ? 1.0 - (1.0 - R2) * ((n - 1) / (n - p)) : 0.0
    RMSE   = n > p ? sqrt(SSE / (n - p)) : 0.0

    # Determine information criteria assuming normality of residual distribution.
    AIC = n > 0 && SSE > 0 ? n * log(SSE / n) + 2p : Inf

    return (R2, R2_Adj, RMSE, AIC)
end

# ------------------------------------------------------------------------------
# SECTION 10: AUTOMATED MODEL SELECTION
# ------------------------------------------------------------------------------

"""
    VISE_SelectBestModel_DDEF(X, Y, InNames) -> (BestModel, LogMsg)
Evaluates multiple candidate model structures and selects the optimal model.
"""
function VISE_SelectBestModel_DDEF(X::AbstractMatrix{Float64}, Y::AbstractVector{Float64}, InNames::AbstractVector{<:AbstractString}, RequestedType::AbstractString="Auto")::Tuple{Dict{String, Any}, String}
    n      = size(X, 1)
    k      = 3
    # 1 + 2*3 + 3*(3-1)/2 = 10
    p_quad = 10
    
    # Execution Logic: If a specific type is requested (and not 'Auto'), bypass model selection.
    req_type = lowercase(RequestedType)
    if req_type != "auto" && req_type != ""
        mod = VISE_Regress_DDEF(X, Y, req_type; InNames = InNames)
        mod["Q2"] = VISE_CrossValidate_DDEF(X, Y, req_type)
        return (convert(Dict{String, Any}, mod), "Forced $req_type")
    end

    # Evaluate candidate model structures including linear and quadratic variations.
    candidates = ["linear"]
    n > p_quad + 2 && push!(candidates, "quadratic")

    best_score  = -Inf
    best_mod    = Dict{String, Any}()
    log_details = String[]

    for type_str in candidates
        m_type = Main.Lib_Core.CORE_GetModelType_DDEF(type_str)
        mod = VISE_Regress_DDEF(X, Y, type_str; InNames = InNames)
        mod["Status"] != "OK" && continue

        q2  = VISE_CrossValidate_DDEF(X, Y, type_str)
        r2a = get(mod, "R2_Adj", 0.0)
        
        q2_safe  = isnan(q2) ? 0.0 : q2
        r2a_safe = isnan(r2a) ? 0.0 : r2a

        score = 0.6 * q2_safe + 0.4 * r2a_safe

        push!(log_details, "$(uppercasefirst(type_str)): R²Adj=$(round(r2a_safe, digits=3)), Q²=$(round(q2_safe, digits=3))")

        if score > best_score
            best_score     = score
            best_mod       = convert(Dict{String, Any}, mod)
            best_mod["Q2"] = q2_safe
        end
    end

    if isempty(best_mod)
        best_mod = Dict{String, Any}(
            "Status"    => "FAIL", 
            "Error"     => "All candidate models failed (collinear design or flat response variation).", 
            "ModelType" => "linear"
        )
        push!(log_details, "FAIL: Collinear Matrix / Zero Variance")
    end

    msg = join(log_details, " | ")
    
    return (best_mod, msg)
end

# ==============================================================================
# PART D: DYNAMIC OPTIMISATION & EXPLORATION
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 11: CROSS-VALIDATION & PRESS STATISTIC
# ------------------------------------------------------------------------------

"""
    VISE_CrossValidate_DDEF(X, Y, ModelType) -> Float64
Calculates Predicted R² (Q²) using the PRESS statistic and Hat Matrix shortcut.
"""
function VISE_CrossValidate_DDEF(X_Raw::AbstractMatrix{Float64}, Y::AbstractVector{Float64},
    ModelType::AbstractString)::Float64
    N     = length(Y)
    N < 4 && return NaN

    X_Design = VISE_ExpandDesign_DDEF(X_Raw, ModelType)

    try
        F     = qr(X_Design)
        Beta  = F \ Y
        Resid = Y .- (X_Design * Beta)
        h_ii  = vec(sum(abs2, Matrix(F.Q); dims=2))

        denom = max.(1.0 .- h_ii, 1e-6)
        PRESS = sum(abs2, Resid ./ denom)
        SST = var(Y) * (N - 1)
        return SST < 1e-9 ? 0.0 : 1.0 - PRESS / SST
    catch
        return NaN
    end
end

"""
    VISE_GridSearch_DDEF(Models, Goals, Bounds; [Steps], [DecayModifiers]) -> (X, Y_Pred, Scores)
Performs high-density grid search across factor space for desirability exploration.
When DecayModifiers are provided, predictions for affected outputs are penalised by
the exponential decay factor before desirability scoring.
"""
function VISE_GridSearch_DDEF(Models::AbstractVector, Goals::AbstractVector, X_Bounds::AbstractMatrix{Float64};
    Steps::Int=41, DecayModifiers::Vector{Main.Lib_Core.CORE_DecayModifier_DDES}=Main.Lib_Core.CORE_DecayModifier_DDES[])
    Dim = 3
    compute_threads = Main.Sys_Fast.FAST_GetComputeThreads_DDEF()
    eff_steps = (compute_threads <= 4) ? 21 : 41

    Ranges = [range(X_Bounds[i, 1], X_Bounds[i, 2]; length=eff_steps) for i in 1:Dim]
    Iter = Iterators.product(Ranges...)
    NumPoints = length(Iter)
    Candidates = Matrix{Float64}(undef, NumPoints, Dim)
    @inbounds for (i, pt) in enumerate(Iter)
        for d in 1:Dim
            Candidates[i, d] = pt[d]
        end
    end
    RefType = isempty(Models) ? "quadratic" : get(Models[1], "ModelType", "quadratic")
    X_Design = VISE_ExpandDesign_DDEF(Candidates, RefType)
    NumModels = length(Models)
    Predictions = zeros(Float64, NumPoints, NumModels)
    Active_Flags = falses(NumModels)
    # BLAS Thread Isolation: Prevents nested threading deadlocks (Threads.@threads + BLAS)
    # on Windows systems during high-concurrency grid searches.
    Main.Sys_Fast.FAST_Log_DDEF("VISE", "GRID_SEARCH", "Exploration Pulse [N=$NumPoints] - Dispatching $(NumModels) models...", "WAIT")
    Scores = Vector{Float64}(undef, NumPoints)
    
    old_blas = LinearAlgebra.BLAS.get_num_threads()
    LinearAlgebra.BLAS.set_num_threads(1)
    try
        # Pre-expand design matrices outside the thread loop to avoid garbage collection pressure
        X_Linear = (RefType == "linear") ? X_Design : VISE_ExpandDesign_DDEF(Candidates, "linear")
        X_Quadratic = (RefType == "quadratic") ? X_Design : VISE_ExpandDesign_DDEF(Candidates, "quadratic")

        # 1. Parallel Regression Matrix Multiplication (Allocation-Free)
        Threads.@threads for m in 1:NumModels
            Mod = Models[m]
            Mod["Status"] != "OK" && continue
            m_type_str = lowercase(get(Mod, "ModelType", "quadratic"))
            Beta = collect(Float64, Mod["Coefs"])
            
            X_eff = (m_type_str == "linear") ? X_Linear : X_Quadratic
            mul!(view(Predictions, :, m), X_eff, Beta)
            
            Active_Flags[m] = true
        end

        # 2. Parallel Multi-Objective Desirability Scoring
        active_idx = findall(Active_Flags)
        Scores = Vector{Float64}(undef, NumPoints)
        if isempty(active_idx)
            fill!(Scores, 1.0)
        else
            sum_weights = 0.0
            parsed_goals = Vector{Tuple}(undef, NumModels)
            for m in 1:NumModels
                gtup = Main.Lib_Core.CORE_ExtractGoal_DDEF(m <= length(Goals) ? Goals[m] : get(Models[m], "Goal", Dict()))
                parsed_goals[m] = gtup
                if m in active_idx; sum_weights += gtup[5] end
            end
            
            pow = sum_weights > 0.0 ? (1.0 / sum_weights) : (length(active_idx) > 0 ? 1.0 / length(active_idx) : 1.0)

            # Pre-compute grid-level decay lookup for consistency with BBO objective.
            grid_decay_lookup = Dict{Int, Vector{Main.Lib_Core.CORE_DecayModifier_DDES}}()
            for dm in DecayModifiers
                for oi in dm.AffectedOutputs
                    if oi >= 1 && oi <= NumModels
                        push!(get!(grid_decay_lookup, oi, Main.Lib_Core.CORE_DecayModifier_DDES[]), dm)
                    end
                end
            end
            
            Threads.@threads for i in 1:NumPoints
                s = 1.0
                @inbounds for m_idx in active_idx
                    pred_val = Predictions[i, m_idx]
                    # Decay-Coupled Correction: Penalise by e^(-lambda * t) for affected outputs.
                    if haskey(grid_decay_lookup, m_idx)
                        for dm in grid_decay_lookup[m_idx]
                            pred_val = Main.Lib_Core.CORE_ApplyDecayPenalty_DDEF(pred_val, dm, view(Candidates, i, :))
                        end
                    end
                    s *= Main.Lib_Core.CORE_CalcDesirability_DDEF(pred_val, parsed_goals[m_idx])
                end
                res_val = s^pow
                @inbounds Scores[i] = (isnan(res_val) || isinf(res_val)) ? 0.0 : clamp(res_val, 0.0, 1.0)
            end
        end
    finally
        LinearAlgebra.BLAS.set_num_threads(old_blas)
    end

    return Candidates, Predictions, Scores
end

function VISE_SensitivityAnalysis_DDEF(Model::AbstractDict, X_Point::AbstractVector{Float64}, X_Clean::AbstractMatrix{Float64})
    Dim, gradients = 3, zeros(3)
    base_pred = VISE_Predict_DDEF(Model, reshape(X_Point, 1, 3))[1]
    
    @inbounds for i in 1:3
        c_min, c_max = minimum(view(X_Clean, :, i)), maximum(view(X_Clean, :, i))
        span  = max(c_max - c_min, 1e-6)
        delta = span * 0.001
        
        Xp = copy(X_Point)
        Xp[i] += delta
        pred_p = VISE_Predict_DDEF(Model, reshape(Xp, 1, 3))[1]
        gradients[i] = abs(pred_p - base_pred) / delta
    end
    
    total = sum(gradients)
    # Return relative percentage contributions (Normalised to 1.0)
    return total > 1e-15 ? gradients ./ total : fill(1.0/3.0, 3)
end

function VISE_GenerateScientificReport_DDEF(Res::AbstractDict)
    io = IOBuffer()
    write(io, "# DOECISORY ANALYTICAL REPORT (SCIENTIFIC COMPENDIUM)\n")
    write(io, Printf.@sprintf("*Protocol Execution: %s | [ACADEMIC PRECISION MODE] *\n", Dates.format(now(), "yyyy-mm-dd HH:MM")))
    write(io, "---\n\n")

    if haskey(Res, "Vitals") && !isnothing(Res["Vitals"])
        v = Res["Vitals"]
        write(io, "### I. Experimental Design Vitals\n")
        write(io, "Rigorous mathematical audit of the underlying design matrix topology.\n\n")
        
        d_val   = get(v, "D", 0.0)
        c_val   = get(v, "Condition", Inf)
        lof_val = get(v, "LOF", 1.0)

        @printf(io, "- **D-Efficiency**: %.2f%% (Goal: >60%% for industrial robustness)\n", d_val * 100)
        @printf(io, "- **Condition Number**: %.2e (Goal: <1e4 for numerical stability)\n", c_val)
        @printf(io, "- **Lack-of-Fit (P)**: %.4f ", lof_val)
        
        if lof_val < 0.05
            write(io, "(`SIGNIFICANT` - Potential systematic bias or missing higher-order terms)\n")
            write(io, "> [!CAUTION]\n> **Critical Lack-of-Fit**: The model fails to capture the underlying curvature. Optimisation based on this surface may be physically misleading.\n")
        else
            write(io, "(`NON-SIGNIFICANT` - Model captures the underlying phenomenon accurately)\n")
        end
        write(io, "\n")
    end

    write(io, "### II. Response Surface Dimension Analysis\n")
    out_names = get(Res, "DisplayOutNames", Res["OutNames"])
    for (m_idx, name) in enumerate(out_names)
        mod = Res["Models"][m_idx]
        mod["Status"] != "OK" && continue

        r2a  = get(mod, "R2_Adj", NaN)
        q2   = get(mod, "Q2", NaN)
        rmse = get(mod, "RMSE", 0.0)
        aic  = get(mod, "AIC", NaN)

        write(io, "#### Response: **$(name)**\n")
        write(io, Printf.@sprintf("- **Fitness (Adj. R²)**: %.4f (Variance explained)\n", r2a))
        write(io, Printf.@sprintf("- **Predictivity (Q²)**: %.4f (Leave-one-out cross-validation)\n", q2))
        write(io, Printf.@sprintf("- **Standard Error (RMSE)**: %.4f\n", rmse))

        quality = q2 > 0.85 ? "SUPERIOR" : q2 > 0.7 ? "ROBUST" : q2 > 0.4 ? "FORMATIVE" : "TENTATIVE"
        write(io, "- **Inference Reliability**: `$quality` Profile. ")
        
        if q2 > 0.7
            write(io, "The model exhibits strong extrapolative potential within the defined design space.\n")
        else
            write(io, "Exercise caution during phase transition; additional data points may be required for high-fidelity mapping.\n")
        end

        gap = r2a - q2
        if gap > 0.20
            msg = Printf.@sprintf("> [!WARNING]\n> **High Overfitting Risk**: A significant gap (%.2f) detected between fitness and predictivity. The model is likely capturing experimental noise rather than true physical trends.\n", gap)
            write(io, msg)
        elseif gap < 0.10 && r2a > 0.70
            write(io, "> [!TIP]\n> **Excellent Model Stability**: The high alignment between R² and Q² suggests a highly reliable scientific model.\n")
        end

        sens = get(Res, "Sensitivities", [])
        if !isempty(sens) && m_idx <= length(sens)
            s_vec = sens[m_idx]
            in_names = get(Res, "DisplayInNames", get(Res, "InNames", []))
            if !isempty(s_vec) && length(s_vec) == length(in_names)
                perm = sortperm(s_vec; rev=true)
                write(io, Printf.@sprintf("- **Primary Driver**: `%s` (contributes %.1f%% to response variance).\n", in_names[perm[1]], s_vec[perm[1]]*100))
            end
        end
        write(io, "\n")
    end

    if !isempty(get(Res, "BestPoint", []))
        write(io, "### III. Global Optimum & Control Topology\n")
        @printf(io, "- **Composite Desirability (D)**: %.4f\n", get(Res, "BestScore", 0.0))

        best_pt  = Res["BestPoint"]
        in_names = get(Res, "InNames", [])
        write(io, "- **Optimal Factor Settings**:\n")
        for (i, val) in enumerate(best_pt)
            @printf(io, "  - *%s*: %.4f\n", in_names[i], val)
        end
        write(io, "\n> [!NOTE]\n> Stability analysis suggests these coordinates reside within a high-confidence 'Optimal Zone' for experimental reproducibility.\n\n")
    else
        write(io, "### III. Global Optimum & Control Topology\n")
        write(io, "> [!IMPORTANT]\n> **Global Optimisation in Progress**: Mathematical convergence in the background. Results will be visible in Pulse #2.\n\n")
    end

    write(io, "*Generated via DoECISORY $(Main.Sys_Fast.FAST_Data_DDEC.VERSION). Formatted in compliance with academic reporting standards.*\n")

    return String(take!(io))
end

# ------------------------------------------------------------------------------
# SECTION 12: PHASE DATA LOADER & INGESTION
# ------------------------------------------------------------------------------

"""
    VISE_LoadPhaseData_DDEF(FilePath, Phase, C, Log) -> DataFrame
High-fidelity data loader that filters global experiment records for phase-specific analysis.
"""
function VISE_LoadPhaseData_DDEF(FilePath::String, Phase::String, C, Log)
    df = Main.Sys_Fast.FAST_ReadExcel_DDEF(FilePath, C.SHEET_DATA)
    isempty(df) && return DataFrame()
    # Filter for Phase-Specific Records to ensure isolated logic
    # Filter for Phase-Specific Records to ensure isolated logic
    if hasproperty(df, Symbol(C.COL_PHASE))
        df_p = filter(r -> string(r[C.COL_PHASE]) == Phase, df)
        return isempty(df_p) ? df : df_p # Fallback to all if Phase-ID tagging is missing
    end
    return df
end

# ------------------------------------------------------------------------------
# SECTION 13: ENSEMBLE MODELLING ORCHESTRATOR
# ------------------------------------------------------------------------------

"""
    VISE_TrainEnsemble_DDEF(X, Y, InNames, ModelType, Goals, Log) -> Vector{Dict}
Parallelised ensemble trainer that selects the optimal model structure for each response variable.
"""
function VISE_TrainEnsemble_DDEF(X::AbstractMatrix{Float64}, Y::AbstractMatrix{Float64}, InNames::AbstractVector{<:AbstractString}, ModelType::AbstractString, Goals::AbstractVector, Log)::Vector{Dict{String, Any}}
    n_out = size(Y, 2)
    models = Vector{Dict{String, Any}}(undef, n_out)
    tasks = Task[]
    for m in 1:n_out
        t = Threads.@spawn begin
            try
                mod, log_msg = VISE_SelectBestModel_DDEF(X, Y[:, m], InNames, ModelType)
                # Attach Metadata for Traceability
                if mod["Status"] == "OK"
                    mod["Goal"] = m <= length(Goals) ? Goals[m] : Dict{String, Any}()
                end
                mod["ModelIndex"] = Int(m)
                models[m] = mod
                Log("VISE", "MODELLING", "Output $m ($ModelType): $(string(log_msg))", "OK")
            catch e
                Log("VISE", "ERR", "Output $m modelling failed: $(string(e))", "FAIL")
                models[m] = Dict{String, Any}("Status" => "FAIL", "Error" => string(e))
            end
        end
        push!(tasks, t)
    end
    wait.(tasks)
    return models
end

# ------------------------------------------------------------------------------
# SECTION 14: SYSTEM EXECUTION GATEWAY (VISE_EXECUTE)
# ------------------------------------------------------------------------------

function VISE_Execute_DDEF(DataFile::AbstractString, Phase::AbstractString, Goals::AbstractVector, ModelType::AbstractString="Auto"; 
    Opts=Dict{String,Any}(), ConfigUpdates::Dict{String,Any}=Dict{String,Any}(), t_start::Float64=time(), RenderMode::Symbol=:Full, Optim::Bool=true)
    t0 = t_start
    C, Log = Main.Sys_Fast.FAST_Data_DDEC, Main.Sys_Fast.FAST_Log_DDEF
    Log("VISE", "INITIALISATION", "Analysing Phase: $Phase (File: $(basename(DataFile)))", "WAIT")
    
    # 1. Load Data & Config
    df_raw = VISE_LoadPhaseData_DDEF(DataFile, Phase, C, Log)
    isempty(df_raw) && return Dict("Status" => "FAIL", "Message" => "Data load failed: Phase $Phase not found in $DataFile.")
    
    config = Main.Sys_Fast.FAST_ReadConfig_DDEF(DataFile)
    
    # 2. Execute Core Analytical Pipeline (Staged Rendering Support)
    res, sheets_to_commit = VISE_ExecuteCore_DDEF(df_raw, config, Phase, Goals, ModelType; Opts=Opts, t_start=t0, RenderMode=RenderMode, Optim=Optim)
    
    res["Status"] != "OK" && return res

    # 3. Handle Configuration Merging & Commit to Disk
    if !isempty(ConfigUpdates)
        for (k, v) in ConfigUpdates
            config[k] = v
        end
        df_cfg = DataFrame(PARAMETER=["MasterConfig"], VALUE_JSON=[JSON3.write(config)])
        sheets_to_commit[C.SHEET_CONFIG] = df_cfg
    end
    
    if Optim
        Log("VISE", "IO_FLUSH", "Committing analytical updates to $DataFile...", "WAIT")
        Main.Sys_Fast.FAST_SafeExcelWrite_DDEF(DataFile, sheets_to_commit)
    else
        res["_Hidden_Sheets"] = sheets_to_commit
    end
    
    elapsed_total = round(time() - t0; digits=1)
    res["Elapsed"] = "$(elapsed_total)s"
    
    Log("VISE", "COMPLETE", "Analytical Orchestration Finalised ($(res["Elapsed"])).", "OK")
    
    return res
end

"""
    VISE_ExecuteCore_DDEF(df_raw, config, Phase, Goals, ModelType; Opts, t_start) -> (Dict, Dict)
Orchestrates the scientific analytical pipeline entirely in memory. Target for JIT warmup.
"""
function VISE_ExecuteCore_DDEF(df_raw::DataFrame, config::AbstractDict, Phase::AbstractString, Goals::AbstractVector, ModelType::AbstractString="Auto"; 
    Opts=Dict{String,Any}(), t_start::Float64=time(), RenderMode::Symbol=:Full, Optim::Bool=true)
    
    C, Log = Main.Sys_Fast.FAST_Data_DDEC, Main.Sys_Fast.FAST_Log_DDEF
    t0 = t_start
    
    X_Clean, Y_Clean, InNames, OutNames, valid_mask = VISE_IngestMatrices_DDEF(df_raw, config, C, Log)
    n_samples, n_out = size(X_Clean, 1), size(Y_Clean, 2)
    
    if n_samples < 3
        return Dict("Status" => "FAIL", "Message" => "Insufficient data (N=$n_samples). Minimum 3 valid rows required."), Dict()
    end
    
    radio_audit = VISE_ApplyDecayKernel_DDEF!(X_Clean, Y_Clean, InNames, OutNames, df_raw, config, Opts, C, Log)
    eff_model = ModelType == "Auto" ? (n_samples > 12 ? "quadratic" : "linear") : lowercase(ModelType)
    if (lowercase(ModelType) != "auto" && lowercase(ModelType) != "") 
        Log("VISE", "MODELLING", "User Directive: Forcing $eff_model model architecture.", "INFO")
    end
    
    models = VISE_TrainEnsemble_DDEF(X_Clean, Y_Clean, InNames, eff_model, Goals, Log)
    
    InNames_v = collect(String, InNames)
    OutNames_v = collect(String, OutNames)
    
    DispInNames  = copy(InNames_v)
    DispOutNames = copy(OutNames_v)
    r_opts = get(Opts, "RadioOpts", Dict{String,Any}())
    if get(r_opts, "Apply", false)
        f_dict = get(r_opts, "Forward", Dict{String,Any}())
        r_dict = get(r_opts, "ReverseMap", Dict{String,Any}())
        for (i, n) in enumerate(DispInNames)
            if haskey(f_dict, n)
                disp_n = get(f_dict[n], "Name", "")
                disp_u = get(f_dict[n], "Unit", "")
                !isempty(disp_n) && (DispInNames[i] = disp_n * (isempty(disp_u) ? "" : " ($disp_u)"))
            end
        end
        for (i, n) in enumerate(DispOutNames)
            if haskey(r_dict, n)
                disp_n = get(r_dict[n], "Name", "")
                disp_u = get(r_dict[n], "Unit", "")
                !isempty(disp_n) && (DispOutNames[i] = disp_n * (isempty(disp_u) ? "" : " ($disp_u)"))
            end
        end
    end

    # Mathematical Optimisation: BBO Pulse handled concurrently or skipped for Priority Start
    bp, bs, ldf, SC, warns = if Optim
        VISE_RunOptimisation_DDEF(X_Clean, models, Goals, config, Phase, InNames_v, OutNames_v, Opts, C, Log)
    else
        [], 0.0, DataFrame(), zeros(1), String[]
    end
    
    Y_Pred, Actual_Scores = VISE_GeneratePredictions_DDEF(X_Clean, Y_Clean, models, Goals)
    df_updated = VISE_PreparePredictionsSheet_DDEF(df_raw, Phase, Y_Pred, Actual_Scores, valid_mask, OutNames_v, C, Log)
    
    anova_tables = Vector{DataFrame}()
    normality_res = Vector{Dict}()
    residuals = Vector{Vector{Float64}}()
    sens_list = Vector{Vector{Float64}}()
    for i in 1:n_out
        m = models[i]
        push!(anova_tables, VISE_GenerateAnovaTable_DDEF(m, X_Clean, Y_Clean[:, i]))
        push!(normality_res, VISE_PerformNormalityTest_DDEF(m, X_Clean, Y_Clean[:, i]))
        push!(residuals, Y_Clean[:, i] .- Y_Pred[:, i])
        
        sens_point = isempty(bp) ? vec(mean(X_Clean; dims=1)) : bp
        push!(sens_list, VISE_SensitivityAnalysis_DDEF(m, sens_point, X_Clean))

        r2a, q2 = get(m, "R2_Adj", 0.0), get(m, "Q2", 0.0)
        (r2a - q2) > 0.20 && push!(warns, "$(DispOutNames[i]): Large R2 gap ($(round(r2a-q2; digits=2))). Potential overfitting.")
    end
    
    # Model Diagnostic Statistics (LOF, ANOVA, Normality, Vitals)
    vitals = Dict("D" => 0.0, "Condition" => Inf, "MaxVIF" => 0.0, "LOF" => 1.0)
    try
        best_m_idx = findfirst(m -> get(m, "ModelType", "") == "quadratic", models)
        isnothing(best_m_idx) && (best_m_idx = 1)
        m_type_str = get(models[best_m_idx], "ModelType", "linear")
        
        X_Coded = Main.Lib_Core.CORE_CodeMatrix_DDEF(X_Clean)
        Xd_health = VISE_ExpandDesign_DDEF(X_Coded, m_type_str)
        m_health = Main.Lib_Core.CORE_CalcDesignMetrics_DDEF(Xd_health)
        
        vitals["D"] = m_health["D"]
        vitals["Condition"] = m_health["Condition"]
        vif_list = [maximum(get(m, "VIFs", [0.0])[2:end]) for m in models if haskey(m, "VIFs") && length(m["VIFs"]) > 1]
        vitals["MaxVIF"] = isempty(vif_list) ? 1.0 : maximum(vif_list)
        
        if n_samples > size(Xd_health, 2) + 2
            _, p_lof = VISE_LackOfFit_DDEF(Xd_health, view(Y_Clean, :, 1))
            vitals["LOF"] = p_lof
        end
    catch e
        Log("VISE", "METRICS_WARN", "Design quality evaluation incomplete: $e", "WARN")
    end
    
    opts_with_mode = copy(Opts)
    opts_with_mode["Mode"] = RenderMode

    graphs = Main.Lib_Arts.ARTS_Render_DDEF(models, X_Clean, Y_Clean, DispInNames, DispOutNames, Goals, 
        [get(m, "R2_Adj", 0.0) for m in models], [get(m, "Q2", 0.0) for m in models], opts_with_mode, ldf,
        sens_list, residuals)
        
    sheets_to_commit = Dict(C.SHEET_DATA => df_updated)
    sheet_leader     = C.PREFIX_LEADERS * Phase
    sheets_to_commit[sheet_leader] = ldf
    
    res_bundle = VISE_AssembleBundle_DDEF(Phase, InNames_v, OutNames_v, DispInNames, DispOutNames, models, bp, bs, ldf, X_Clean, Y_Clean, Opts, 
        Goals, Y_Pred, Actual_Scores, radio_audit, warns, vitals, anova_tables, normality_res, residuals, sens_list, graphs, t_start, C)
        
    return res_bundle, sheets_to_commit
end

# ------------------------------------------------------------------------------
# SECTION 15: INTERNAL LOGISTIC HELPERS
# ------------------------------------------------------------------------------

function VISE_IngestMatrices_DDEF(df::DataFrame, config::AbstractDict, C, Log)
    # Strict lookup via System Constants (VARIA_, RESULT_)
    in_cols = filter(n -> startswith(uppercase(strip(string(n))), C.PRE_INPUT), names(df))
    out_cols = filter(n -> startswith(uppercase(strip(string(n))), C.PRE_RESULT), names(df))
    
    nr = nrow(df)
    in_len, out_len = length(in_cols), length(out_cols)
    
    # Stability Guard: Ensure we always have at least one column to prevent 0xN Matrix structural failures
    X = zeros(nr, max(1, in_len))
    Y = fill(NaN, nr, max(1, out_len))
    
    for (ci, c) in enumerate(in_cols) X[:, ci] .= Main.Sys_Fast.FAST_SafeNum_DDEF.(df[!, c]) end
    for (ci, c) in enumerate(out_cols) Y[:, ci] .= Main.Sys_Fast.FAST_SafeNum_DDEF.(df[!, c]) end
    
    mask = vec(all(!isnan, Y[:, 1:max(1, out_len)]; dims=2))
    xc, yc = X[mask, 1:in_len], Y[mask, 1:out_len]   
    
    # Strict Type Enforcement: Ensure names are Vector{String} to avoid MethodError in TrainEnsemble
    in_names = String[VISE_ResolveName_DDEF(string(n), C.PRE_INPUT, get(config, "Ingredients", []), C) for n in in_cols]
    out_names = String[VISE_ResolveName_DDEF(string(n), C.PRE_RESULT, get(config, "Outputs", []), C) for n in out_cols]
    
    # Final Matrix Emergency Fallback: If no columns were found (Warmup/Migration Safety)
    if isempty(xc) || size(xc, 2) == 0
        Log("VISE", "INGEST_FAIL", "Matrix Extraction Failure: No valid columns matched prefix $(C.PRE_INPUT).", "FAIL")
        return zeros(min(1, nr), 3), zeros(min(1, nr), 1), ["X1", "X2", "X3"], ["Y1"], [false]
    end
    
    return xc, yc, in_names, out_names, mask
end

VISE_ResolveName_DDEF(n, pfx, cfg, C) = let n_up=uppercase(strip(string(n))); match=findfirst(i->uppercase(pfx*strip(get(i,"Name","")))==n_up || startswith(n_up, uppercase(pfx*strip(get(i,"Name",""))*"_")), cfg); isnothing(match) ? replace(Main.Sys_Fast.FAST_CleanHeader_DDEF(n), Regex("(?i)^"*pfx)=>"") : cfg[match]["Name"] end

function VISE_ApplyDecayKernel_DDEF!(X, Y, in_n, out_n, df, config, opts, C, Log)
    audit = []
    !get(get(opts, "RadioOpts", Dict()), "Apply", false) && return audit
    
    r_opts = get(opts, "RadioOpts", Dict{String,Any}())
    fwd_dict = get(r_opts, "Forward", Dict{String,Any}())
    rev_dict = get(r_opts, "ReverseMap", Dict{String,Any}())
    
    ingreds = get(config, "Ingredients", [])
    
    N = size(X, 1)

    # Forward Decay (Inputs)
    for v_name in keys(fwd_dict)
        idx = findfirst(i -> get(i, "Name", "") == v_name, ingreds)
        isnothing(idx) && continue
        ing = ingreds[idx]
        
        v_idx = findfirst(==(v_name), in_n)
        
        hl_raw  = get(ing, "HalfLife", 0.0)
        hl_unit = get(ing, "HalfLifeUnit", "Hours")
        hl_min  = Main.Lib_Mole.MOLE_ConvertTimeToMinutes_DDEF(hl_raw, hl_unit)

        if hl_min > 0.0
            col_exp = Main.Sys_Fast.FAST_GetCol_DDEF(df, "TIME_EXP_MINS_" * v_name)
            
            dfs = Float64[]
            for i in 1:N
                t_min = isempty(col_exp) ? 0.0 : Main.Sys_Fast.FAST_SafeNum_DDEF(df[i, col_exp])
                df_row = exp(-log(2) * t_min / hl_min)
                
                if !isnothing(v_idx)
                    X[i, v_idx] *= df_row
                end
                push!(dfs, df_row)
            end
            
            type_lbl = isnothing(v_idx) ? "Forward (Fixed)" : "Forward (Input)"
            f_opts = get(fwd_dict, v_name, Dict())
            disp_name = get(f_opts, "Name", "")
            disp_name = isempty(disp_name) ? v_name : disp_name

            push!(audit, Dict(
                "Name"        => disp_name,
                "HalfLife"    => hl_raw,
                "Unit"        => hl_unit,
                "Type"        => type_lbl,
                "AvgDeltaT"   => isempty(col_exp) ? 0.0 : mean(Main.Sys_Fast.FAST_SafeNum_DDEF.(df[!, col_exp])),
                "AvgDF"       => isempty(dfs) ? 1.0 : mean(dfs),
                "IsCorrected" => true
            ))
        end
    end

    # Reverse Decay & Yield Transformation (Outputs)
    for (out_name, out_data) in rev_dict
        mapped_in_name = get(out_data, "Source", "None")
        (mapped_in_name == "None" || isempty(mapped_in_name)) && continue
        o_idx = findfirst(==(out_name), out_n)
        isnothing(o_idx) && continue

        idx = findfirst(i -> get(i, "Name", "") == mapped_in_name, ingreds)
        isnothing(idx) && continue
        ing = ingreds[idx]
        
        hl_raw  = get(ing, "HalfLife", 0.0)
        hl_unit = get(ing, "HalfLifeUnit", "Hours")
        hl_min  = Main.Lib_Mole.MOLE_ConvertTimeToMinutes_DDEF(hl_raw, hl_unit)

        if hl_min > 0.0
            col_meas = Main.Sys_Fast.FAST_GetCol_DDEF(df, "TIME_MEAS_MINS_" * mapped_in_name)
            col_exp  = Main.Sys_Fast.FAST_GetCol_DDEF(df, "TIME_EXP_MINS_" * mapped_in_name)
            
            dfs = Float64[]
            for i in 1:N
                t_meas = isempty(col_meas) ? 0.0 : Main.Sys_Fast.FAST_SafeNum_DDEF(df[i, col_meas])
                t_exp  = isempty(col_exp)  ? 0.0 : Main.Sys_Fast.FAST_SafeNum_DDEF(df[i, col_exp])
                
                df_row = exp(log(2) * t_meas / hl_min)
                A_out_corr = Y[i, o_idx] * df_row
                
                v_idx = findfirst(==(mapped_in_name), in_n)
                if !isnothing(v_idx)
                    # Yield relative to Independent Variable (already forward decayed)
                    A_in_corr = X[i, v_idx]
                    yield_val = (A_in_corr > 0.0) ? (A_out_corr / A_in_corr) * 100.0 : 0.0
                    Y[i, o_idx] = clamp(yield_val, 0.0, 100.0)
                else
                    # Yield relative to Fixed/Filler Ingredient
                    c_fixed = Main.Sys_Fast.FAST_GetCol_DDEF(df, C.PRE_FIXED * mapped_in_name)
                    c_fixed = isempty(c_fixed) ? Main.Sys_Fast.FAST_GetCol_DDEF(df, C.PRE_FILL * mapped_in_name) : c_fixed
                    
                    if !isempty(c_fixed)
                        val_raw = Main.Sys_Fast.FAST_SafeNum_DDEF(df[i, c_fixed])
                        # In-place dynamic forward decay for fixed components logic
                        A_in_corr = val_raw * exp(-log(2) * t_exp / hl_min)
                        yield_val = (A_in_corr > 0.0) ? (A_out_corr / A_in_corr) * 100.0 : 0.0
                        Y[i, o_idx] = clamp(yield_val, 0.0, 100.0)
                    else
                        # Fallback if no input volume/mass found
                        Y[i, o_idx] = A_out_corr
                    end
                end
                push!(dfs, df_row)
            end
            
            r_opts_out = get(rev_dict, out_name, Dict())
            disp_name = get(r_opts_out, "Name", "")
            disp_name = isempty(disp_name) ? out_name : disp_name

            push!(audit, Dict(
                "Name"        => disp_name,
                "HalfLife"    => hl_raw,
                "Unit"        => hl_unit,
                "Type"        => "Reverse & Yield ($mapped_in_name)",
                "AvgDeltaT"   => isempty(col_meas) ? 0.0 : mean(Main.Sys_Fast.FAST_SafeNum_DDEF.(df[!, col_meas])),
                "AvgDF"       => isempty(dfs) ? 1.0 : mean(dfs),
                "IsCorrected" => true
            ))
        end
    end
    return audit
end

# ------------------------------------------------------------------------------
# SECTION 16: DECAY-COUPLED OPTIMISATION BRIDGE
# ------------------------------------------------------------------------------

"""
    VISE_ExtractDecayModifiers_DDEF(InNames, OutNames, Config, Opts) -> Vector{CORE_DecayModifier_DDES}
Extracts decay modifier parameters from the project configuration by cross-referencing
radioactive ingredients with time-unit variables. This enables the optimisation engine
to apply the exponential decay penalty e^(-lambda * t) during candidate evaluation,
solving the radiopharmaceutical time-yield paradox.

Automatic Detection Logic:
1. Scan InNames for variables whose Unit is a temporal dimension (min, hours, sec, etc.).
2. For each radioactive ingredient with HalfLife > 0, check if RadioOpts.ReverseMap
   links any output to that ingredient.
3. Build a CORE_DecayModifier_DDES with the time variable index, decay constant,
   and affected output indices.
"""
function VISE_ExtractDecayModifiers_DDEF(in_n::AbstractVector{<:AbstractString}, out_n::AbstractVector{<:AbstractString},
    config::AbstractDict, opts::AbstractDict)::Vector{Main.Lib_Core.CORE_DecayModifier_DDES}

    modifiers = Main.Lib_Core.CORE_DecayModifier_DDES[]
    !get(get(opts, "RadioOpts", Dict()), "Apply", false) && return modifiers

    ingreds   = get(config, "Ingredients", [])
    r_opts    = get(opts, "RadioOpts", Dict{String,Any}())
    rev_dict  = get(r_opts, "ReverseMap", Dict{String,Any}())

    # Step 1: Identify time variable indices among the 3 input factors.
    time_indices = Int[]
    for (idx, name) in enumerate(in_n)
        ing_match = findfirst(i -> get(i, "Name", "") == name, ingreds)
        if !isnothing(ing_match)
            unit_str = string(get(ingreds[ing_match], "Unit", ""))
            if Main.Lib_Mole.MOLE_IsTimeUnit_DDEF(unit_str)
                push!(time_indices, idx)
            end
        end
    end

    isempty(time_indices) && return modifiers

    # Step 2: For each radioactive ingredient, build modifiers.
    for ing in ingreds
        hl_raw  = Main.Sys_Fast.FAST_SafeNum_DDEF(get(ing, "HalfLife", 0.0))
        hl_raw <= 0.0 && continue
        is_rad  = get(ing, "IsRadioactive", false) == true
        !is_rad && hl_raw <= 0.0 && continue

        hl_unit = string(get(ing, "HalfLifeUnit", "Hours"))
        hl_min  = Main.Lib_Mole.MOLE_ConvertTimeToMinutes_DDEF(hl_raw, hl_unit)
        hl_min <= 0.0 && continue

        lambda  = log(2) / hl_min
        i_name  = string(get(ing, "Name", "Unknown"))

        # Step 3: Determine which outputs are affected via ReverseMap.
        affected = Int[]
        for (out_name, out_data) in rev_dict
            mapped_src = get(out_data, "Source", "None")
            if mapped_src == i_name
                o_idx = findfirst(==(out_name), out_n)
                !isnothing(o_idx) && push!(affected, o_idx)
            end
        end

        # Safety Guard: Only apply decay to explicitly mapped outputs.
        # Outputs like Purity (%), pH, or particle size are decay-independent
        # and must NOT receive the exponential penalty.
        if isempty(affected)
            Main.Sys_Fast.FAST_Log_DDEF("VISE", "DECAY_BRIDGE",
                "Isotope '$i_name' has no ReverseMap output mapping. Decay penalty skipped for this isotope. " *
                "To enable decay-coupled optimisation, map at least one output to '$i_name' in the Radioactivity Correction panel.", "WARN")
            continue
        end

        # Create one modifier per time variable (typically only one exists).
        for t_idx in time_indices
            push!(modifiers, Main.Lib_Core.CORE_DecayModifier_DDES(
                t_idx, lambda, affected, i_name
            ))
        end
    end

    if !isempty(modifiers)
        Main.Sys_Fast.FAST_Log_DDEF("VISE", "DECAY_BRIDGE",
            "Decay-Coupled Optimisation ACTIVE: $(length(modifiers)) modifier(s) extracted [$(join([m.IsotopeName for m in modifiers], ", "))]", "OK")
    end

    return modifiers
end

function VISE_RunOptimisation_DDEF(X, models, goals, config, phase, in_n, out_n, opts, C, Log)
    !get(opts, "Optim", true) && return [], 0.0, DataFrame(), zeros(1), String[]
    
    bounds = hcat(minimum(X; dims=1)', maximum(X; dims=1)')
    decay_mods = VISE_ExtractDecayModifiers_DDEF(in_n, out_n, config, opts)
    
    # 1. High-Density Harmonic Grid Exploration
    grid_steps = get(opts, "GridSteps", 41)
    XT, YP, SC = VISE_GridSearch_DDEF(models, goals, bounds; Steps=grid_steps, DecayModifiers=decay_mods)
    
    # 2. Continuous Global Desirability Maximum (BlackBoxOptim)
    max_time = get(opts, "MaxTime", 2.0)
    bp, bs = Main.Lib_Core.CORE_OptimiseDesirability_DDEF(models, goals, bounds; MaxTime=max_time, DecayModifiers=decay_mods)
    
    # Predict outputs for continuous BBO point
    num_models = length(models)
    bp_mat = reshape(Float64.(bp), 1, 3)
    yp_bbo = zeros(Float64, 1, num_models)
    for m in 1:num_models
        if models[m]["Status"] == "OK"
            yp_bbo[1, m] = VISE_Predict_DDEF(models[m], bp_mat)[1]
        end
    end

    for dm in decay_mods
        for oi in dm.AffectedOutputs
            if oi >= 1 && oi <= num_models
                yp_bbo[1, oi] = Main.Lib_Core.CORE_ApplyDecayPenalty_DDEF(yp_bbo[1, oi], dm, bp)
            end
        end
    end

    # 3. Fuse BBO Optimum and Grid Candidates into 14-Leader Vault
    num_candidates = length(SC)
    top_grid_indices = partialsortperm(SC, 1:min(8, num_candidates); rev=true)

    candidate_pool = Tuple{Vector{Float64}, Vector{Float64}, Float64, Bool}[]
    push!(candidate_pool, (Float64.(bp), vec(yp_bbo), Float64(bs), true))

    for idx in top_grid_indices
        pt_x = XT[idx, :]
        dist_to_bbo = sum(abs.(pt_x .- bp) ./ max.(1e-5, bounds[:, 2] .- bounds[:, 1]))
        if dist_to_bbo > 0.01
            push!(candidate_pool, (pt_x, YP[idx, :], SC[idx], false))
        end
    end

    sort!(candidate_pool; by=x -> x[3], rev=true)
    selected_top = candidate_pool[1:min(8, length(candidate_pool))]
    
    cand_x_list = [c[1] for c in selected_top]
    cand_y_list = [c[2] for c in selected_top]
    cand_sc_list = [c[3] for c in selected_top]
    cand_tags = String[@sprintf("TOP-%02d", k) for k in 1:length(selected_top)]
    
    bench_score = cand_sc_list[1]
    score_limit = bench_score * 0.90
    tier_indices = findall(>=(score_limit), SC)
    (isempty(tier_indices)) && (tier_indices = top_grid_indices)

    # 4. Input Minimisation Diversity (3 Leaders: INP-X1, INP-X2, INP-X3)
    for i in 1:min(3, size(XT, 2))
        tag_pre = i <= length(in_n) ? first(in_n[i] * "   ", 3) : "IN$i"
        best_idx, min_val = -1, Inf
        for idx in tier_indices
            val = XT[idx, i]
            if val < min_val
                min_val, best_idx = val, idx
            end
        end
        if best_idx != -1
            push!(cand_x_list, XT[best_idx, :])
            push!(cand_y_list, YP[best_idx, :])
            push!(cand_sc_list, SC[best_idx])
            push!(cand_tags, "INP-$(tag_pre)")
        end
    end

    # 5. Output Maximisation Diversity (3 Leaders: OUT-Y1, OUT-Y2, OUT-Y3)
    for i in 1:min(3, size(YP, 2))
        tag_pre = i <= length(out_n) ? first(out_n[i] * "   ", 3) : "OUT$i"
        m_goal = get(models[i], "Goal", Dict())
        gtup = Main.Lib_Core.CORE_ExtractGoal_DDEF(m_goal)
        best_idx, max_d = -1, -Inf
        for idx in tier_indices
            val = YP[idx, i]
            d_val = Main.Lib_Core.CORE_CalcDesirability_DDEF(val, gtup)
            if d_val > max_d
                max_d, best_idx = d_val, idx
            end
        end
        if best_idx != -1
            push!(cand_x_list, XT[best_idx, :])
            push!(cand_y_list, YP[best_idx, :])
            push!(cand_sc_list, SC[best_idx])
            push!(cand_tags, "OUT-$(tag_pre)")
        end
    end

    final_XT = reduce(vcat, [reshape(v, 1, :) for v in cand_x_list])
    final_YP = reduce(vcat, [reshape(v, 1, :) for v in cand_y_list])
    final_SC = cand_sc_list

    ldf = VISE_PrepareLeadersDF_DDEF(final_XT, final_YP, final_SC, cand_tags, in_n, out_n, phase, C)

    # 6. Stoichiometric Safety Audit
    ingreds = get(config, "Ingredients", [])
    if !isempty(ingreds)
        g_cfg = get(config, "Global", Dict())
        sv    = Float64(get(g_cfg, "Volume", 5.0))
        sc    = Float64(get(g_cfg, "Conc", 10.0))
        
        audit = Main.Lib_Mole.MOLE_AuditBatch_DDEF(ingreds, final_XT, sv, sc)
        if !audit["IsFeasible"]
            Main.Sys_Fast.FAST_Log_DDEF("VISE", "STOICHIOMETRY", "Experimental design contains physically questionable runs.", "WARN")
        else
            Main.Sys_Fast.FAST_Log_DDEF("VISE", "STOICHIOMETRY", "Physical feasibility audit passed for $(nrow(ldf)) candidate leaders.", "OK")
        end
    end

    # 7. Boundary Warnings
    warns = String[]
    if !isempty(bp)
        for i in 1:min(3, length(bp))
            v_range = [bounds[i, 1], (bounds[i, 1] + bounds[i, 2]) / 2, bounds[i, 2]]
            ok, msg = Main.Sys_Flow.FLOW_AskLeader_DDEF(bp[i], v_range)
            !ok && push!(warns, "$(in_n[i]): $msg")
        end
    end

    return bp, bs, ldf, SC, warns
end

function VISE_PrepareLeadersDF_DDEF(xt, yp, sc, tags, in_n, out_n, phase, C)
    df = DataFrame()
    df[!, Symbol(C.COL_ID)] = tags
    df[!, Symbol(C.COL_PHASE)] = fill(phase, length(tags))
    df[!, Symbol(C.COL_STATUS)] = fill("Candidate", length(tags))
    df[!, Symbol(C.COL_SCORE)] = round.(sc; digits=4)
    
    for (i, n) in enumerate(in_n)
        col_sym = Symbol(C.PRE_INPUT * n)
        df[!, col_sym] = round.(xt[:, i]; digits=3)
    end
    
    for (i, n) in enumerate(out_n)
        col_pred = Symbol(C.PRE_PRED * n)
        df[!, col_pred] = round.(yp[:, i]; digits=3)
        
        # Result columns should be missing for candidates
        col_res = Symbol(C.PRE_RESULT * n)
        df[!, col_res] = Vector{Union{Missing, Float64}}(missing, length(tags))
    end
    
    return df
end

function VISE_GeneratePredictions_DDEF(X, Y, models, goals)
    yp = hcat([VISE_Predict_DDEF(m, X) for m in models]...)
    pg = [Main.Lib_Core.CORE_ExtractGoal_DDEF(get(m, "Goal", Dict())) for m in models]
    
    sum_w = sum(g[5] for g in pg)
    pow   = sum_w > 0.0 ? (1.0 / sum_w) : (length(models) > 0 ? 1.0 / length(models) : 1.0)
    
    n_points = size(X, 1)
    sc = zeros(n_points)
    
    for i in 1:n_points
        s = 1.0
        for j in eachindex(models)
            d = Main.Lib_Core.CORE_CalcDesirability_DDEF(yp[i, j], pg[j])
            s *= d
        end
        score = s^pow
        sc[i] = clamp(score, 0.0, 1.0)
    end
    
    return yp, sc
end

function VISE_PreparePredictionsSheet_DDEF(df::DataFrame, phase::AbstractString, yp::AbstractMatrix, sc::AbstractVector, mask, out_n, C, Log)
    # This prevents DataFrames.jl ArgumentError when assigning to non-existent columns.
    for n in out_n
        col_sym = Symbol(C.PRE_PRED * n)
        if !(col_sym in propertynames(df))
            df[!, col_sym] = Vector{Union{Float64, Missing}}(missing, nrow(df))
        end
    end
    if !(Symbol(C.COL_SCORE) in propertynames(df))
        df[!, Symbol(C.COL_SCORE)] = Vector{Union{Float64, Missing}}(missing, nrow(df))
    end

    idx_m = findall(mask)
    for (i, r_idx) in enumerate(idx_m)
        for (m, n) in enumerate(out_n) 
            df[r_idx, Symbol(C.PRE_PRED * n)] = round(yp[i, m]; digits=3) 
        end
        df[r_idx, Symbol(C.COL_SCORE)] = round(sc[i]; digits=4)
    end
    return df
end


function VISE_AssembleBundle_DDEF(phase, in_n, out_n, disp_in, disp_out, models, bp, bs, ldf, xc, yc, opts, goals, yp, sc, radio, warns, vitals, anova, normality, residuals, sens, graphs, t0, C)
    ui_mods = deepcopy(models); for m in ui_mods delete!(m, "_Closure") end
    return Dict("Status"=>"OK", "Phase"=>phase, "InNames"=>in_n, "OutNames"=>out_n, "DisplayInNames"=>disp_in, "DisplayOutNames"=>disp_out, "Models"=>ui_mods, "Goals"=>goals, "R2_Adj"=>[get(m, "R2_Adj", 0.0) for m in models], "Q2"=>[get(m, "Q2", 0.0) for m in models], "BestPoint"=>bp, "BestScore"=>bs, "Leaders"=>ldf, "X_Clean"=>xc, "Y_Clean"=>yc, "Graphs"=>graphs, "Vitals"=>vitals, "Sensitivities"=>sens, "ANOVA"=>anova, "Normality"=>normality, "Residuals"=>residuals, "RadioCorrection"=>radio, "BoundaryWarnings"=>warns, "Elapsed"=>"$(round(time()-t0; digits=1))s")
end

"""
    VISE_ExportToExcel_DDEF(Res::Dict, FilePath::AbstractString) -> Bool
Produces a high-fidelity academic Excel report with multiple analytical sheets.
"""
function VISE_ExportToExcel_DDEF(Res::AbstractDict, FilePath::AbstractString)
    Main.Sys_Fast.FAST_Log_DDEF("VISE", "EXPORT", "Generating High-Fidelity Scientific Portfolio: $FilePath", "WAIT")
    try
        XLSX.openxlsx(FilePath, mode="w") do xf
            sheet_ov       = xf[1]
            XLSX.rename!(sheet_ov, "Summary")
            sheet_ov["A1"] = "DoECISORY Scientific Intelligence Report"
            sheet_ov["A2"] = "Generated: $(Dates.now())"
            sheet_ov["A3"] = "Project: $(get(Res, "Phase", "Unnamed Phase"))"

            sheet_mod       = XLSX.addsheet!(xf, "Model_Statistics")
            sheet_mod["A1"] = ["Response", "Model Type", "R2", "R2_Adj", "RMSE", "P-Value", "Normality (p)"]

            X_Raw = Res["X_Clean"]
            Y_Raw = Res["Y_Clean"]
            
            X_Clean = VISE_PrepareMatrix_DDEF(X_Raw)
            Y_Clean = VISE_PrepareMatrix_DDEF(Y_Raw)
            
            row_idx = 2
            for (i, out_name) in enumerate(get(Res, "DisplayOutNames", get(Res, "OutNames", [])))
                m    = Res["Models"][i]
                norm = VISE_PerformNormalityTest_DDEF(m, X_Clean, Y_Clean[:, i])

                sheet_mod[row_idx, 1] = out_name
                sheet_mod[row_idx, 2] = get(m, "ModelType", "N/A")
                sheet_mod[row_idx, 3] = round(get(m, "R2", 0.0); digits=4)
                sheet_mod[row_idx, 4] = round(get(m, "R2_Adj", 0.0); digits=4)
                sheet_mod[row_idx, 5] = round(get(m, "RMSE", 0.0); digits=4)
                sheet_mod[row_idx, 6] = round(get(m, "P_Value", 1.0); digits=4)
                sheet_mod[row_idx, 7] = norm["p"]

                row_idx += 1
            end

            for (i, out_name) in enumerate(get(Res, "DisplayOutNames", get(Res, "OutNames", [])))
                m         = Res["Models"][i]
                safe_name = first(replace(out_name, r"[^\w]" => "_"), 25)

                # Execution of Analysis of Variance (ANOVA) documentation.
                sh_ano   = XLSX.addsheet!(xf, "ANOVA_$(safe_name)")
                df_anova = VISE_GenerateAnovaTable_DDEF(m, X_Clean, Y_Clean[:, i])
                XLSX.writetable!(sh_ano, df_anova; anchor_cell=XLSX.CellRef("A1"))

                # Tabulation of model coefficients and diagnostic metrics.
                sh_coef = XLSX.addsheet!(xf, "Coefs_$(safe_name)")
                terms   = get(m, "TermNames", [])
                coefs   = get(m, "Coefs", [])
                p_vals  = get(m, "P_Coefs", [])
                vifs    = get(m, "VIFs", [])

                sh_coef["A1"] = ["Term", "Coefficient", "P-Value", "VIF", "Significance"]
                for j in eachindex(terms)
                    sh_coef[j+1, 1] = terms[j]
                    sh_coef[j+1, 2] = round(coefs[j]; digits=4)
                    sh_coef[j+1, 3] = isnan(p_vals[j]) ? "N/A" : round(p_vals[j]; digits=4)
                    sh_coef[j+1, 4] = (j == 1) ? 1.0 : round(vifs[j]; digits=2)
                    sh_coef[j+1, 5] = (!isnan(p_vals[j]) && p_vals[j] < 0.05) ? "*" : ""
                end
            end

            # Integrated radiation and isothermal decay correction registry.
            if haskey(Res, "RadioCorrection")
                sh_rad       = XLSX.addsheet!(xf, "Radiation_Decay_Correction")
                sh_rad["A1"] = ["Component", "Half-Life", "Unit", "Avg Delta-T (Hours)", "Avg Decay Factor", "Correction Applied"]
                data         = Res["RadioCorrection"]
                for (r_idx, itm) in enumerate(data)
                    sh_rad[r_idx+1, 1] = itm["Name"]
                    sh_rad[r_idx+1, 2] = itm["HalfLife"]
                    sh_rad[r_idx+1, 3] = itm["Unit"]
                    sh_rad[r_idx+1, 4] = round(get(itm, "AvgDeltaT", 0.0); digits=4)
                    sh_rad[r_idx+1, 5] = round(get(itm, "AvgDF", 0.0); digits=6)
                    sh_rad[r_idx+1, 6] = get(itm, "IsCorrected", false) ? "YES (Dynamic)" : "NO"
                end
            end
        end
        Main.Sys_Fast.FAST_Log_DDEF("VISE", "EXPORT", "Scientific Portfolio Generated with Legacy Fidelity.", "OK")
        return true
    catch e
        Main.Sys_Fast.FAST_Log_DDEF("VISE", "EXPORT", "Excel export failed: $e", "FAIL")
        return false
    end
end
end # Module Lib_Vise
