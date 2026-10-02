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
using ..Sys_Fast
using ..Lib_Mole
using ..Lib_Core
using ..Sys_Flow

const Main = parentmodule(@__MODULE__)
using HypothesisTests
import HypothesisTests: pvalue

export VISE_Regress_DDEF, VISE_GridSearch_DDEF, VISE_ExpandDesign_DDEF,
       VISE_Predict_DDEF, VISE_Execute_DDEF, VISE_CrossValidate_DDEF,
       VISE_GetTermNames_DDEF, VISE_ClampIndex_DDEF, VISE_SelectBestModel_DDEF,
       VISE_CalcMetrics_DDEF, VISE_SensitivityAnalysis_DDEF, VISE_GenerateScientificReport_DDEF,
       VISE_FormatMarkdownTable_DDEF, VISE_GetWeightRating_DDEF, VISE_CalcVIF_DDEF,
       VISE_LackOfFit_DDEF, VISE_GenerateAnovaTable_DDEF, VISE_PerformNormalityTest_DDEF,
       VISE_ExportToExcel_DDEF, VISE_ExtractDCYP_DDEF, VISE_ApplyForwReveDecay_DDEF,
       VISE_ResolveName_DDEF, VISE_WidenColumnFloat_DDEF!, VISE_InsertColAfter_DDEF!

# ==============================================================================
# PART A: MODELLING & DESIGN EXPANSION
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 1: REGRESSION DATA STRUCTURES & TERM GENERATOR
# ------------------------------------------------------------------------------

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


"""
    VISE_GetTermNames_DDEF(InNames, ModelType) -> Vector{String}
Generates human-readable names for regression terms (Factor Interactions and Polynomials).
"""
function VISE_GetTermNames_DDEF(InNames::AbstractVector{<:AbstractString}, ModelType::Any)
    m_type = Main.Lib_Core.CORE_GetModelType_DDEF(ModelType)
    actual_names = length(InNames) >= 3 ? InNames : ["X1", "X2", "X3"]
    return VISE_GetTerms_DDEF(m_type, actual_names)
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
    X_mat = (X isa AbstractVector) ? reshape(X, 1, length(X)) : X
    m_type = get(Model, "ModelType", "linear")
    Xd = VISE_ExpandDesign_DDEF(X_mat, m_type)
    p = size(Xd, 2)
    raw_beta = get(Model, "Coefs", Float64[])
    Beta = if isempty(raw_beta)
        zeros(Float64, p)
    elseif length(raw_beta) == p
        collect(Float64, raw_beta)
    elseif length(raw_beta) > p
        collect(Float64, raw_beta[1:p])
    else
        vcat(collect(Float64, raw_beta), zeros(Float64, p - length(raw_beta)))
    end
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

    # Isolate independent variables and initialise variance inflation vector.
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
        MS     = Vector{Union{Float64, Missing}}(missing, length(sources)),
        F      = Vector{Union{Float64, Missing}}(missing, length(sources)),
        P      = Vector{Union{Float64, Missing}}(missing, length(sources))
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
        if !ismissing(df_anova.MS[idx_res]) && !ismissing(df_anova.MS[idx_mod]) && df_anova.MS[idx_res] > 1e-12
            f                   = df_anova.MS[idx_mod] / df_anova.MS[idx_res]
            df_anova.F[idx_mod] = round(f; digits=2)
            df_anova.P[idx_mod] = round(1.0 - cdf(FDist(df_anova.df[idx_mod], df_anova.df[idx_res]), f); digits=4)
        end
    end

    # Execution of Lack-of-Fit significance verification.
    idx_lof = findfirst(==("Lack of Fit"), sources)
    idx_pe = findfirst(==("Pure Error"), sources)
    if !isnothing(idx_lof) && !isnothing(idx_pe)
        if !ismissing(df_anova.MS[idx_pe]) && !ismissing(df_anova.MS[idx_lof]) && df_anova.MS[idx_pe] > 1e-12
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
    VISE_GridSearch_DDEF(Models, Goals, Bounds; [Steps], [ModifiersDCYP]) -> (X, Y_Pred, Scores)
Performs high-density grid search across factor space for desirability exploration.
When ModifiersDCYP are provided, composite desirability is penalised by the exponential
decay factor e^(-lambda * t_reaction) for the reaction incubation time.
"""
function VISE_GridSearch_DDEF(Models::AbstractVector, Goals::AbstractVector, X_Bounds::AbstractMatrix{Float64};
    Steps::Int=41, ModifiersDCYP::Vector{Main.Lib_Core.CORE_ModifierDCYP_DDES}=Main.Lib_Core.CORE_ModifierDCYP_DDES[])
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
    NumModels = length(Models)
    Predictions = zeros(Float64, NumPoints, NumModels)
    Active_Flags = falses(NumModels)

    Main.Sys_Fast.FAST_Log_DDEF("VISE", "GRID_SEARCH", "Exploration Pulse [N=$NumPoints] - Dispatching $(NumModels) models...", "WAIT")

    # Pre-expand design matrices for Linear and Quadratic structures
    X_Linear = VISE_ExpandDesign_DDEF(Candidates, "linear")
    X_Quadratic = VISE_ExpandDesign_DDEF(Candidates, "quadratic")

    # 1. Deterministic Matrix-Vector Multiplication (Thread-safe)
    for m in 1:NumModels
        Mod = Models[m]
        Mod["Status"] != "OK" && continue
        m_type_str = lowercase(get(Mod, "ModelType", "quadratic"))
        Beta = collect(Float64, Mod["Coefs"])
        
        X_eff = (m_type_str == "linear") ? X_Linear : X_Quadratic
        p_cols = size(X_eff, 2)
        @inbounds for i in 1:NumPoints
            acc = 0.0
            for j in 1:p_cols
                acc += X_eff[i, j] * Beta[j]
            end
            Predictions[i, m] = acc
        end
        
        Active_Flags[m] = true
    end

    # 2. Multi-Objective Desirability Scoring
    active_idx = findall(Active_Flags)
    Scores = Vector{Float64}(undef, NumPoints)
    if isempty(active_idx)
        fill!(Scores, 1.0)
    else
        parsed_goals = Vector{Tuple}(undef, NumModels)
        for m in 1:NumModels
            gtup = Main.Lib_Core.CORE_ExtractGoal_DDEF(m <= length(Goals) ? Goals[m] : get(Models[m], "Goal", Dict()))
            parsed_goals[m] = gtup
        end
        base_goals = [(g[1], g[2], g[3], g[4], 1.0) for g in parsed_goals]
        inv_k = length(active_idx) > 0 ? (1.0 / length(active_idx)) : 1.0
        neighbour_weights = [Main.Lib_Core.CORE_GetNeighbourWeights_DDEF(parsed_goals[m][5]) for m in active_idx]

        @inbounds for i in 1:NumPoints
            prod_u = 1.0
            prod_e = 1.0
            for (j, m_idx) in enumerate(active_idx)
                pred_val = Predictions[i, m_idx]
                if isnan(pred_val) || isinf(pred_val)
                    prod_u = 0.0
                    prod_e = 0.0
                    break
                end

                b = Main.Lib_Core.CORE_CalcDesirability_DDEF(pred_val, base_goals[m_idx])
                if b <= 1e-12
                    prod_u = 0.0
                    prod_e = 0.0
                    break
                end

                w_m, w_c, w_p = neighbour_weights[j]
                u = b^(w_c * inv_k)
                e = (b^(w_m * inv_k) + u + b^(w_p * inv_k)) / 3.0
                prod_u *= u
                prod_e *= e
            end
            res_val = clamp(0.50 * prod_u + 0.50 * prod_e, 0.0, 1.0)
            for dm in ModifiersDCYP
                res_val = Main.Lib_Core.CORE_ApplyDCYP_DDEF(res_val, dm, view(Candidates, i, :))
            end
            Scores[i] = (isnan(res_val) || isinf(res_val)) ? 0.0 : clamp(res_val, 0.0, 1.0)
        end
    end

    Main.Sys_Fast.FAST_Log_DDEF("VISE", "GRID_SEARCH", "Exploration Pulse completed successfully.", "OK")
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

"""
    VISE_FormatMarkdownTable_DDEF(headers::Vector{String}, aligns::Vector{Symbol}, rows::Vector{Vector{String}}) -> String
Constructs a Markdown table with strictly uniform, character-perfect column alignment.
Supported alignments: :left, :right, :centre.
"""
function VISE_FormatMarkdownTable_DDEF(headers::Vector{String}, aligns::Vector{Symbol}, rows::Vector{Vector{String}})::String
    clean_cell(s::AbstractString) = replace(replace(s, r"</?[a-zA-Z][a-zA-Z0-9]*\b[^>]*>" => ""), "&lt;" => "<", "&gt;" => ">")
    
    n_cols = length(headers)
    clean_headers = [clean_cell(h) for h in headers]
    clean_rows = [[clean_cell(j <= length(r) ? r[j] : "") for j in 1:n_cols] for r in rows]

    widths = [max(textwidth(clean_headers[j]), 3) for j in 1:n_cols]
    for r in clean_rows
        for j in 1:n_cols
            widths[j] = max(widths[j], textwidth(r[j]))
        end
    end

    function pad_vis(s::AbstractString, w::Int, align::Symbol)::String
        tw = textwidth(s)
        tw >= w && return s
        pad = w - tw
        if align == :right
            return repeat(' ', pad) * s
        elseif align == :centre
            left_pad = pad ÷ 2
            right_pad = pad - left_pad
            return repeat(' ', left_pad) * s * repeat(' ', right_pad)
        else # :left
            return s * repeat(' ', pad)
        end
    end

    io = IOBuffer()
    
    # 1. Header row
    write(io, "|")
    for j in 1:n_cols
        h_str = pad_vis(clean_headers[j], widths[j], aligns[j])
        write(io, " ", h_str, " |")
    end
    write(io, "\n")
    
    # 2. Divider row (:--- for left, ---: for right, :---: for centre)
    write(io, "|")
    for j in 1:n_cols
        w = widths[j]
        div_str = if aligns[j] == :right
            repeat('-', w + 1) * ":"
        elseif aligns[j] == :centre
            ":" * repeat('-', w) * ":"
        else
            ":" * repeat('-', w + 1)
        end
        write(io, div_str, "|")
    end
    write(io, "\n")
    
    # 3. Data rows
    for r in clean_rows
        write(io, "|")
        for j in 1:n_cols
            c_str = pad_vis(r[j], widths[j], aligns[j])
            write(io, " ", c_str, " |")
        end
        write(io, "\n")
    end
    
    return String(take!(io))
end

function VISE_GetWeightRating_DDEF(w::Any)::String
    w_val = round((w isa Real) ? Float64(w) : something(tryparse(Float64, string(w)), 1.0); digits=2)
    w_val == 0.50 && return "1/5"
    w_val == 0.75 && return "2/5"
    w_val == 1.00 && return "3/5"
    w_val == 1.50 && return "4/5"
    w_val == 2.00 && return "5/5"
    return "3/5"
end

function VISE_GenerateScientificReport_DDEF(Res::AbstractDict)
    io = IOBuffer()
    
    phase     = get(Res, "Phase", "Phase1")
    in_names_all  = get(Res, "DisplayInNames", get(Res, "InNames", []))
    out_names_all = get(Res, "DisplayOutNames", get(Res, "OutNames", []))
    n_samples = haskey(Res, "X_Clean") ? (Res["X_Clean"] isa AbstractMatrix ? size(Res["X_Clean"], 1) : length(Res["X_Clean"])) : 0
    n_factors = !isempty(in_names_all) ? length(in_names_all) : (haskey(Res, "X_Clean") ? (Res["X_Clean"] isa AbstractMatrix ? size(Res["X_Clean"], 2) : (length(Res["X_Clean"]) > 0 && Res["X_Clean"][1] isa AbstractVector ? length(Res["X_Clean"][1]) : 0)) : 0)
    n_outputs = !isempty(out_names_all) ? length(out_names_all) : (haskey(Res, "Y_Clean") ? (Res["Y_Clean"] isa AbstractMatrix ? size(Res["Y_Clean"], 2) : (length(Res["Y_Clean"]) > 0 && Res["Y_Clean"][1] isa AbstractVector ? length(Res["Y_Clean"][1]) : 0)) : 0)

    fmt_pos(s::AbstractString) = String(s)
    fmt_neg(s::AbstractString) = String(s)

    write(io, "# STATISTICAL ANALYSIS REPORT\n")
    write(io, Printf.@sprintf("*Execution Date: %s | Experimental Phase: %s*\n", Dates.format(now(), "yyyy-mm-dd HH:MM"), phase))
    write(io, Printf.@sprintf("*Sample Size (N): %d runs | Factors (k): %d | Responses (m): %d*\n\n", n_samples, n_factors, n_outputs))
    write(io, "---\n\n")

    models = get(Res, "Models", Dict{String,Any}[])
    is_quadratic = any(m -> lowercase(string(get(m, "ModelType", get(m, :ModelType, "")))) == "quadratic", models) || (n_samples > 12 && n_factors >= 2)

    # --- Report Stage I: Experimental Design Vitals ---
    if haskey(Res, "Vitals") && !isnothing(Res["Vitals"])
        v = Res["Vitals"]
        write(io, "### I. Experimental Design Vitals\n")
        write(io, "Assessment of information matrix conditioning, optimality criteria, and lack-of-fit.\n\n")
        
        d_val   = get(v, "D", 0.0)
        a_val   = get(v, "A", 0.0)
        g_val   = get(v, "G", 0.0)
        i_val   = get(v, "I", 0.0)
        c_val   = get(v, "Condition", Inf)
        vif_val = get(v, "MaxVIF", 1.0)
        lof_val = get(v, "LOF", 1.0)

        d_num = (!ismissing(d_val) && !isnan(d_val)) ? Float64(d_val) : 0.0
        c_num = (!ismissing(c_val) && !isnan(c_val)) ? Float64(c_val) : Inf
        v_num = (!ismissing(vif_val) && !isnan(vif_val)) ? Float64(vif_val) : 1.0

        d_benchmark = is_quadratic ? "≥ 35.00% (RSM)" : "≥ 60.00%"
        d_threshold = is_quadratic ? 0.35 : 0.60
        d_eval = if is_quadratic
            if d_num >= 0.45
                fmt_pos("High efficiency")
            elseif d_num >= 0.35
                fmt_pos("Satisfactory efficiency")
            else
                fmt_neg("Marginal efficiency")
            end
        else
            if d_num >= 0.60
                fmt_pos("Adequate efficiency (D ≥ 60%)")
            else
                fmt_neg("Low efficiency (D < 60%)")
            end
        end

        c_eval = c_num < 100.0 ? fmt_pos("Well-conditioned (κ < 100)") : (c_num < 1000.0 ? "Moderate collinearity" : fmt_neg("Severe ill-conditioning (κ ≥ 1,000)"))
        c_str  = isinf(c_num) ? "Inf" : (c_num >= 1e4 ? @sprintf("%.2e", c_num) : @sprintf("%.2f", c_num))

        v_eval = v_num == 1.0 ? fmt_pos("Orthogonal factors (VIF = 1.0)") : (v_num <= 5.0 ? fmt_pos("Low collinearity (VIF ≤ 5.0)") : fmt_neg("High collinearity (VIF > 5.0)"))

        lof_str, lof_tag = if ismissing(lof_val) || isnan(lof_val)
            "N/A", "Replicate runs absent"
        else
            ln = Float64(lof_val)
            @sprintf("%.4f", ln), (ln >= 0.05 ? fmt_pos("Adequate fit (p ≥ 0.05)") : fmt_neg("Significant lack of fit (p < 0.05)"))
        end

        vitals_headers = ["Metric / Criterion", "Value", "Benchmark Reference", "Statistical Evaluation"]
        vitals_aligns  = [:left, :right, :left, :left]
        vitals_rows    = Vector{String}[]

        push!(vitals_rows, ["D-Efficiency", @sprintf("%.2f%%", d_num * 100), d_benchmark, d_eval])
        if (!ismissing(a_val) && !isnan(a_val) && Float64(a_val) > 0.0)
            push!(vitals_rows, ["A-Optimality", @sprintf("%.4f", Float64(a_val)), "tr((X'X)⁻¹) minim.", "Average parameter variance"])
        end
        if (!ismissing(g_val) && !isnan(g_val) && Float64(g_val) > 0.0)
            push!(vitals_rows, ["G-Optimality", @sprintf("%.4f", Float64(g_val)), "max SPV minim.", "Maximum prediction variance"])
        end
        if (!ismissing(i_val) && !isnan(i_val) && Float64(i_val) > 0.0)
            push!(vitals_rows, ["I-Optimality", @sprintf("%.4f", Float64(i_val)), "∫ SPV dX minim.", "Mean prediction variance"])
        end
        push!(vitals_rows, ["Condition Number (κ)", c_str, "< 100.00", c_eval])
        push!(vitals_rows, ["Maximum Collinearity (VIF)", @sprintf("%.2f", v_num), "≤ 5.00", v_eval])
        push!(vitals_rows, ["Lack-of-Fit (P-Value)", lof_str, "p ≥ 0.0500", lof_tag])

        write(io, VISE_FormatMarkdownTable_DDEF(vitals_headers, vitals_aligns, vitals_rows))
        write(io, "\n")

        if is_quadratic
            write(io, Printf.@sprintf("*Design Efficiency Note: For second-order response surface methodology (RSM) models with quadratic curvature and interaction terms, theoretical D-efficiency standardly ranges between 30%% and 50%% (Box-Behnken / Central Composite benchmarks). A D-efficiency of %.2f%% confirms a well-balanced experimental design for quadratic surface estimation.*\n\n", d_num * 100))
        end

        if c_num < 100.0 && v_num <= 5.0
            write(io, "*Matrix Condition: The design matrix is well-conditioned (κ < 100) with low variance inflation (VIF ≤ 5.0), ensuring stable parameter estimation without collinearity inflation.*\n\n")
        elseif c_num >= 1000.0 || v_num > 10.0
            write(io, "*Matrix Condition: Severe multicollinearity or ill-conditioning detected in the design matrix (κ ≥ 1,000 or VIF > 10.0). Standard errors of regression coefficients may be substantially inflated.*\n\n")
        else
            write(io, "*Matrix Condition: Moderate collinearity present among design factors. Regression estimates remain computationally stable, though standard errors are slightly increased.*\n\n")
        end
        
        if !ismissing(lof_val) && !isnan(lof_val)
            if Float64(lof_val) < 0.05
                write(io, "*Lack-of-Fit Interpretation: The test is statistically significant (p < 0.05). The variation unaccounted for by the model exceeds experimental pure error, indicating that the fitted model order is insufficient to capture response surface curvature or interactions. Higher-order polynomial terms or transformations are recommended.*\n\n")
            else
                write(io, "*Lack-of-Fit Interpretation: The test is non-significant (p ≥ 0.05). There is no statistical evidence of model inadequacy against pure experimental error, confirming that the response surface is adequately modelled.*\n\n")
            end
        else
            write(io, "*Lack-of-Fit Interpretation: Replicate runs at identical factor coordinates were not conducted in this design. Consequently, pure experimental error cannot be separated from residual lack-of-fit error.*\n\n")
        end
    end

    # --- Report Stage II: Model Summary & Cross-Validation ---
    out_names = get(Res, "DisplayOutNames", Res["OutNames"])
    norms     = get(Res, "Normality", Dict[])
    sens      = get(Res, "Sensitivities", [])
    in_names  = get(Res, "DisplayInNames", get(Res, "InNames", []))

    write(io, "### II. Model Summary & Cross-Validation\n")
    write(io, "Summary of regression goodness-of-fit, leave-one-out cross-validation (LOOCV), and residual normality.\n\n")

    summary_headers = ["Response Variable", "Model Order", "Adj. R²", "Q² (LOOCV)", "RMSE", "Model P-Val", "Normality (p)", "Predictive Validity"]
    summary_aligns  = [:left, :left, :right, :right, :right, :right, :right, :left]
    summary_rows    = Vector{String}[]

    for (m_idx, name) in enumerate(out_names)
        m_idx > length(models) && continue
        mod = models[m_idx]
        mod["Status"] != "OK" && continue

        raw_mtype = get(mod, "ModelType", "linear")
        m_type = uppercase(first(raw_mtype, 1)) * lowercase(raw_mtype[2:end])
        r2a  = get(mod, "R2_Adj", NaN)
        q2   = get(mod, "Q2", NaN)
        rmse = get(mod, "RMSE", NaN)
        pval = get(mod, "P_Value", NaN)
        
        norm_p = (m_idx <= length(norms) && haskey(norms[m_idx], "p") && !isnan(norms[m_idx]["p"])) ? norms[m_idx]["p"] : NaN
        
        quality = if ismissing(q2) || isnan(q2)
            "N/A"
        elseif q2 >= 0.70
            fmt_pos("High (Q² ≥ 0.70)")
        elseif q2 >= 0.50
            fmt_pos("Moderate (Q² ≥ 0.50)")
        elseif q2 >= 0.0
            fmt_neg("Low (0 ≤ Q² < 0.50)")
        else
            fmt_neg("Overfitted (Q² < 0)")
        end

        r2a_s  = (!ismissing(r2a) && !isnan(r2a)) ? @sprintf("%.4f", Float64(r2a)) : "N/A"
        q2_s   = (!ismissing(q2) && !isnan(q2))   ? @sprintf("%.4f", Float64(q2))  : "N/A"
        rmse_s = (!ismissing(rmse) && !isnan(rmse)) ? @sprintf("%.4f", Float64(rmse)) : "N/A"
        pval_s = (!ismissing(pval) && !isnan(pval)) ? (pval < 0.0001 ? "<0.0001" : @sprintf("%.4f", Float64(pval))) : "N/A"
        norm_s = (!ismissing(norm_p) && !isnan(norm_p)) ? (norm_p < 0.0001 ? "<0.0001" : @sprintf("%.4f", Float64(norm_p))) : "N/A"

        push!(summary_rows, [first(name, 24), m_type, r2a_s, q2_s, rmse_s, pval_s, norm_s, quality])
    end

    write(io, VISE_FormatMarkdownTable_DDEF(summary_headers, summary_aligns, summary_rows))
    write(io, "\n")
    
    for (m_idx, name) in enumerate(out_names)
        m_idx > length(models) && continue
        mod = models[m_idx]
        mod["Status"] != "OK" && continue
        
        pval = get(mod, "P_Value", NaN)
        r2a  = get(mod, "R2_Adj", NaN)
        q2   = get(mod, "Q2", NaN)
        norm_p = (m_idx <= length(norms) && haskey(norms[m_idx], "p") && !isnan(norms[m_idx]["p"])) ? norms[m_idx]["p"] : NaN
        
        sig_str = if !ismissing(pval) && !isnan(pval)
            pval < 0.05 ? "The regression model is statistically significant (p < 0.05)." : "The regression model is not statistically significant at α = 0.05 (p ≥ 0.05)."
        else
            ""
        end
        
        gen_str = if !ismissing(r2a) && !isnan(r2a) && !ismissing(q2) && !isnan(q2)
            gap = r2a - q2
            if q2 < 0.0
                "Negative Q² indicates that the model has poor predictive generalisation."
            elseif gap > 0.20
                @sprintf("The gap between Adj. R² (%.3f) and Q² (%.3f) exceeds 0.20, indicating potential overfitting to training runs.", r2a, q2)
            elseif q2 >= 0.50
                @sprintf("Close agreement between Adj. R² (%.3f) and Q² (%.3f) confirms acceptable predictive generalisation.", r2a, q2)
            else
                @sprintf("Adj. R² is %.3f and Q² is %.3f, reflecting modest predictive power.", r2a, q2)
            end
        else
            ""
        end
        
        norm_str = if !ismissing(norm_p) && !isnan(norm_p)
            norm_p >= 0.05 ? 
                @sprintf("Residuals satisfy the normality assumption (Shapiro-Wilk p = %.4f ≥ 0.05), supporting the validity of standard parametric tests.", norm_p) :
                @sprintf("Residuals depart from normality (Shapiro-Wilk p = %.4f < 0.05); inference should be interpreted with caution.", norm_p)
        else
            ""
        end
        
        write(io, Printf.@sprintf("*%s Analysis: %s %s %s*\n\n", name, sig_str, gen_str, norm_str))
    end

    # --- Report Stage III: Analysis of Variance (ANOVA) ---
    anova_tables = get(Res, "ANOVA", DataFrame[])
    if !isempty(anova_tables)
        write(io, "### III. Analysis of Variance (ANOVA)\n")
        write(io, "Partitioning of total response sum of squares into regression model and residual components.\n\n")

        anova_headers = ["Source of Variation", "df", "Sum of Squares", "Mean Square", "F-Statistic", "P-Value"]
        anova_aligns  = [:left, :right, :right, :right, :right, :right]

        for (m_idx, name) in enumerate(out_names)
            m_idx > length(anova_tables) && continue
            df_ano = anova_tables[m_idx]
            isempty(df_ano) && continue

            write(io, Printf.@sprintf("#### Response: %s\n", name))
            
            anova_rows = Vector{String}[]
            for r in eachrow(df_ano)
                src = string(r.Source)
                df_i = string(r.df)
                ss_i = (!ismissing(r.SS) && !isnan(r.SS)) ? @sprintf("%.4f", Float64(r.SS)) : "-"
                ms_i = (!ismissing(r.MS) && !isnan(r.MS)) ? @sprintf("%.4f", Float64(r.MS)) : "-"
                f_i  = (!ismissing(r.F) && !isnan(r.F))   ? @sprintf("%.2f", Float64(r.F))   : "-"
                p_i  = (!ismissing(r.P) && !isnan(r.P))   ? (Float64(r.P) < 0.0001 ? "<0.0001" : @sprintf("%.4f", Float64(r.P))) : "-"

                push!(anova_rows, [src, df_i, ss_i, ms_i, f_i, p_i])
            end

            write(io, VISE_FormatMarkdownTable_DDEF(anova_headers, anova_aligns, anova_rows))
            write(io, "\n")
            
            idx_m = findfirst(==("Model"), df_ano.Source)
            idx_l = findfirst(==("Lack of Fit"), df_ano.Source)
            
            ano_notes = String[]
            if !isnothing(idx_m) && !ismissing(df_ano.P[idx_m]) && !isnan(df_ano.P[idx_m])
                f_m = (!ismissing(df_ano.F[idx_m]) && !isnan(df_ano.F[idx_m])) ? Float64(df_ano.F[idx_m]) : NaN
                p_m = Float64(df_ano.P[idx_m])
                if p_m < 0.05
                    push!(ano_notes, @sprintf("The regression model explains a statistically significant portion of variance (F = %.2f, p = %.4f).", f_m, p_m))
                else
                    push!(ano_notes, @sprintf("The regression model does not explain variance above residual error at α = 0.05 (F = %.2f, p = %.4f).", f_m, p_m))
                end
            end
            
            if !isnothing(idx_l) && !ismissing(df_ano.P[idx_l]) && !isnan(df_ano.P[idx_l])
                f_l = (!ismissing(df_ano.F[idx_l]) && !isnan(df_ano.F[idx_l])) ? Float64(df_ano.F[idx_l]) : NaN
                p_l = Float64(df_ano.P[idx_l])
                if p_l >= 0.05
                    push!(ano_notes, @sprintf("Lack-of-Fit is non-significant (F = %.2f, p = %.4f ≥ 0.05), indicating adequate model structure.", f_l, p_l))
                else
                    push!(ano_notes, @sprintf("Lack-of-Fit is statistically significant (F = %.2f, p = %.4f < 0.05), indicating model inadequacy or uncaptured curvature.", f_l, p_l))
                end
            end
            
            if !isempty(ano_notes)
                write(io, "*ANOVA Interpretation: " * join(ano_notes, " ") * "*\n\n")
            end
        end
    end

    # --- Report Stage IV: Regression Model Coefficients & Collinearity ---
    write(io, "### IV. Regression Model Coefficients & Collinearity\n")
    write(io, "Estimated regression coefficients (β), two-tailed p-values, and Variance Inflation Factors (VIF).\n\n")

    coef_headers = ["Term / Predictor", "Coefficient (β)", "P-Value", "VIF", "Significance"]
    coef_aligns  = [:left, :right, :right, :right, :left]

    for (m_idx, name) in enumerate(out_names)
        m_idx > length(models) && continue
        mod = models[m_idx]
        mod["Status"] != "OK" && continue

        terms  = get(mod, "TermNames", String[])
        coefs  = get(mod, "Coefs", Float64[])
        pcoefs = get(mod, "P_Coefs", Float64[])
        vifs   = get(mod, "VIFs", Float64[])

        isempty(terms) && continue

        write(io, Printf.@sprintf("#### Response: %s\n", name))

        sig_terms = String[]
        coef_rows = Vector{String}[]
        for j in eachindex(terms)
            t_name = terms[j]
            c_val  = (j <= length(coefs)) ? coefs[j] : NaN
            p_val  = (j <= length(pcoefs)) ? pcoefs[j] : NaN
            v_val  = (j <= length(vifs)) ? ((j == 1) ? 1.0 : vifs[j]) : 1.0

            c_str = (!isnan(c_val)) ? @sprintf("%.4f", c_val) : "N/A"
            p_str = (!isnan(p_val)) ? (p_val < 0.0001 ? "<0.0001" : @sprintf("%.4f", p_val)) : "N/A"
            v_str = (!isnan(v_val)) ? @sprintf("%.2f", v_val) : "N/A"
            
            sig = if !isnan(p_val)
                if p_val < 0.001
                    push!(sig_terms, t_name)
                    fmt_pos("***")
                elseif p_val < 0.01
                    push!(sig_terms, t_name)
                    fmt_pos("**")
                elseif p_val < 0.05
                    push!(sig_terms, t_name)
                    fmt_pos("*")
                else
                    "ns"
                end
            else
                ""
            end

            push!(coef_rows, [t_name, c_str, p_str, v_str, sig])
        end

        write(io, VISE_FormatMarkdownTable_DDEF(coef_headers, coef_aligns, coef_rows))
        write(io, "\n")
        
        non_intercept_sig = filter(!=("(Intercept)"), sig_terms)
        sig_msg = if isempty(non_intercept_sig)
            "No factor terms reached statistical significance at α = 0.05."
        else
            "Statistically significant factors (p < 0.05): " * join(non_intercept_sig, ", ") * "."
        end
        
        max_v = length(vifs) > 1 ? maximum(vifs[2:end]) : 1.0
        vif_msg = if max_v <= 5.0
            "Variance Inflation Factors (VIF ≤ 5.0) confirm negligible multicollinearity."
        elseif max_v <= 10.0
            @sprintf("Moderate collinearity detected (maximum VIF = %.2f); parameter variances are slightly inflated.", max_v)
        else
            @sprintf("Severe collinearity detected (maximum VIF = %.2f > 10.0); coefficient standard errors are inflated.", max_v)
        end
        
        write(io, Printf.@sprintf("*Coefficient Interpretation: %s %s*\n\n", sig_msg, vif_msg))
    end
    write(io, "*Significance codes: *** p < 0.001, ** p < 0.01, * p < 0.05, ns: non-significant (p ≥ 0.05).*\n\n")

    # --- Report Stage V: Factor Sensitivity & Relative Importance ---
    if !isempty(sens)
        write(io, "### V. Factor Sensitivity & Relative Importance\n")
        write(io, "Normalised sensitivity derivatives (|∂ŷ/∂Xᵢ|) indicating relative contribution to response variation.\n\n")

        sens_headers = ["Factor Parameter", "Relative Sensitivity (%)", "Sensitivity Rank"]
        sens_aligns  = [:left, :right, :left]

        for (m_idx, name) in enumerate(out_names)
            m_idx > length(sens) && continue
            s_vec = sens[m_idx]
            isempty(s_vec) && continue

            if length(s_vec) == length(in_names)
                write(io, Printf.@sprintf("#### Response: %s\n", name))
                
                sens_rows = Vector{String}[]
                perm = sortperm(s_vec; rev=true)
                for (rank, idx) in enumerate(perm)
                    s_pct = @sprintf("%.2f%%", s_vec[idx] * 100)
                    push!(sens_rows, [in_names[idx], s_pct, "Rank $rank"])
                end

                write(io, VISE_FormatMarkdownTable_DDEF(sens_headers, sens_aligns, sens_rows))
                write(io, "\n")
                
                top_f = in_names[perm[1]]
                top_pct = round(s_vec[perm[1]] * 100; digits=1)
                write(io, Printf.@sprintf("*Sensitivity Interpretation: %s exerts the strongest relative influence (%.1f%%) on %s in the evaluated domain.*\n\n", top_f, top_pct, name))
            end
        end
    end

    # --- Report Stage VI: Multi-Response Numerical Optimisation ---
    best_pt = get(Res, "BestPoint", [])
    if !isempty(best_pt)
        bs = Float64(get(Res, "BestScore", 0.0))
        warns = get(Res, "BoundaryWarnings", String[])
        
        write(io, "### VI. Multi-Response Numerical Optimisation\n")
        write(io, "Simultaneous optimisation via Derringer-Suich desirability function maximisation.\n\n")
        @printf(io, "- **Overall Composite Desirability (D)**: `%.3f` (Scale: 0.000 to 1.000)\n\n", bs)

        # Optimisation Goals Specification Table
        goals = get(Res, "Goals", [])
        if !isempty(goals)
            write(io, "#### Multi-Response Optimisation Criteria\n")
            goals_headers = ["Parameter", "Criterion / Goal", "Target", "Lower Limit", "Upper Limit", "Weight", "Rating"]
            goals_aligns  = [:left, :left, :right, :right, :right, :right, :centre]
            goals_rows    = Vector{String}[]
            for (g_idx, g) in enumerate(goals)
                p_name = string(get(g, "Name", get(g, "Variable", (g_idx <= length(out_names) ? out_names[g_idx] : "Response $g_idx"))))
                p_goal = string(get(g, "Type", get(g, "Goal", "Nominal")))
                p_target = get(g, "Target", NaN)
                p_target_str = (ismissing(p_target) || isnan(p_target)) ? "-" : @sprintf("%.3f", Float64(p_target))
                p_low = get(g, "Low", get(g, "Min", NaN))
                p_low_str = (ismissing(p_low) || isnan(p_low)) ? "-" : @sprintf("%.3f", Float64(p_low))
                p_high = get(g, "High", get(g, "Max", NaN))
                p_high_str = (ismissing(p_high) || isnan(p_high)) ? "-" : @sprintf("%.3f", Float64(p_high))
                raw_w = Float64(get(g, "Weight", 1.0))
                p_weight = @sprintf("%.2f", raw_w)
                p_rating = VISE_GetWeightRating_DDEF(raw_w)
                push!(goals_rows, [p_name, p_goal, p_target_str, p_low_str, p_high_str, p_weight, p_rating])
            end
            write(io, VISE_FormatMarkdownTable_DDEF(goals_headers, goals_aligns, goals_rows))
            write(io, "\n")
        end

        write(io, "#### Optimal Factor Operating Conditions\n")
        opt_headers = ["Factor Parameter", "Optimal Setting (X*)", "Design Space Status"]
        opt_aligns  = [:left, :right, :left]
        opt_rows    = Vector{String}[]

        for (i, val) in enumerate(best_pt)
            fname = (i <= length(in_names)) ? in_names[i] : "Factor $i"
            has_b_warn = any(w -> occursin(fname, w), warns)
            b_status = has_b_warn ? fmt_neg("Boundary proximity") : fmt_pos("Interior design point")
            push!(opt_rows, [fname, @sprintf("%.3f", val), b_status])
        end

        write(io, VISE_FormatMarkdownTable_DDEF(opt_headers, opt_aligns, opt_rows))
        write(io, "\n")
        
        if !isempty(models)
            write(io, "#### Predicted Response Values at Optimum\n")
            pred_headers = ["Response Variable", "Target Criterion", "Predicted Value (ŷ)", "Individual Desirability (d)"]
            pred_aligns  = [:left, :left, :right, :right]
            pred_rows    = Vector{String}[]
            
            bp_mat = reshape(Float64.(best_pt), 1, length(best_pt))
            
            for (m_idx, name) in enumerate(out_names)
                m_idx > length(models) && continue
                mod = models[m_idx]
                mod["Status"] != "OK" && continue
                
                y_opt = try
                    VISE_Predict_DDEF(mod, bp_mat)[1]
                catch
                    NaN
                end
                m_goal = (m_idx <= length(goals)) ? goals[m_idx] : get(mod, "Goal", Dict())
                gtup = Main.Lib_Core.CORE_ExtractGoal_DDEF(m_goal)
                d_i = Main.Lib_Core.CORE_CalcDesirability_DDEF(y_opt, gtup)
                
                g_type = string(get(m_goal, "Type", "Maximise"))
                g_target = get(m_goal, "Target", NaN)
                g_desc = if g_type == "Target" && !isnan(g_target)
                    @sprintf("Target (= %.3f)", Float64(g_target))
                else
                    g_type
                end
                
                push!(pred_rows, [first(name, 24), g_desc, @sprintf("%.3f", y_opt), @sprintf("%.3f", d_i)])
            end

            write(io, VISE_FormatMarkdownTable_DDEF(pred_headers, pred_aligns, pred_rows))
            write(io, "\n")
        end

        # Leader Candidates & Pareto Frontier Table
        ldf = get(Res, "Leaders", nothing)
        if !isnothing(ldf) && isa(ldf, DataFrame) && !isempty(ldf)
            write(io, "#### Candidate Optimisation Solutions (Pareto Frontier & Leader Candidates)\n")
            lead_headers = string.(names(ldf))
            lead_aligns = [:left; fill(:right, length(lead_headers) - 1)]
            lead_rows = Vector{String}[]
            for r in eachrow(ldf)
                row_strs = String[]
                for (col_idx, val) in enumerate(r)
                    if ismissing(val)
                        push!(row_strs, "-")
                    elseif isa(val, Number)
                        push!(row_strs, @sprintf("%.3f", Float64(val)))
                    else
                        push!(row_strs, string(val))
                    end
                end
                push!(lead_rows, row_strs)
            end
            write(io, VISE_FormatMarkdownTable_DDEF(lead_headers, lead_aligns, lead_rows))
            write(io, "\n")
        end

        d_interp = if bs >= 0.80
            @sprintf("Composite desirability D = %.3f indicates excellent simultaneous attainment of response goals.", bs)
        elseif bs >= 0.50
            @sprintf("Composite desirability D = %.3f indicates acceptable satisfaction of competing response targets.", bs)
        else
            @sprintf("Composite desirability D = %.3f reflects significant compromise among conflicting response requirements.", bs)
        end
        
        b_interp = if !isempty(warns)
            "One or more optimal settings lie near the boundary of the experimental domain. Expanding the design space in future trials may yield further optimisation gains."
        else
            "All optimal factor coordinates lie within the interior of the experimental design domain."
        end
        
        write(io, Printf.@sprintf("*Optimisation Summary: %s %s*\n\n", d_interp, b_interp))
    else
        write(io, "### VI. Multi-Response Numerical Optimisation\n")
        write(io, "*Numerical optimisation not conducted or convergence incomplete.*\n\n")
    end

    # --- Report Stage VII: Radiochemical Decay Corrections ---
    if haskey(Res, "RadioCorrection") && !isempty(Res["RadioCorrection"])
        write(io, "### VII. Radiochemical Decay Corrections\n")
        write(io, "Physical decay corrections and yield adjustments performed in accordance with radioactive decay laws.\n\n")

        rad_headers = ["Component", "Type", "Half-Life", "Unit", "Avg Delta-T (min)", "Avg Decay Factor"]
        rad_aligns  = [:left, :left, :right, :left, :right, :right]
        rad_rows    = Vector{String}[]

        for itm in Res["RadioCorrection"]
            push!(rad_rows, [
                string(get(itm, "Name", "")),
                string(get(itm, "Type", "Decay")),
                @sprintf("%.2f", Float64(get(itm, "HalfLife", 0.0))),
                string(get(itm, "Unit", "")),
                @sprintf("%.2f", Float64(get(itm, "AvgDeltaT", 0.0))),
                @sprintf("%.4f", Float64(get(itm, "AvgDF", 1.0)))
            ])
        end

        write(io, VISE_FormatMarkdownTable_DDEF(rad_headers, rad_aligns, rad_rows))
        write(io, "\n")
    end

    write(io, "---\n")
    write(io, "*Generated by DoECISORY $(Main.Sys_Fast.FAST_Data_DDEC.VERSION) | Design of Experiments & Response Surface Methodology*\n")

    return String(take!(io))
end

# ==============================================================================
# PART E: SYSTEM ORCHESTRATION & EXECUTION GATEWAY
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 12: PHASE DATA LOADER & INGESTION
# ------------------------------------------------------------------------------

"""
    VISE_LoadPhaseData_DDEF(Source, Phase, C, [Log]) -> DataFrame
High-fidelity data loader that filters global experiment records for phase-specific analysis.
Accepts either an Excel FilePath or an existing DataFrame.
"""
function VISE_LoadPhaseData_DDEF(df::AbstractDataFrame, Phase::AbstractString, C, Log=Sys_Fast.FAST_Log_DDEF)
    isempty(df) && return DataFrame()
    if hasproperty(df, Symbol(C.COL_PHASE))
        clean_target = replace(strip(Phase), " " => "")
        isempty(clean_target) && return df
        return filter(r -> replace(strip(string(r[C.COL_PHASE])), " " => "") == clean_target, df)
    end
    return df
end

function VISE_LoadPhaseData_DDEF(FilePath::AbstractString, Phase::AbstractString, C, Log=Sys_Fast.FAST_Log_DDEF)
    df = Main.Sys_Fast.FAST_ReadExcel_DDEF(FilePath, C.SHEET_DATA)
    return VISE_LoadPhaseData_DDEF(df, Phase, C, Log)
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
    Opts::AbstractDict=Dict{String,Any}(), ConfigUpdates::AbstractDict=Dict{String,Any}(), t_start::Float64=time(), RenderMode::Symbol=:Full, Optim::Bool=true)
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

    # Multi-Phase Dataset Preservation: Merge phase-specific updates back into global dataset
    try
        df_full = Main.Sys_Fast.FAST_ReadExcel_DDEF(DataFile, C.SHEET_DATA)
        if !isempty(df_full) && hasproperty(df_full, Symbol(C.COL_PHASE))
            clean_target = replace(strip(Phase), " " => "")
            mask_other = coalesce.(replace.(strip.(string.(df_full[!, C.COL_PHASE])), " " => "") .!= clean_target, false)
            if any(mask_other) && haskey(sheets_to_commit, C.SHEET_DATA)
                df_up = sheets_to_commit[C.SHEET_DATA]
                for col in names(df_up)
                    col_sym = Symbol(col)
                    col_up_str = uppercase(string(col))
                    is_meta_col = col_up_str in (C.COL_EXP_ID, "ID", C.COL_PHASE, C.COL_STATUS, C.COL_NOTES)
                    if col_sym in propertynames(df_full)
                        if !is_meta_col && eltype(df_full[!, col_sym]) === Missing
                            VISE_WidenColumnFloat_DDEF!(df_full, col_sym)
                        end
                    else
                        col_eltype = is_meta_col ? String : Union{Missing, Float64}
                        df_full[!, col_sym] = Vector{col_eltype}(missing, nrow(df_full))
                    end
                end
                p_indices = findall(.!mask_other)
                for (i, r_idx) in enumerate(p_indices)
                    if i <= nrow(df_up)
                        for col in names(df_up)
                            df_full[r_idx, Symbol(col)] = df_up[i, Symbol(col)]
                        end
                    end
                end
                sheets_to_commit[C.SHEET_DATA] = df_full
            end
        end
    catch e_merge
        Log("VISE", "MERGE_WARN", "Multi-phase data merge fallback: $e_merge", "WARN")
    end

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
    
    X_Nominal = copy(X_Clean)
    radio_audit = VISE_ApplyForwReveDecay_DDEF(X_Clean, Y_Clean, InNames, OutNames, df_raw, config, Opts, C, Log; mask=valid_mask)
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
        f_dict = get(r_opts, "FORW", Dict{String,Any}())
        r_dict = get(r_opts, "REVE", Dict{String,Any}())
        forw_active_disp = get(f_dict, "Enabled", false) in (true, 1, "ON", "true", "TRUE")
        reve_active_disp = get(r_dict, "Enabled", false) in (true, 1, "ON", "true", "TRUE")

        if forw_active_disp
            for (i, n) in enumerate(DispInNames)
                if haskey(f_dict, n) && f_dict[n] isa AbstractDict
                    disp_n = get(f_dict[n], "Name", "")
                    disp_u = get(f_dict[n], "Unit", "")
                    !isempty(disp_n) && (DispInNames[i] = disp_n * (isempty(disp_u) ? "" : " ($disp_u)"))
                end
            end
        end
        if reve_active_disp
            for (i, n) in enumerate(DispOutNames)
                if haskey(r_dict, n) && r_dict[n] isa AbstractDict
                    disp_n = get(r_dict[n], "Name", "")
                    disp_u = get(r_dict[n], "Unit", "")
                    !isempty(disp_n) && (DispOutNames[i] = disp_n * (isempty(disp_u) ? "" : " ($disp_u)"))
                end
            end
        end
    end

    mods_dcyp = VISE_ExtractDCYP_DDEF(InNames_v, OutNames_v, config, Opts)

    # Mathematical Optimisation: BBO Pulse in Initial Space (X_Nominal bounds)
    bp, bs, ldf, SC, warns = if Optim
        VISE_RunOptimisation_DDEF(X_Clean, models, Goals, config, Phase, InNames_v, OutNames_v, Opts, C, Log; X_Nominal=X_Nominal)
    else
        [], 0.0, DataFrame(), zeros(1), String[]
    end
    
    Y_Pred, Actual_Scores = VISE_GeneratePredictions_DDEF(X_Clean, Y_Clean, models, Goals; ModifiersDCYP=mods_dcyp)
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
    vitals = Dict("D" => 0.0, "A" => 0.0, "G" => 0.0, "I" => 0.0, "Condition" => Inf, "MaxVIF" => 0.0, "LOF" => 1.0)
    try
        best_m_idx = findfirst(m -> get(m, "ModelType", "") == "quadratic", models)
        isnothing(best_m_idx) && (best_m_idx = 1)
        m_type_str = get(models[best_m_idx], "ModelType", "linear")
        
        X_Coded = Main.Lib_Core.CORE_CodeMatrix_DDEF(X_Clean)
        Xd_health = VISE_ExpandDesign_DDEF(X_Coded, m_type_str)
        m_health = Main.Lib_Core.CORE_CalcDesignMetrics_DDEF(X_Coded, m_type_str)
        
        vitals["D"] = Float64(get(m_health, "D", 0.0))
        vitals["A"] = Float64(get(m_health, "A", 0.0))
        vitals["G"] = Float64(get(m_health, "G", 0.0))
        vitals["I"] = Float64(get(m_health, "I", 0.0))
        vitals["Condition"] = Float64(get(m_health, "Condition", Inf))
        vif_list = [maximum(get(m, "VIFs", [0.0])[2:end]) for m in models if haskey(m, "VIFs") && length(m["VIFs"]) > 1]
        vitals["MaxVIF"] = isempty(vif_list) ? 1.0 : Float64(maximum(vif_list))
        
        if n_samples > size(Xd_health, 2) + 2
            _, p_lof = VISE_LackOfFit_DDEF(Xd_health, view(Y_Clean, :, 1))
            vitals["LOF"] = (ismissing(p_lof) || isnan(p_lof)) ? NaN : Float64(p_lof)
        end
    catch e
        Log("VISE", "VITALS_WARN", "Design vitals evaluation incomplete: $e", "WARN")
    end
    
    opts_with_mode = copy(Opts)
    opts_with_mode["Mode"] = RenderMode

    graphs = Main.Lib_Arts.ARTS_Render_DDEF(models, X_Nominal, Y_Clean, DispInNames, DispOutNames, Goals, 
        [get(m, "R2_Adj", 0.0) for m in models], [get(m, "Q2", 0.0) for m in models], opts_with_mode, ldf,
        sens_list, residuals)
        
    sheets_to_commit = Dict(C.SHEET_DATA => df_updated)
    sheet_leader     = C.PREFIX_LEADERS * Phase
    sheets_to_commit[sheet_leader] = ldf
    
    res_bundle = VISE_AssembleBundle_DDEF(Phase, InNames_v, OutNames_v, DispInNames, DispOutNames, models, bp, bs, ldf, X_Clean, Y_Clean, Opts, 
        Goals, Y_Pred, Actual_Scores, radio_audit, warns, vitals, anova_tables, normality_res, residuals, sens_list, graphs, t_start, C; X_Nominal=X_Nominal)
        
    return res_bundle, sheets_to_commit
end

# ------------------------------------------------------------------------------
# SECTION 15: INTERNAL LOGISTIC HELPERS
# ------------------------------------------------------------------------------

function VISE_IngestMatrices_DDEF(df::DataFrame, config::AbstractDict, C, Log)
    # Phase-specific isolation: Ingest only columns that have active numeric data in this phase
    in_cols = filter(names(df)) do n
        startswith(uppercase(strip(string(n))), C.PRE_INPUT) &&
        any(x -> !ismissing(x) && !isnan(Main.Sys_Fast.FAST_SafeNum_DDEF(x)), df[!, n])
    end
    out_cols = filter(names(df)) do n
        startswith(uppercase(strip(string(n))), C.PRE_RESULT) &&
        any(x -> !ismissing(x) && !isnan(Main.Sys_Fast.FAST_SafeNum_DDEF(x)), df[!, n])
    end
    
    # Architectural Guard: DoECISORY strictly operates on 3 factor dimensions per phase
    if length(in_cols) > 3
        Log("VISE", "INGEST_WARN", "Expected 3 factor columns for Phase analysis, found $(length(in_cols)): $(join(in_cols, ", ")). Selecting first 3.", "WARN")
        in_cols = in_cols[1:3]
    end
    
    nr = nrow(df)
    in_len, out_len = length(in_cols), length(out_cols)
    
    # Stability Guard: Ensure we always have at least one column to prevent 0xN Matrix structural failures
    X = zeros(nr, max(1, in_len))
    Y = fill(NaN, nr, max(1, out_len))
    
    for (ci, c) in enumerate(in_cols) X[:, ci] .= Main.Sys_Fast.FAST_SafeNum_DDEF.(df[!, c]) end
    for (ci, c) in enumerate(out_cols) Y[:, ci] .= Main.Sys_Fast.FAST_SafeNum_DDEF.(df[!, c]) end
    
    mask = out_len > 0 ? vec(all(!isnan, Y[:, 1:out_len]; dims=2)) : fill(false, nr)
    xc, yc = X[mask, 1:in_len], Y[mask, 1:out_len]   
    
    # Strict Type Enforcement: Ensure names are Vector{String} to avoid MethodError in TrainEnsemble
    in_names = String[VISE_ResolveName_DDEF(string(n), C.PRE_INPUT, get(config, "Ingredients", []), C) for n in in_cols]
    out_names = String[VISE_ResolveName_DDEF(string(n), C.PRE_RESULT, get(config, "Outputs", []), C) for n in out_cols]
    
    # Final Matrix Emergency Fallback: If no valid rows or columns were found
    if isempty(xc) || size(xc, 2) == 0
        if isempty(in_cols)
            Log("VISE", "INGEST_FAIL", "Matrix Extraction Failure: No valid columns matched prefix $(C.PRE_INPUT) with numeric data.", "FAIL")
            return zeros(0, 3), zeros(0, 1), ["X1", "X2", "X3"], ["Y1"], fill(false, nr)
        elseif isempty(out_cols)
            Log("VISE", "INGEST_INFO", "No experimental response data found in $(C.PRE_RESULT) columns for this phase.", "INFO")
            return zeros(0, in_len), zeros(0, 1), in_names, ["Y1"], fill(false, nr)
        else
            Log("VISE", "INGEST_WARN", "No rows with complete response data found (mask empty).", "WARN")
            return zeros(0, in_len), zeros(0, out_len), in_names, out_names, fill(false, nr)
        end
    end
    
    return xc, yc, in_names, out_names, mask
end

"""
    VISE_ResolveName_DDEF(ColumnName, Prefix, ConfigList, C) -> String
Resolves the variable or response name from column headers using configuration metadata with safe fallback.
Handles underscore vs space differences, casing, and attached unit suffixes (e.g. `_` or `_%`).
"""
function VISE_ResolveName_DDEF(ColumnName::AbstractString, Prefix::AbstractString, ConfigList, C)::String
    raw_col = strip(string(ColumnName))
    isempty(raw_col) && return ""
    raw_up  = uppercase(raw_col)

    norm_tok(s) = uppercase(replace(replace(strip(string(s)), "_" => " "), r"\s+" => " "))

    if !isempty(ConfigList)
        # 1. Exact match against expected headers from configuration
        for item in ConfigList
            nm = strip(string(Main.Sys_Fast.FAST_GetSafe_DDEF(item, "Name", "")))
            isempty(nm) && continue
            u = strip(string(Main.Sys_Fast.FAST_GetSafe_DDEF(item, "Unit", "")))
            exp_header = (isempty(u) || u == "-") ? Prefix * nm : Prefix * nm * "_" * u
            if raw_up == uppercase(exp_header)
                return nm
            end
        end

        for item in ConfigList
            nm = strip(string(Main.Sys_Fast.FAST_GetSafe_DDEF(item, "Name", "")))
            isempty(nm) && continue
            if raw_up == uppercase(Prefix * nm)
                return nm
            end
        end

        # 2. Normalised comparison (handling space vs underscore and units)
        col_clean = replace(raw_col, Regex("(?i)^" * Prefix) => "")
        col_norm  = norm_tok(col_clean)

        for item in ConfigList
            nm = strip(string(Main.Sys_Fast.FAST_GetSafe_DDEF(item, "Name", "")))
            isempty(nm) && continue
            nm_norm = norm_tok(nm)

            # Direct normalised match
            if col_norm == nm_norm
                return nm
            end

            # Match with unit suffix stripped
            u = strip(string(Main.Sys_Fast.FAST_GetSafe_DDEF(item, "Unit", "")))
            if !isempty(u) && u != "-"
                if col_norm == norm_tok(nm * " " * u) || col_norm == norm_tok(nm * "_" * u)
                    return nm
                end
            end

            # Prefix-based match if unit or trailing token is appended
            if startswith(col_norm, nm_norm) && (length(col_norm) == length(nm_norm) || col_norm[length(nm_norm)+1] in (' ', '_', '%'))
                return nm
            end
        end

        # 3. Direct name check
        for item in ConfigList
            nm = strip(string(Main.Sys_Fast.FAST_GetSafe_DDEF(item, "Name", "")))
            isempty(nm) && continue
            u = strip(string(Main.Sys_Fast.FAST_GetSafe_DDEF(item, "Unit", "")))
            exp_header = (isempty(u) || u == "-") ? nm : nm * "_" * u
            if raw_up == uppercase(exp_header) || raw_up == uppercase(nm)
                return nm
            end
        end
    end

    clean = Main.Sys_Fast.FAST_CleanHeader_DDEF(raw_col)
    clean_no_pfx = replace(clean, Regex("(?i)^" * Prefix) => "")
    return clean_no_pfx
end

"""
    VISE_WidenColumnFloat_DDEF!(df::DataFrame, col_sym::Symbol) -> Symbol
Safely widens the eltype of a column to Vector{Union{Missing, Float64}} to prevent MethodError when assigning numeric values.
"""
function VISE_WidenColumnFloat_DDEF!(df::DataFrame, col_sym::Symbol)::Symbol
    if !(col_sym in propertynames(df))
        df[!, col_sym] = Vector{Union{Missing, Float64}}(missing, nrow(df))
    else
        df[!, col_sym] = Vector{Union{Missing, Float64}}([
            (ismissing(v) || (v isa AbstractString && isempty(strip(v)))) ? missing : Float64(Main.Sys_Fast.FAST_SafeNum_DDEF(v))
            for v in df[!, col_sym]
        ])
    end
    return col_sym
end

"""
    VISE_InsertColAfter_DDEF!(df::DataFrame, new_col::String, ref_col::String) -> DataFrame
Safely positions `new_col` immediately to the right of `ref_col` in `df` without altering other columns.
"""
function VISE_InsertColAfter_DDEF!(df::DataFrame, new_col::String, ref_col::String)::DataFrame
    col_names = string.(names(df))
    (new_col == ref_col || !(new_col in col_names)) && return df
    ref_idx = findlast(==(ref_col), col_names)
    isnothing(ref_idx) && return df

    filter!(c -> c != new_col, col_names)
    ref_idx = findlast(==(ref_col), col_names)
    isnothing(ref_idx) && return df

    insert!(col_names, ref_idx + 1, new_col)
    select!(df, Symbol.(col_names))
    return df
end

"""
    VISE_ApplyForwReveDecay_DDEF(X, Y, InNames, OutNames, DataFrame, Config, Opts, Constants, Log; mask) -> Vector{Dict}
Executes forward and reverse radioactive decay corrections across experimental data matrices:
1. Forward Phase (Precursor Inputs): Decays precursor amounts from preparation to synthesis time (Reverse=false).
   Always populates `ACTUAL_<Isotope>` columns in `DataFrame` based on physical decay laws regardless of UI toggles.
2. Reverse Phase (Product Outputs): Pure reverse radioactive decay correction restoring delayed measured product activity
   back to End of Synthesis (EOS, Reverse=true). Populates `ACTUAL_<OutputName>` immediately to the right of the precursor
   `ACTUAL_` column without altering raw experimental records (`RESULT_`).
All physical radioactive decay factors are calculated via `Lib_Mole.MOLE_CalcRadioDecay_DDEF`.
"""
function VISE_ApplyForwReveDecay_DDEF(X, Y, in_n, out_n, df, config, opts, C, Log; mask=trues(nrow(df)))
    audit = Dict{String,Any}[]
    r_opts      = get(opts, "RadioOpts", Dict{String,Any}())
    apply_radio = get(r_opts, "Apply", false)
    fwd_dict    = get(r_opts, "FORW", Dict{String,Any}())
    rev_dict    = get(r_opts, "REVE", Dict{String,Any}())

    forw_active = apply_radio && (get(fwd_dict, "Enabled", false) in (true, 1, "ON", "true", "TRUE"))
    reve_active = apply_radio && (get(rev_dict, "Enabled", false) in (true, 1, "ON", "true", "TRUE"))

    ingreds = get(config, "Ingredients", [])
    idx_m   = findall(mask)
    N       = length(idx_m)
    N == 0 && return audit

    # --------------------------------------------------------------------------
    # Phase 1: Forward Decay (Inputs & Fixed Precursors)
    # Populates ACTUAL_ columns in the dataset.
    # --------------------------------------------------------------------------
    for ing in ingreds
        v_name = strip(string(get(ing, "Name", "")))
        isempty(v_name) && continue

        hl_raw   = Float64(Main.Sys_Fast.FAST_SafeNum_DDEF(get(ing, "HalfLife", 0.0)))
        hl_unit  = string(get(ing, "HalfLifeUnit", "Hours"))
        hl_min   = Main.Lib_Mole.MOLE_ConvertTimeToMinutes_DDEF(hl_raw, hl_unit)
        is_radio = (get(ing, "IsRadioactive", false) in (true, 1, "true", "TRUE")) || hl_min > 0.0
        !is_radio && continue

        v_idx = findfirst(==(v_name), in_n)

        # Locate elapsed synthesis delay: TIME_FORW_MINS_<Name>
        col_exp = Main.Sys_Fast.FAST_GetCol_DDEF(df, "TIME_FORW_MINS_" * v_name)

        # Locate actual decayed activity column: ACTUAL_<Name>
        col_actual = Main.Sys_Fast.FAST_GetCol_DDEF(df, "ACTUAL_" * v_name)
        if isempty(col_actual)
            p_names = string.(names(df))
            act_match = findfirst(c -> startswith(c, "ACTUAL_") && occursin(v_name, c), p_names)
            !isnothing(act_match) && (col_actual = p_names[act_match])
        end
        if isempty(col_actual)
            v_u = string(get(ing, "Unit", ""))
            col_actual = (isempty(v_u) || v_u == "-") ? ("ACTUAL_" * v_name) : ("ACTUAL_" * v_name * "_" * v_u)
        end

        # Locate nominal precursor column
        col_nom = Main.Sys_Fast.FAST_GetCol_DDEF(df, C.PRE_INPUT * v_name)
        isempty(col_nom) && (col_nom = Main.Sys_Fast.FAST_GetCol_DDEF(df, C.PRE_FIXED * v_name))
        isempty(col_nom) && (col_nom = Main.Sys_Fast.FAST_GetCol_DDEF(df, C.PRE_FILL * v_name))
        if isempty(col_nom)
            p_names = string.(names(df))
            m_nom = findfirst(c -> (startswith(c, C.PRE_INPUT) || startswith(c, C.PRE_FIXED) || startswith(c, C.PRE_FILL)) && occursin(v_name, c), p_names)
            !isnothing(m_nom) && (col_nom = p_names[m_nom])
        end

        if !isempty(col_actual)
            VISE_WidenColumnFloat_DDEF!(df, Symbol(col_actual))
        end

        is_target_forw = forw_active && haskey(fwd_dict, v_name) && (fwd_dict[v_name] isa AbstractDict)

        dfs = Float64[]
        for (i, r_idx) in enumerate(idx_m)
            t_min   = isempty(col_exp) ? 0.0 : Main.Sys_Fast.FAST_SafeNum_DDEF(df[r_idx, col_exp])
            val_nom = !isempty(col_nom) ? Main.Sys_Fast.FAST_SafeNum_DDEF(df[r_idx, col_nom]) :
                      (i <= size(X, 1) && !isnothing(v_idx) && v_idx <= size(X, 2) ? Float64(X[i, v_idx]) : 0.0)
            df_row  = (hl_min > 0.0 && t_min > 0.0) ? Main.Lib_Mole.MOLE_CalcRadioDecay_DDEF(1.0, hl_raw, hl_unit, t_min; Reverse=false) : 1.0

            val_act = (hl_min > 0.0 && t_min > 0.0 && val_nom > 0.0) ?
                Main.Lib_Mole.MOLE_CalcRadioDecay_DDEF(val_nom, hl_raw, hl_unit, t_min; Reverse=false) :
                val_nom

            if !isempty(col_actual) && val_act > 0.0
                df[r_idx, Symbol(col_actual)] = round(val_act; digits=4)
            end

            # Only mutate training matrix X if Forward Decay is explicitly active for this ingredient
            if is_target_forw && !isnothing(v_idx) && val_act > 0.0
                X[i, v_idx] = val_act
            end
            push!(dfs, df_row)
        end

        if is_target_forw
            type_lbl = isnothing(v_idx) ? "FORW (Fixed)" : "FORW (Input)"
            f_opts = get(fwd_dict, v_name, Dict())
            disp_name = get(f_opts, "Name", "")
            disp_name = isempty(disp_name) ? v_name : disp_name

            push!(audit, Dict(
                "Name"        => disp_name,
                "HalfLife"    => hl_raw,
                "Unit"        => hl_unit,
                "Type"        => type_lbl,
                "AvgDeltaT"   => isempty(col_exp) ? 0.0 : mean(Main.Sys_Fast.FAST_SafeNum_DDEF.(df[idx_m, col_exp])),
                "AvgDF"       => isempty(dfs) ? 1.0 : mean(dfs),
                "IsCorrected" => true
            ))
        end
    end

    # Fallback header scan: Populate any remaining empty input ACTUAL_ columns
    for col in names(df)
        col_str = string(col)
        !startswith(col_str, "ACTUAL_") && continue
        
        vals = df[idx_m, col]
        all(!ismissing, vals) && continue
        
        comp_token = replace(replace(col_str, "ACTUAL_" => ""), r"_[a-zA-Z%]+$" => "")
        ing_idx = findfirst(i -> occursin(lowercase(strip(string(get(i, "Name", "")))), lowercase(comp_token)) ||
                                 occursin(lowercase(comp_token), lowercase(strip(string(get(i, "Name", ""))))), ingreds)
        isnothing(ing_idx) && continue
        ing_match = ingreds[ing_idx]
        
        hl_raw   = Float64(Main.Sys_Fast.FAST_SafeNum_DDEF(get(ing_match, "HalfLife", 0.0)))
        hl_unit  = string(get(ing_match, "HalfLifeUnit", "Hours"))
        hl_min   = Main.Lib_Mole.MOLE_ConvertTimeToMinutes_DDEF(hl_raw, hl_unit)
        hl_min <= 0.0 && continue
        
        col_exp = Main.Sys_Fast.FAST_GetCol_DDEF(df, "TIME_FORW_MINS_" * comp_token)
        col_nom = Main.Sys_Fast.FAST_GetCol_DDEF(df, C.PRE_INPUT * comp_token)
        isempty(col_nom) && (col_nom = Main.Sys_Fast.FAST_GetCol_DDEF(df, C.PRE_FIXED * comp_token))
        isempty(col_nom) && (col_nom = Main.Sys_Fast.FAST_GetCol_DDEF(df, C.PRE_FILL * comp_token))
        
        VISE_WidenColumnFloat_DDEF!(df, Symbol(col_str))
        for r_idx in idx_m
            t_min   = isempty(col_exp) ? 0.0 : Main.Sys_Fast.FAST_SafeNum_DDEF(df[r_idx, col_exp])
            val_nom = isempty(col_nom) ? 0.0 : Main.Sys_Fast.FAST_SafeNum_DDEF(df[r_idx, col_nom])
            val_act = (hl_min > 0.0 && t_min > 0.0 && val_nom > 0.0) ?
                Main.Lib_Mole.MOLE_CalcRadioDecay_DDEF(val_nom, hl_raw, hl_unit, t_min; Reverse=false) : val_nom
            if val_act > 0.0
                df[r_idx, Symbol(col_str)] = round(val_act; digits=4)
            end
        end
    end

    # --------------------------------------------------------------------------
    # Phase 2: Pure Reverse Decay & Activity EOS Restoration (Outputs)
    # Populates ACTUAL_<OutputName> immediately right of input ACTUAL_
    # --------------------------------------------------------------------------
    if reve_active
        effective_rev = filter(p -> p.first != "Enabled" && p.second isa AbstractDict, rev_dict)
        for (out_name, out_data) in effective_rev
            out_data isa AbstractDict || continue
            mapped_in_name = get(out_data, "Source", "None")
            (mapped_in_name == "None" || isempty(mapped_in_name)) && continue
            o_idx = findfirst(==(out_name), out_n)
            isnothing(o_idx) && continue

            idx = findfirst(i -> get(i, "Name", "") == mapped_in_name, ingreds)
            isnothing(idx) && continue
            ing = ingreds[idx]

            hl_raw  = Float64(Main.Sys_Fast.FAST_SafeNum_DDEF(get(ing, "HalfLife", 0.0)))
            hl_unit = string(get(ing, "HalfLifeUnit", "Hours"))
            hl_min  = Main.Lib_Mole.MOLE_ConvertTimeToMinutes_DDEF(hl_raw, hl_unit)
            hl_min <= 0.0 && continue

            # Measurement latency column: TIME_REVE_MINS_<Source> or TIME_REVE_MINS_<Output>
            col_meas = Main.Sys_Fast.FAST_GetCol_DDEF(df, "TIME_REVE_MINS_" * mapped_in_name)
            isempty(col_meas) && (col_meas = Main.Sys_Fast.FAST_GetCol_DDEF(df, "TIME_REVE_MINS_" * out_name))

            # Raw experimental result column: RESULT_<Output> (strictly preserved)
            col_res = Main.Sys_Fast.FAST_GetCol_DDEF(df, C.PRE_RESULT * out_name)
            if isempty(col_res)
                p_names = string.(names(df))
                m_res = findfirst(c -> startswith(c, C.PRE_RESULT) && occursin(out_name, c), p_names)
                !isnothing(m_res) && (col_res = p_names[m_res])
            end

            # Resolve output ACTUAL column header: ACTUAL_<OutputName>
            outputs_cfg = get(config, "Outputs", [])
            o_cfg_idx = findfirst(o -> get(o, "Name", "") == out_name, outputs_cfg)
            out_unit = !isnothing(o_cfg_idx) ? string(get(outputs_cfg[o_cfg_idx], "Unit", "")) : ""
            disp_unit = get(out_data, "Unit", out_unit)

            col_act_out = Main.Sys_Fast.FAST_GetCol_DDEF(df, "ACTUAL_" * out_name)
            if isempty(col_act_out)
                col_act_out = (isempty(disp_unit) || disp_unit == "-") ? ("ACTUAL_" * out_name) : ("ACTUAL_" * out_name * "_" * disp_unit)
            end

            VISE_WidenColumnFloat_DDEF!(df, Symbol(col_act_out))

            # Reorder df columns: Place ACTUAL_<OutputName> immediately to the right of input ACTUAL_ column
            in_act_cols = filter(c -> startswith(string(c), "ACTUAL_") && string(c) != col_act_out, names(df))
            if !isempty(in_act_cols)
                ref_col = string(last(in_act_cols))
                VISE_InsertColAfter_DDEF!(df, col_act_out, ref_col)
            end

            dfs = Float64[]
            for (i, r_idx) in enumerate(idx_m)
                t_meas = isempty(col_meas) ? 0.0 : Main.Sys_Fast.FAST_SafeNum_DDEF(df[r_idx, col_meas])
                val_raw = !isempty(col_res) ? Main.Sys_Fast.FAST_SafeNum_DDEF(df[r_idx, col_res]) :
                          (i <= size(Y, 1) && o_idx <= size(Y, 2) ? Float64(Y[i, o_idx]) : 0.0)

                df_row = (hl_min > 0.0 && t_meas > 0.0) ?
                         Main.Lib_Mole.MOLE_CalcRadioDecay_DDEF(1.0, hl_raw, hl_unit, t_meas; Reverse=true) : 1.0

                # Pure Reverse Decay: Restore delayed measurement to End of Synthesis (EOS)
                A_out_corr = (hl_min > 0.0 && t_meas > 0.0 && val_raw > 0.0) ?
                             Main.Lib_Mole.MOLE_CalcRadioDecay_DDEF(val_raw, hl_raw, hl_unit, t_meas; Reverse=true) :
                             val_raw

                if A_out_corr > 0.0
                    df[r_idx, Symbol(col_act_out)] = round(A_out_corr; digits=4)
                end

                # When radio correction is applied, update Y directly with EOS activity
                if A_out_corr > 0.0 && i <= size(Y, 1) && o_idx <= size(Y, 2)
                    Y[i, o_idx] = A_out_corr
                end
                push!(dfs, df_row)
            end

            disp_name = get(out_data, "Name", "")
            disp_name = isempty(disp_name) ? out_name : disp_name

            push!(audit, Dict(
                "Name"        => disp_name,
                "HalfLife"    => hl_raw,
                "Unit"        => hl_unit,
                "Type"        => "REVE (EOS Activity)",
                "AvgDeltaT"   => isempty(col_meas) ? 0.0 : mean(Main.Sys_Fast.FAST_SafeNum_DDEF.(df[idx_m, col_meas])),
                "AvgDF"       => isempty(dfs) ? 1.0 : mean(dfs),
                "IsCorrected" => true
            ))
        end
    end

    return audit
end

# ------------------------------------------------------------------------------
# SECTION 16: DECAY-COUPLED OPTIMISATION BRIDGE (DCYP)
# ------------------------------------------------------------------------------

"""
    VISE_ExtractDCYP_DDEF(InNames, OutNames, Config, Opts) -> Vector{CORE_ModifierDCYP_DDES}
Extracts decay modifier parameters for the DCYP (Decay Penalty) mechanism.
Decoupled from individual outputs, DCYP directly penalises composite desirability
D by e^(-lambda * t_reaction) over the incubation time, balancing chemical conversion
against isotope physical decay.
"""
function VISE_ExtractDCYP_DDEF(in_n::AbstractVector{<:AbstractString}, out_n::AbstractVector{<:AbstractString},
    config::AbstractDict, opts::AbstractDict)::Vector{Main.Lib_Core.CORE_ModifierDCYP_DDES}

    modifiers = Main.Lib_Core.CORE_ModifierDCYP_DDES[]
    !get(get(opts, "RadioOpts", Dict()), "Apply", false) && return modifiers

    r_opts    = get(opts, "RadioOpts", Dict{String,Any}())
    dcyp_cfg  = get(r_opts, "DCYP", Dict())
    
    dcyp_enabled = if dcyp_cfg isa AbstractDict
        get(dcyp_cfg, "Enabled", false) in (true, 1, "ON", "true", "TRUE")
    elseif dcyp_cfg isa AbstractString
        uppercase(strip(dcyp_cfg)) in ("ON", "TRUE", "1")
    elseif dcyp_cfg isa Bool
        dcyp_cfg
    else
        false
    end
    !dcyp_enabled && return modifiers

    ingreds = get(config, "Ingredients", [])

    # Step 1: Identify reaction time variable index among the input factors
    time_indices = Int[]
    for (idx, name) in enumerate(in_n)
        ing_match = findfirst(i -> get(i, "Name", "") == name, ingreds)
        if !isnothing(ing_match)
            unit_str = string(get(ingreds[ing_match], "Unit", ""))
            if Main.Lib_Mole.MOLE_IsTimeUnit_DDEF(unit_str) || occursin(r"(?i)(time|duration|min|minute|hour|sec)", name)
                push!(time_indices, idx)
            end
        else
            if occursin(r"(?i)(time|duration|min|minute|hour|sec)", name)
                push!(time_indices, idx)
            end
        end
    end

    isempty(time_indices) && return modifiers

    # Step 2: Identify isotope for decay constant lambda
    selected_iso = dcyp_cfg isa AbstractDict ? get(dcyp_cfg, "Isotope", "Auto") : "Auto"
    
    rad_candidates = filter(ingreds) do ing
        is_rad = get(ing, "IsRadioactive", false) == true
        hl_raw = Main.Sys_Fast.FAST_SafeNum_DDEF(get(ing, "HalfLife", 0.0))
        return is_rad || hl_raw > 0.0
    end

    target_ing = nothing
    if selected_iso != "Auto" && !isempty(selected_iso)
        idx = findfirst(i -> get(i, "Name", "") == selected_iso, rad_candidates)
        if !isnothing(idx)
            target_ing = rad_candidates[idx]
        end
    end
    if isnothing(target_ing) && !isempty(rad_candidates)
        target_ing = first(rad_candidates)
    end

    isnothing(target_ing) && return modifiers

    hl_raw  = Main.Sys_Fast.FAST_SafeNum_DDEF(get(target_ing, "HalfLife", 0.0))
    hl_raw <= 0.0 && return modifiers
    hl_unit = string(get(target_ing, "HalfLifeUnit", "Hours"))
    hl_min  = Main.Lib_Mole.MOLE_ConvertTimeToMinutes_DDEF(hl_raw, hl_unit)
    hl_min <= 0.0 && return modifiers

    lambda = log(2) / hl_min
    iso_name = string(get(target_ing, "Name", "Radioisotope"))

    for t_idx in time_indices
        push!(modifiers, Main.Lib_Core.CORE_ModifierDCYP_DDES(
            t_idx, lambda, iso_name
        ))
    end

    if !isempty(modifiers)
        Main.Sys_Fast.FAST_Log_DDEF("VISE", "DECAY_BRIDGE",
            "Decay-Coupled Optimisation (DCYP) ACTIVE: $(iso_name) (t½ = $(hl_raw) $(hl_unit)) on factor '$(in_n[first(time_indices)])' [λ = $(round(lambda; digits=6)) min⁻¹]", "OK")
    end

    return modifiers
end

function VISE_RunOptimisation_DDEF(X, models, goals, config, phase, in_n, out_n, opts, C, Log; X_Nominal=X)
    !get(opts, "Optim", true) && return [], 0.0, DataFrame(), zeros(1), String[]
    
    # Search space bounds derived from initial nominal space (X_Nominal)
    bounds = hcat(minimum(X_Nominal; dims=1)', maximum(X_Nominal; dims=1)')
    mods_dcyp = VISE_ExtractDCYP_DDEF(in_n, out_n, config, opts)
    
    grid_steps = get(opts, "GridSteps", 41)
    XT, YP, SC = VISE_GridSearch_DDEF(models, goals, bounds; Steps=grid_steps, ModifiersDCYP=mods_dcyp)
    
    max_time = get(opts, "MaxTime", 2.0)
    bp, bs = Main.Lib_Core.CORE_OptimiseDesirability_DDEF(models, goals, bounds; MaxTime=max_time, ModifiersDCYP=mods_dcyp)
    
    # Predict outputs for continuous BBO point 
    num_models = length(models)
    bp_mat = reshape(Float64.(bp), 1, 3)
    yp_bbo = zeros(Float64, 1, num_models)
    for m in 1:num_models
        if models[m]["Status"] == "OK"
            yp_bbo[1, m] = VISE_Predict_DDEF(models[m], bp_mat)[1]
        end
    end

    # Fuse BBO Optimum and Grid Candidates
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
    cand_tags = String[c[4] ? @sprintf("TOP-%02d*", k) : @sprintf("TOP-%02d", k) for (k, c) in enumerate(selected_top)]
    
    bench_score = cand_sc_list[1]
    score_limit = bench_score * 0.90
    tier_indices = findall(>=(score_limit), SC)
    (isempty(tier_indices)) && (tier_indices = top_grid_indices)

    # Input Minimisation Diversity
    for i in 1:min(3, size(XT, 2))
        tag_pre = i <= length(in_n) ? replace(strip(in_n[i]), " " => "_") : "X$i"
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

    # Output Maximisation Diversity
    for i in 1:min(3, size(YP, 2))
        tag_pre = i <= length(out_n) ? replace(strip(out_n[i]), " " => "_") : "Y$i"
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

    # 6. Global Score Ranking & Duplicate Point Clustering
    if !isempty(cand_sc_list)
        sort_perm    = sortperm(cand_sc_list; rev=true, alg=Base.Sort.MergeSort)
        cand_x_list  = cand_x_list[sort_perm]
        cand_y_list  = cand_y_list[sort_perm]
        cand_sc_list = cand_sc_list[sort_perm]
        cand_tags    = cand_tags[sort_perm]

        n_cands = length(cand_x_list)
        cluster_ids = zeros(Int, n_cands)
        next_cid = 1
        for i in 1:n_cands
            cluster_ids[i] != 0 && continue
            matches = [j for j in 1:n_cands if all(abs.(cand_x_list[i] .- cand_x_list[j]) .< 1e-4)]
            if length(matches) > 1
                for m_idx in matches
                    cluster_ids[m_idx] = next_cid
                end
                next_cid += 1
            end
        end

        digits_sup = Dict('0'=>'⁰', '1'=>'¹', '2'=>'²', '3'=>'³', '4'=>'⁴', '5'=>'⁵', '6'=>'⁶', '7'=>'⁷', '8'=>'⁸', '9'=>'⁹')
        for i in 1:n_cands
            if cluster_ids[i] > 0
                sup_str = join([get(digits_sup, d, d) for d in string(cluster_ids[i])])
                cand_tags[i] = cand_tags[i] * sup_str
            end
        end
    end

    final_XT = reduce(vcat, [reshape(v, 1, :) for v in cand_x_list])
    final_YP = reduce(vcat, [reshape(v, 1, :) for v in cand_y_list])
    final_SC = cand_sc_list

    ldf = VISE_PrepareLeadersDF_DDEF(final_XT, final_YP, final_SC, cand_tags, in_n, out_n, phase, C)

    # Stoichiometric Safety Audit
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

    # Boundary Warnings
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
    
    # Result columns first 
    for (i, n) in enumerate(out_n)
        col_res = Symbol(C.PRE_RESULT * n)
        df[!, col_res] = Vector{Union{Missing, Float64}}(missing, length(tags))
    end

    # Prediction columns second 
    for (i, n) in enumerate(out_n)
        col_pred = Symbol(C.PRE_PRED * n)
        df[!, col_pred] = round.(yp[:, i]; digits=3)
    end
    
    return df
end

function VISE_GeneratePredictions_DDEF(X, Y, models, goals;
    ModifiersDCYP::Vector{Main.Lib_Core.CORE_ModifierDCYP_DDES}=Main.Lib_Core.CORE_ModifierDCYP_DDES[])
    yp = hcat([VISE_Predict_DDEF(m, X) for m in models]...)
    pg = [Main.Lib_Core.CORE_ExtractGoal_DDEF(j <= length(goals) ? goals[j] : get(models[j], "Goal", Dict())) for j in eachindex(models)]
    bg = [(g[1], g[2], g[3], g[4], 1.0) for g in pg]
    
    k = length(models)
    inv_k = k > 0 ? (1.0 / k) : 1.0
    neighbour_weights = [Main.Lib_Core.CORE_GetNeighbourWeights_DDEF(g[5]) for g in pg]
    
    n_points = size(X, 1)
    sc = zeros(n_points)
    
    @inbounds for i in 1:n_points
        prod_u = 1.0
        prod_e = 1.0
        for j in eachindex(models)
            val = yp[i, j]
            if isnan(val) || isinf(val)
                prod_u = 0.0
                prod_e = 0.0
                break
            end

            b = Main.Lib_Core.CORE_CalcDesirability_DDEF(val, bg[j])
            if b <= 1e-12
                prod_u = 0.0
                prod_e = 0.0
                break
            end

            w_m, w_c, w_p = neighbour_weights[j]
            u = b^(w_c * inv_k)
            e = (b^(w_m * inv_k) + u + b^(w_p * inv_k)) / 3.0
            prod_u *= u
            prod_e *= e
        end
        score = clamp(0.50 * prod_u + 0.50 * prod_e, 0.0, 1.0)

        # Decay-Coupled Optimisation
        for dm in ModifiersDCYP
            if dm.TimeIndex >= 1 && dm.TimeIndex <= size(X, 2)
                score = Main.Lib_Core.CORE_ApplyDCYP_DDEF(score, dm, view(X, i, :))
            end
        end

        sc[i] = (isnan(score) || isinf(score)) ? 0.0 : clamp(score, 0.0, 1.0)
    end
    
    return yp, sc
end

function VISE_PreparePredictionsSheet_DDEF(df::DataFrame, phase::AbstractString, yp::AbstractMatrix, sc::AbstractVector, mask, out_n, C, Log)
    idx_m   = findall(mask)
    df_cols = string.(names(df))

    # 1. Update/Add Prediction Columns with flexible name matching and type widening
    for (m, n) in enumerate(out_n)
        n_clean = replace(strip(string(n)), " " => "_")
        match_idx = findfirst(c -> c == C.PRE_PRED * n_clean || startswith(c, C.PRE_PRED * n_clean * "_") || (startswith(c, C.PRE_PRED) && occursin(n_clean, c)), df_cols)
        target_sym = if !isnothing(match_idx)
            Symbol(df_cols[match_idx])
        else
            Symbol(C.PRE_PRED * n_clean)
        end

        VISE_WidenColumnFloat_DDEF!(df, target_sym)

        for (i, r_idx) in enumerate(idx_m)
            if i <= size(yp, 1) && m <= size(yp, 2)
                df[r_idx, target_sym] = round(Float64(yp[i, m]); digits=3)
            end
        end
    end

    # 2. Update/Add Desirability Score Column with type widening
    score_idx = findfirst(c -> uppercase(strip(c)) == uppercase(C.COL_SCORE), df_cols)
    target_score = if !isnothing(score_idx)
        Symbol(df_cols[score_idx])
    else
        Symbol(C.COL_SCORE)
    end

    VISE_WidenColumnFloat_DDEF!(df, target_score)

    for (i, r_idx) in enumerate(idx_m)
        if i <= length(sc)
            df[r_idx, target_score] = round(Float64(sc[i]); digits=4)
        end
    end

    return df
end


function VISE_AssembleBundle_DDEF(phase, in_n, out_n, disp_in, disp_out, models, bp, bs, ldf, xc, yc, opts, goals, yp, sc, radio, warns, vitals, anova, normality, residuals, sens, graphs, t0, C; X_Nominal=xc)
    ui_mods = deepcopy(models); for m in ui_mods delete!(m, "_Closure") end
    return Dict("Status"=>"OK", "Phase"=>phase, "InNames"=>in_n, "OutNames"=>out_n, "DisplayInNames"=>disp_in, "DisplayOutNames"=>disp_out, "Models"=>ui_mods, "Goals"=>goals, "R2_Adj"=>[get(m, "R2_Adj", 0.0) for m in models], "Q2"=>[get(m, "Q2", 0.0) for m in models], "BestPoint"=>bp, "BestScore"=>bs, "Leaders"=>ldf, "X_Clean"=>xc, "X_Nominal"=>X_Nominal, "Y_Clean"=>yc, "Graphs"=>graphs, "Vitals"=>vitals, "Sensitivities"=>sens, "ANOVA"=>anova, "Normality"=>normality, "Residuals"=>residuals, "RadioCorrection"=>radio, "BoundaryWarnings"=>warns, "Elapsed"=>"$(round(time()-t0; digits=1))s")
end

"""
    VISE_ExportToExcel_DDEF(Res::Dict, FilePath::AbstractString) -> Bool
Produces a high-fidelity academic Excel report with multiple analytical sheets.
"""
function VISE_ExportToExcel_DDEF(Res::AbstractDict, FilePath::AbstractString)
    Main.Sys_Fast.FAST_Log_DDEF("VISE", "EXPORT", "Generating High-Fidelity Scientific Portfolio: $FilePath", "WAIT")
    try
        XLSX.openxlsx(FilePath, mode="w") do xf
            # 1. Summary Sheet with Project Vitals
            sheet_ov       = xf[1]
            XLSX.rename!(sheet_ov, "Summary")
            sheet_ov["A1"] = "DoECISORY Scientific Analysis Summary"
            sheet_ov["A2"] = "Generated: $(Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))"
            sheet_ov["A3"] = "Experimental Phase: $(get(Res, "Phase", "Phase1"))"
            in_names  = get(Res, "InNames", get(Res, "DisplayInNames", []))
            out_names = get(Res, "OutNames", get(Res, "DisplayOutNames", []))
            n_runs    = haskey(Res, "X_Clean") ? (Res["X_Clean"] isa AbstractMatrix ? size(Res["X_Clean"], 1) : length(Res["X_Clean"])) : 0
            sheet_ov["A4"] = "Sample Size (N): $(n_runs) runs"
            sheet_ov["A5"] = "Factors (k): $(length(in_names))"
            sheet_ov["A6"] = "Responses (m): $(length(out_names))"

            if haskey(Res, "Vitals") && !isnothing(Res["Vitals"])
                v = Res["Vitals"]
                sheet_ov["A8"] = ["Design Vital Criterion", "Value", "Benchmark Reference", "Status"]
                d_v = Float64(get(v, "D", 0.0))
                a_v = Float64(get(v, "A", 0.0))
                g_v = Float64(get(v, "G", 0.0))
                i_v = Float64(get(v, "I", 0.0))
                c_v = get(v, "Condition", Inf)
                c_num = isinf(c_v) ? "Inf" : round(Float64(c_v); digits=2)
                v_num = round(Float64(get(v, "MaxVIF", 1.0)); digits=2)
                lof_v = get(v, "LOF", NaN)
                lof_str = (ismissing(lof_v) || isnan(lof_v)) ? "N/A" : round(Float64(lof_v); digits=4)

                sheet_ov["A9"]  = ["D-Efficiency", round(d_v * 100; digits=2), ">= 35.00% (RSM)", d_v >= 0.35 ? "Pass" : "Marginal"]
                sheet_ov["A10"] = ["A-Optimality", a_v > 0.0 ? round(a_v; digits=4) : "N/A", "tr((X'X)^-1) minim.", "Average parameter variance"]
                sheet_ov["A11"] = ["G-Optimality", g_v > 0.0 ? round(g_v; digits=4) : "N/A", "max SPV minim.", "Maximum prediction variance"]
                sheet_ov["A12"] = ["I-Optimality", i_v > 0.0 ? round(i_v; digits=4) : "N/A", "Integral(SPV dX) minim.", "Mean prediction variance"]
                sheet_ov["A13"] = ["Condition Number (kappa)", c_num, "< 100.00", (c_v < 100.0) ? "Well-conditioned" : "Collinear"]
                sheet_ov["A14"] = ["Maximum VIF", v_num, "<= 5.00", (v_num <= 5.0) ? "Low Collinearity" : "High Collinearity"]
                sheet_ov["A15"] = ["Lack-of-Fit (p-value)", lof_str, "p >= 0.0500", ((ismissing(lof_v) || isnan(lof_v)) ? "N/A" : (lof_v >= 0.05 ? "Adequate Fit" : "Significant Lack of Fit"))]
            end

            # 2. Model Statistics with Q² (LOOCV)
            sheet_mod       = XLSX.addsheet!(xf, "Model_Statistics")
            sheet_mod["A1"] = ["Response", "Model Type", "R2", "R2_Adj", "Q2", "RMSE", "P-Value", "Normality (p)"]

            X_Raw = Res["X_Clean"]
            Y_Raw = Res["Y_Clean"]
            
            X_Clean = VISE_PrepareMatrix_DDEF(X_Raw)
            Y_Clean = VISE_PrepareMatrix_DDEF(Y_Raw)
            
            row_idx = 2
            for (i, out_name) in enumerate(get(Res, "DisplayOutNames", get(Res, "OutNames", [])))
                m    = Res["Models"][i]
                norm = VISE_PerformNormalityTest_DDEF(m, X_Clean, Y_Clean[:, i])

                r2_v   = get(m, "R2", 0.0)
                r2a_v  = get(m, "R2_Adj", 0.0)
                q2_v   = get(m, "Q2", 0.0)
                rmse_v = get(m, "RMSE", 0.0)
                pv_v   = get(m, "P_Value", 1.0)
                norm_p = get(norm, "p", NaN)

                sheet_mod[row_idx, 1] = out_name
                sheet_mod[row_idx, 2] = get(m, "ModelType", "N/A")
                sheet_mod[row_idx, 3] = (ismissing(r2_v) || isnan(r2_v) || isinf(r2_v)) ? "N/A" : round(Float64(r2_v); digits=4)
                sheet_mod[row_idx, 4] = (ismissing(r2a_v) || isnan(r2a_v) || isinf(r2a_v)) ? "N/A" : round(Float64(r2a_v); digits=4)
                sheet_mod[row_idx, 5] = (ismissing(q2_v) || isnan(q2_v) || isinf(q2_v)) ? "N/A" : round(Float64(q2_v); digits=4)
                sheet_mod[row_idx, 6] = (ismissing(rmse_v) || isnan(rmse_v) || isinf(rmse_v)) ? "N/A" : round(Float64(rmse_v); digits=4)
                sheet_mod[row_idx, 7] = (ismissing(pv_v) || isnan(pv_v) || isinf(pv_v)) ? "N/A" : round(Float64(pv_v); digits=4)
                sheet_mod[row_idx, 8] = (ismissing(norm_p) || isnan(norm_p) || isinf(norm_p)) ? "N/A" : round(Float64(norm_p); digits=4)

                row_idx += 1
            end

            # 3. Individual ANOVA and Coefficients per response
            for (i, out_name) in enumerate(get(Res, "DisplayOutNames", get(Res, "OutNames", [])))
                m         = Res["Models"][i]
                safe_name = first(replace(out_name, r"[^\w]" => "_"), 25)

                # ANOVA Documentation
                ano_target = "ANOVA_$(safe_name)"
                if ano_target in XLSX.sheetnames(xf)
                    suffix     = "_$(i)"
                    avail_len  = max(0, 31 - 6 - length(suffix))
                    ano_target = "ANOVA_$(first(safe_name, avail_len))$(suffix)"
                end
                sh_ano   = XLSX.addsheet!(xf, ano_target)
                df_anova = VISE_GenerateAnovaTable_DDEF(m, X_Clean, Y_Clean[:, i])
                df_anova_clean = copy(df_anova)
                for col in names(df_anova_clean)
                    df_anova_clean[!, col] = [ismissing(v) || (v isa Number && (isnan(v) || isinf(v))) ? missing : v for v in df_anova_clean[!, col]]
                end
                XLSX.writetable!(sh_ano, df_anova_clean; anchor_cell=XLSX.CellRef("A1"))

                # Model Coefficients
                coef_target = "Coefs_$(safe_name)"
                if coef_target in XLSX.sheetnames(xf)
                    suffix      = "_$(i)"
                    avail_len   = max(0, 31 - 6 - length(suffix))
                    coef_target = "Coefs_$(first(safe_name, avail_len))$(suffix)"
                end
                sh_coef = XLSX.addsheet!(xf, coef_target)
                terms   = get(m, "TermNames", [])
                coefs   = get(m, "Coefs", [])
                p_vals  = get(m, "P_Coefs", [])
                vifs    = get(m, "VIFs", [])

                sh_coef["A1"] = ["Term", "Coefficient", "P-Value", "VIF", "Significance"]
                for j in eachindex(terms)
                    c_v  = coefs[j]
                    pv_v = (length(p_vals) >= j) ? p_vals[j] : NaN
                    vf_v = (j == 1) ? 1.0 : ((length(vifs) >= j) ? vifs[j] : NaN)
                    
                    c_out  = (ismissing(c_v) || isnan(c_v) || isinf(c_v)) ? "N/A" : round(Float64(c_v); digits=4)
                    pv_out = (ismissing(pv_v) || isnan(pv_v) || isinf(pv_v)) ? "N/A" : round(Float64(pv_v); digits=4)
                    vf_out = (ismissing(vf_v) || isnan(vf_v) || isinf(vf_v)) ? "N/A" : round(Float64(vf_v); digits=2)

                    term_clean = replace(replace(string(terms[j]), "×" => "*"), "²" => "^2")
                    sh_coef[j+1, 1] = term_clean
                    sh_coef[j+1, 2] = c_out
                    sh_coef[j+1, 3] = pv_out
                    sh_coef[j+1, 4] = vf_out
                    sh_coef[j+1, 5] = (!ismissing(pv_v) && !isnan(pv_v) && pv_v < 0.05) ? "*" : ""
                end
            end

            # 4. Leader Candidates Sheet
            if haskey(Res, "Leaders") && !isnothing(Res["Leaders"])
                ldf_raw = Res["Leaders"]
                ldf = if isa(ldf_raw, DataFrame)
                    ldf_raw
                elseif isa(ldf_raw, AbstractVector) && !isempty(ldf_raw)
                    DataFrame(ldf_raw)
                else
                    DataFrame()
                end
                if !isempty(ldf)
                    ldf_clean = copy(ldf)
                    for col in names(ldf_clean)
                        ldf_clean[!, col] = [ismissing(v) || (v isa Number && (isnan(v) || isinf(v))) ? missing : v for v in ldf_clean[!, col]]
                    end
                    sh_lead = XLSX.addsheet!(xf, "Leader_Candidates")
                    XLSX.writetable!(sh_lead, ldf_clean; anchor_cell=XLSX.CellRef("A1"))
                end
            end

            # 5. Optimisation Goals Sheet
            if haskey(Res, "Goals") && !isnothing(Res["Goals"])
                goals_list = Res["Goals"]
                if !isempty(goals_list)
                    sh_goals = XLSX.addsheet!(xf, "Optimisation_Goals")
                    sh_goals["A1"] = ["Parameter", "Criterion / Goal", "Target", "Lower Limit", "Upper Limit", "Weight", "Rating"]
                    for (g_idx, g) in enumerate(goals_list)
                        p_name = string(get(g, "Name", get(g, "Variable", "Parameter $g_idx")))
                        p_goal = string(get(g, "Type", get(g, "Goal", "Nominal")))
                        p_target = get(g, "Target", NaN)
                        p_target_val = (ismissing(p_target) || isnan(p_target)) ? "N/A" : round(Float64(p_target); digits=4)
                        p_low = get(g, "Low", get(g, "Min", NaN))
                        p_low_val = (ismissing(p_low) || isnan(p_low)) ? "N/A" : round(Float64(p_low); digits=4)
                        p_high = get(g, "High", get(g, "Max", NaN))
                        p_high_val = (ismissing(p_high) || isnan(p_high)) ? "N/A" : round(Float64(p_high); digits=4)
                        raw_w = Float64(get(g, "Weight", 1.0))
                        p_weight = round(raw_w; digits=2)
                        p_rating = VISE_GetWeightRating_DDEF(raw_w)

                        sh_goals[g_idx+1, 1] = p_name
                        sh_goals[g_idx+1, 2] = p_goal
                        sh_goals[g_idx+1, 3] = p_target_val
                        sh_goals[g_idx+1, 4] = p_low_val
                        sh_goals[g_idx+1, 5] = p_high_val
                        sh_goals[g_idx+1, 6] = p_weight
                        sh_goals[g_idx+1, 7] = p_rating
                    end
                end
            end

            # 6. Integrated radiation and isothermal decay correction registry
            if haskey(Res, "RadioCorrection")
                sh_rad       = XLSX.addsheet!(xf, "Radiation_Decay_Correction")
                sh_rad["A1"] = ["Component", "Type", "Half-Life", "Unit", "Avg Delta-T (min)", "Avg Decay Factor", "Correction Applied"]
                data         = Res["RadioCorrection"]
                for (r_idx, itm) in enumerate(data)
                    sh_rad[r_idx+1, 1] = get(itm, "Name", "")
                    sh_rad[r_idx+1, 2] = get(itm, "Type", "Decay")
                    sh_rad[r_idx+1, 3] = get(itm, "HalfLife", 0.0)
                    sh_rad[r_idx+1, 4] = get(itm, "Unit", "")
                    sh_rad[r_idx+1, 5] = round(get(itm, "AvgDeltaT", 0.0); digits=4)
                    sh_rad[r_idx+1, 6] = round(get(itm, "AvgDF", 0.0); digits=6)
                    sh_rad[r_idx+1, 7] = get(itm, "IsCorrected", false) ? "YES (Dynamic)" : "NO"
                end
            end
        end
        Main.Sys_Fast.FAST_ApplyExcelStyle_DDEF(FilePath)
        Main.Sys_Fast.FAST_Log_DDEF("VISE", "EXPORT", "Scientific Portfolio Generated with Publication Fidelity.", "OK")
        return true
    catch e
        Main.Sys_Fast.FAST_Log_DDEF("VISE", "EXPORT", "Excel export failed: $e", "FAIL")
        return false
    end
end

end
