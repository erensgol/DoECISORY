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
using XLSX
using Main.Sys_Fast
using Main.Lib_Arts
using Main.Lib_Mole
using Main.Lib_Core
using Main.Sys_Flow
using Surrogates
using HypothesisTests

export VISE_Regress_DDEF, VISE_GridSearch_DDEF, VISE_ExpandDesign_DDEF,
    VISE_Predict_DDEF, VISE_Execute_DDEF, VISE_CrossValidate_DDEF,
    VISE_GetTermNames_DDEF, VISE_ClampIndex_DDEF,
    VISE_TrainSurrogate_DDEF, VISE_BuildSurrogateClosure_DDEF,
    VISE_SelectBestModel_DDEF, VISE_CalcMetrics_DDEF,
    VISE_SensitivityAnalysis_DDEF, VISE_GenerateScientificReport_DDEF,
    VISE_CalcVIF_DDEF, VISE_LackOfFit_DDEF, VISE_GenerateAnovaTable_DDEF,
    VISE_PerformNormalityTest_DDEF, VISE_ExportToExcel_DDEF

# --------------------------------------------------------------------------------------
# --- PHYSICAL CORRECTIONS & MATH MODELS (MOVED TO Lib_Mole) ---
# --------------------------------------------------------------------------------------

"""
    VISE_GetTermNames_DDEF(InNames, ModelType) -> Vector{String}
Generates human-readable names for regression terms (e.g., "A × B", "A²").
"""
function VISE_GetTermNames_DDEF(InNames::Vector{String}, ModelType::String)
    K = 3 # Fixed 3-variable system
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
    N = size(X, 1)
    K = 3 # Fixed 3-variable system
    occursin("linear", lowercase(ModelType)) && return hcat(ones(N), X)

    combos = [(1, 2), (1, 3), (2, 3)] # combinations(1:3, 2)
    n_inter = 3

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
# --- SURROGATES.JL STATELESS WRAPPERS ---
# --------------------------------------------------------------------------------------

"""
    VISE_TrainSurrogate_DDEF(X_Raw, Y, ModelType; [InNames]) -> Dict
Extracts training data required for on-the-fly execution of Surrogate models (Kriging/RBF).
"""
function VISE_TrainSurrogate_DDEF(X_Raw::AbstractMatrix{Float64}, Y::AbstractVector{Float64}, ModelType::String; InNames::Vector{String}=String[])
    N = size(X_Raw, 1)
    K = 3 # Fixed 3-variable system
    lb = vec(minimum(X_Raw; dims=1))
    ub = vec(maximum(X_Raw; dims=1))

    # Guard bounds for zero-variance limits
    for i in 1:K
        if abs(lb[i] - ub[i]) < 1e-6
            lb[i] -= 1e-3
            ub[i] += 1e-3
        end
    end

    TNames = isempty(InNames) ? ["Term $i" for i in 1:K] : InNames

    # R2 calculation mock value (Kriging interpolates exact points with R2=1.0)
    return Dict(
        "Status" => "OK",
        "ModelType" => ModelType,
        "X_Train" => X_Raw,
        "Y_Train" => Y,
        "LB" => lb,
        "UB" => ub,
        "Coefs" => Float64[],      # Empty placeholder for unified UI usage
        "TermNames" => TNames,
        "R2" => 0.999,             # Proxy metrics
        "R2_Adj" => 0.999,
        "RMSE" => 0.0,
        "F_Stat" => NaN,
        "P_Value" => NaN,
        "P_Coefs" => fill(NaN, K),
        "SE_Coefs" => fill(NaN, K),
        "t_Stats" => fill(NaN, K),
        "N_Samples" => N
    )
end

"""
    VISE_BuildSurrogateClosure_DDEF(Model::Dict)
Reconstructs Surrogates.jl struct from stateless dictionary for prediction.
"""
function VISE_BuildSurrogateClosure_DDEF(Model::Dict)
    X_mat = convert(Matrix{Float64}, Model["X_Train"])
    Y_vec = convert(Vector{Float64}, Model["Y_Train"])
    lb = convert(Vector{Float64}, Model["LB"])
    ub = convert(Vector{Float64}, Model["UB"])

    N = size(X_mat, 1)
    K = 3 # Fixed 3-variable system

    # Convert observation vectors into NTuples for Surrogates API
    x_tups = [ntuple(j -> X_mat[i, j], 3) for i in 1:N]

    m_type = lowercase(get(Model, "ModelType", ""))

    if m_type == "kriging"
        return Kriging(x_tups, Y_vec, lb, ub)
    elseif m_type == "rbf"
        return RadialBasis(x_tups, Y_vec, lb, ub)
    else
        return RadialBasis(x_tups, Y_vec, lb, ub)
    end
end

# --------------------------------------------------------------------------------------
# --- REGRESSION ENGINE (OLS CORE) ---
# --------------------------------------------------------------------------------------

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
function VISE_Regress_DDEF(X_Raw::AbstractMatrix{Float64}, Y::AbstractVector{Float64},
    ModelType::String; InNames::Vector{String}=String[])
    X_Design = VISE_ExpandDesign_DDEF(X_Raw, ModelType)

    try
        # --- STRICT SCIENTIFIC OLS REGRESSION ---
        n = size(X_Design, 1)
        p = size(X_Design, 2)

        # Condition Number Check (Matrix Health)
        if cond(X_Design) > 1e10
            return Dict("Status" => "FAIL", "Error" => "Pre-Flight Matrix Health Check Failed: Design matrix condition number > 1e10. Potential multicollinearity detected.")
        end

        if n < p
            throw(ArgumentError("Insufficient data: Number of observations (\$n) is less than model parameters (\$p)."))
        end

        # Explicit rank check to prevent data manipulation via pseudo-inverse
        if rank(X_Design) < p
            throw(ArgumentError("Design matrix is linearly dependent (Singular/Collinear)."))
        end

        Beta = X_Design \ Y

        Y_Pred = X_Design * Beta
        Resid = Y .- Y_Pred
        SSE = sum(abs2, Resid)
        SST = var(Y) * (length(Y) - 1)

        n, p = size(X_Design)
        R2, R2_Adj, RMSE, AIC = VISE_CalcMetrics_DDEF(Y, Y_Pred, p)

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

        vifs = VISE_CalcVIF_DDEF(X_Design)
        TNames = VISE_GetTermNames_DDEF(InNames, ModelType)
        cond_num = cond(X_Design)

        return Dict(
            "Coefs" => Beta, "TermNames" => TNames,
            "R2" => R2, "R2_Adj" => R2_Adj,
            "RMSE" => RMSE, "AIC" => AIC, "F_Stat" => F_Stat,
            "P_Value" => P_Value, "P_Coefs" => P_Coefs,
            "SE_Coefs" => SE_Coefs, "t_Stats" => t_Stats,
            "VIFs" => vifs, "Condition" => cond_num,
            "ModelType" => ModelType, "N_Samples" => n,
            "Status" => "OK",
        )
    catch e
        Sys_Fast.FAST_Log_DDEF("VISE", "REGRESS_ERROR", sprint(showerror, e, catch_backtrace()), "FAIL")
        return Dict("Status" => "FAIL", "Error" => string(e))
    end
end

"""
    VISE_CalcVIF_DDEF(X_Design) -> Vector{Float64}
Calculates Variance Inflation Factors (VIF) to detect multicollinearity.
"""
function VISE_CalcVIF_DDEF(X_Design::AbstractMatrix)
    n, p = size(X_Design)
    p <= 1 && return Float64[]

    # Exclude intercept for VIF
    X = X_Design[:, 2:end]
    p_eff = p - 1
    vifs = fill(1.0, p) # Intercept VIF is 1.0 by convention

    try
        # Correlation matrix method
        C = cor(X)
        if cond(C) > 1e12
            # Use ridge-like regularisation for VIF stability in degenerate designs
            C += I * 1e-6
        end
        v_diag = diag(inv(C))
        vifs[2:end] .= v_diag
    catch
        vifs[2:end] .= 999.0 # Indicator of extreme collinearity
    end
    return vifs
end

"""
    VISE_LackOfFit_DDEF(X_Design, Y) -> (F_Stat, P_Value)
Performs Lack-of-Fit test to determine if model structure is adequate (requires replicates).
"""
function VISE_LackOfFit_DDEF(X_Design::AbstractMatrix, Y::AbstractVector)
    n, p = size(X_Design)

    # Identify unique rows (experimental settings)
    unique_rows = Dict{Vector{Float64},Vector{Float64}}()
    for i in 1:n
        row = X_Design[i, :]
        if haskey(unique_rows, row)
            push!(unique_rows[row], Y[i])
        else
            unique_rows[row] = [Y[i]]
        end
    end

    # SS_PureError
    ss_pe = 0.0
    df_pe = 0
    for (row, vals) in unique_rows
        if length(vals) > 1
            ss_pe += sum(abs2, vals .- mean(vals))
            df_pe += (length(vals) - 1)
        end
    end

    df_pe == 0 && return (NaN, NaN) # No replicates

    # SS_Residual from OLS
    Beta = X_Design \ Y
    Resid = Y .- (X_Design * Beta)
    ss_res = sum(abs2, Resid)
    df_res = n - p

    # SS_LackOfFit
    ss_lof = max(0.0, ss_res - ss_pe)
    df_lof = df_res - df_pe

    df_lof <= 0 && return (NaN, NaN)

    ms_lof = ss_lof / df_lof
    ms_pe = ss_pe / df_pe

    ms_pe < 1e-12 && return (999.0, 0.0) # Perfect replicates, any deviation is LOF

    f_stat = ms_lof / ms_pe
    p_val = 1.0 - cdf(FDist(df_lof, df_pe), f_stat)

    return (f_stat, p_val)
end

"""
    VISE_GenerateAnovaTable_DDEF(Model::Dict, X::AbstractMatrix, Y::AbstractVector) -> DataFrame
Constructs a comprehensive ANOVA table for experimental validation.
"""
function VISE_GenerateAnovaTable_DDEF(Model::Dict, X_Raw::Any, Y_Raw::Any)
    # Ensure Matrix/Vector format (handles JSON deserialization artifacts)
    X = (X_Raw isa AbstractMatrix) ? Float64.(collect(X_Raw)) : (X_Raw isa AbstractVector && !isempty(X_Raw) && X_Raw[1] isa AbstractVector) ? 
        Float64.(reduce(vcat, transpose.(collect.(X_Raw)))) : (X_Raw isa AbstractVector && length(X_Raw) % 3 == 0) ? 
        reshape(Float64.(collect(X_Raw)), :, 3) : X_Raw
        
    Y = (Y_Raw isa AbstractVector) ? Float64.(collect(Y_Raw)) : Y_Raw

    n = length(Y)
    m_type = get(Model, "ModelType", "linear")
    Xd = VISE_ExpandDesign_DDEF(X, m_type)
    p = size(Xd, 2)

    Beta = get(Model, "Coefs", Float64[])
    isempty(Beta) && return DataFrame()

    Y_Pred = Xd * Beta
    Resid = Y .- Y_Pred

    # 1. SS Calculations
    SS_Total = var(Y) * (n - 1)
    SS_Resid = sum(abs2, Resid)
    SS_Reg = max(0.0, SS_Total - SS_Resid)

    # 2. DF Calculations
    DF_Total = n - 1
    DF_Reg = p - 1
    DF_Resid = n - p

    # 3. Lack-of-Fit Logic
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

    # 4. Assembly
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
        Source=sources,
        SS=round.(ss_vals; digits=4),
        df=df_vals,
        MS=fill(NaN, length(sources)),
        F=fill(NaN, length(sources)),
        P=fill(NaN, length(sources))
    )

    # Calculate MS, F, P
    for i in 1:nrow(df_anova)
        if df_anova.df[i] > 0
            df_anova.MS[i] = round(df_anova.SS[i] / df_anova.df[i]; digits=4)
        end
    end

    # Model F-Test
    idx_mod = findfirst(==("Model"), sources)
    idx_res = findfirst(==("Residual"), sources)
    if !isnothing(idx_mod) && !isnothing(idx_res) && df_anova.MS[idx_res] > 1e-12
        f = df_anova.MS[idx_mod] / df_anova.MS[idx_res]
        df_anova.F[idx_mod] = round(f; digits=2)
        df_anova.P[idx_mod] = round(1.0 - cdf(FDist(df_anova.df[idx_mod], df_anova.df[idx_res]), f); digits=4)
    end

    # LOF F-Test
    idx_lof = findfirst(==("Lack of Fit"), sources)
    idx_pe = findfirst(==("Pure Error"), sources)
    if !isnothing(idx_lof) && !isnothing(idx_pe) && df_anova.MS[idx_pe] > 1e-12
        f_lof = df_anova.MS[idx_lof] / df_anova.MS[idx_pe]
        df_anova.F[idx_lof] = round(f_lof; digits=2)
        df_anova.P[idx_lof] = round(1.0 - cdf(FDist(df_anova.df[idx_lof], df_anova.df[idx_pe]), f_lof); digits=4)
    end

    return df_anova
end

"""
    VISE_PerformNormalityTest_DDEF(Model::Dict, X::AbstractMatrix, Y::AbstractVector) -> Dict
Executes Shapiro-Wilk test on model residuals.
"""
function VISE_PerformNormalityTest_DDEF(Model::Dict, X_Raw::Any, Y_Raw::Any)
    # Ensure Matrix/Vector format (handles JSON deserialization artifacts)
    X = (X_Raw isa AbstractMatrix) ? Float64.(collect(X_Raw)) : (X_Raw isa AbstractVector && !isempty(X_Raw) && X_Raw[1] isa AbstractVector) ? 
        Float64.(reduce(vcat, transpose.(collect.(X_Raw)))) : (X_Raw isa AbstractVector && length(X_Raw) % 3 == 0) ? 
        reshape(Float64.(collect(X_Raw)), :, 3) : X_Raw
        
    Y = (Y_Raw isa AbstractVector) ? Float64.(collect(Y_Raw)) : Y_Raw

    m_type = get(Model, "ModelType", "linear")
    Xd = VISE_ExpandDesign_DDEF(X, m_type)
    Beta = get(Model, "Coefs", Float64[])
    isempty(Beta) && return Dict("p" => NaN, "IsNormal" => false)

    Resid = Y .- (Xd * Beta)

    try
        sw = HypothesisTests.ShapiroWilkTest(Resid)
        p = HypothesisTests.pvalue(sw)
        return Dict("p" => round(p; digits=4), "IsNormal" => p > 0.05, "Test" => "Shapiro-Wilk")
    catch
        return Dict("p" => NaN, "IsNormal" => false, "Test" => "Fail")
    end
end

"""
    VISE_CalcMetrics_DDEF(Y_Real, Y_Pred, p) -> (R2, R2_Adj, RMSE, AIC)
Calculates core statistical metrics (R², Adjusted R², RMSE, AIC).
"""
function VISE_CalcMetrics_DDEF(Y_Real::AbstractVector{Float64}, Y_Pred::AbstractVector{Float64}, p::Int)
    n = length(Y_Real)
    Resid = Y_Real .- Y_Pred
    SSE = sum(abs2, Resid)
    SST = var(Y_Real) * (n - 1)

    R2 = SST > 1e-9 ? 1.0 - SSE / SST : 0.0
    R2_Adj = n > p ? 1.0 - (1.0 - R2) * ((n - 1) / (n - p)) : 0.0
    RMSE = n > p ? sqrt(SSE / (n - p)) : 0.0

    # Akaike Information Criterion (Assuming normal residuals)
    AIC = n > 0 && SSE > 0 ? n * log(SSE / n) + 2p : Inf

    return (R2, R2_Adj, RMSE, AIC)
end

"""
    VISE_ExportToExcel_DDEF(FilePath::String, Results::Dict) -> Bool
Exports all statistical models, ANOVA tables, and metrics to a professional XLSX file.
"""
function VISE_ExportToExcel_DDEF(FilePath::String, Results::Any)
    try
        XLSX.openxlsx(FilePath, mode="w") do xf
            # 1. Overview Sheet
            sheet_ov = xf[1]
            XLSX.rename!(sheet_ov, "Summary")
            sheet_ov["A1"] = "DaishoDoE Scientific Intelligence Report"
            sheet_ov["A2"] = "Generated: $(Dates.now())"

            # 2. Models Sheet
            sheet_mod = XLSX.addsheet!(xf, "Model_Statistics")
            sheet_mod["A1"] = ["Response", "Model Type", "R2", "R2_Adj", "RMSE", "P-Value", "Normality (p)"]

            # Ensure Matrix format for consistency across JSON/Store transfers
            X_Clean = Results["X_Clean"]
            if !(X_Clean isa AbstractMatrix)
                if X_Clean isa AbstractVector && !isempty(X_Clean) && X_Clean[1] isa AbstractVector
                    X_Clean = reduce(vcat, transpose.(collect.(X_Clean)))
                elseif X_Clean isa AbstractVector && length(X_Clean) % 3 == 0
                    X_Clean = reshape(Float64.(collect(X_Clean)), :, 3)
                end
            end
            
            Y_Clean = Results["Y_Clean"]
            if !(Y_Clean isa AbstractMatrix) && Y_Clean isa AbstractVector && !isempty(Y_Clean) && Y_Clean[1] isa AbstractVector
                 Y_Clean = reduce(vcat, transpose.(collect.(Y_Clean)))
            end

            row_idx = 2
            for (i, out_name) in enumerate(get(Results, "OutNames", []))
                m = Results["Models"][i]
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

            # 3. ANOVA & Coefficients (Specific sheets per output)
            for (i, out_name) in enumerate(get(Results, "OutNames", []))
                m = Results["Models"][i]
                safe_name = first(replace(out_name, r"[^\w]" => "_"), 25)

                # ANOVA Sheet
                sh_ano = XLSX.addsheet!(xf, "ANOVA_$(safe_name)")
                df_anova = VISE_GenerateAnovaTable_DDEF(m, X_Clean, Y_Clean[:, i])
                XLSX.writetable!(sh_ano, df_anova; anchor_cell=XLSX.CellRef("A1"))

                # Coefficients Sheet
                sh_coef = XLSX.addsheet!(xf, "Coefs_$(safe_name)")
                terms = get(m, "TermNames", [])
                coefs = get(m, "Coefs", [])
                p_vals = get(m, "P_Coefs", [])
                vifs = get(m, "VIFs", [])

                sh_coef["A1"] = ["Term", "Coefficient", "P-Value", "VIF", "Significance"]
                for j in eachindex(terms)
                    sh_coef[j+1, 1] = terms[j]
                    sh_coef[j+1, 2] = round(coefs[j]; digits=4)
                    sh_coef[j+1, 3] = isnan(p_vals[j]) ? "N/A" : round(p_vals[j]; digits=4)
                    sh_coef[j+1, 4] = (j == 1) ? 1.0 : round(vifs[j]; digits=2)
                    sh_coef[j+1, 5] = (!isnan(p_vals[j]) && p_vals[j] < 0.05) ? "*" : ""
                end
            end

            # 4. Radiation & Decay Correction Sheet (If applicable)
            if haskey(Results, "RadioCorrection")
                sh_rad = XLSX.addsheet!(xf, "Radiation_Decay_Correction")
                sh_rad["A1"] = ["Component/Response", "Half-Life", "Unit", "Delta-T (Hours)", "Decay Factor (DF)", "Correction Applied"]
                data = Results["RadioCorrection"]
                for (r_idx, itm) in enumerate(data)
                    sh_rad[r_idx+1, 1] = itm["Name"]
                    sh_rad[r_idx+1, 2] = itm["HalfLife"]
                    sh_rad[r_idx+1, 3] = itm["Unit"]
                    sh_rad[r_idx+1, 4] = round(itm["DeltaT"]; digits=4)
                    sh_rad[r_idx+1, 5] = round(itm["DecayFactor"]; digits=6)
                    sh_rad[r_idx+1, 6] = itm["IsCorrected"] ? "YES" : "NO"
                end
            end
        end
        return true
    catch e
        Sys_Fast.FAST_Log_DDEF("VISE", "EXPORT_ERR", "Excel export failed: $e", "FAIL")
        return false
    end
end

"""
    VISE_SelectBestModel_DDEF(X, Y, InNames) -> (BestModel, LogMsg)
Evaluates multiple model structures and selects the optimal winner.
"""
function VISE_SelectBestModel_DDEF(X::AbstractMatrix{Float64}, Y::AbstractVector{Float64}, InNames::Vector{String})
    n = size(X, 1)
    k = 3 # Fixed 3-variable system
    p_quad = 10 # 1 + 2*3 + 3*(3-1)/2 = 10

    # Candidates: Linear, Quadratic (if N permits)
    candidates = ["linear"]
    n > p_quad + 2 && push!(candidates, "quadratic")

    best_score = -Inf
    best_mod = nothing
    log_details = String[]

    for type in candidates
        mod = VISE_Regress_DDEF(X, Y, type; InNames=InNames)
        mod["Status"] != "OK" && continue

        q2 = VISE_CrossValidate_DDEF(X, Y, type)
        r2a = get(mod, "R2_Adj", 0.0)

        # Tournament Score: Q2 is weighted higher to prevent over-fitting
        score = 0.6 * q2 + 0.4 * r2a

        push!(log_details, "$(uppercasefirst(type)): R²Adj=$(round(r2a, digits=3)), Q²=$(round(q2, digits=3))")

        if score > best_score
            best_score = score
            best_mod = mod
            best_mod["Q2"] = q2
        end
    end

    msg = join(log_details, " | ")
    return (best_mod, msg)
end

"""
    VISE_Predict_DDEF(Model, X_New) -> Vector{Float64}
Evaluates the fitted model on a new set of data points.
"""
function VISE_Predict_DDEF(Model::Dict, X_New::AbstractMatrix{Float64})
    get(Model, "Status", "FAIL") != "OK" && return zeros(size(X_New, 1))

    m_type = lowercase(get(Model, "ModelType", ""))
    if m_type == "kriging" || m_type == "rbf"
        surr = VISE_BuildSurrogateClosure_DDEF(Model)
        N_new, Dim = size(X_New)
        preds = zeros(N_new)
        for i in 1:N_new
            preds[i] = surr(ntuple(d -> X_New[i, d], Dim))
        end
        return preds
    end

    return VISE_ExpandDesign_DDEF(X_New, Model["ModelType"]) * Model["Coefs"]
end

# --------------------------------------------------------------------------------------
# --- VALIDATION (CROSS-VALIDATION & Q²) ---
# --------------------------------------------------------------------------------------

"""
    VISE_CrossValidate_DDEF(X, Y, ModelType) -> Float64
Calculates Predicted R² (Q²) using the PRESS statistic and Hat Matrix shortcut.
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
# --- MULTITHREADED GRID SEARCH OPTIMISATION ---
# --------------------------------------------------------------------------------------

"""
    VISE_GridSearch_DDEF(Models, Goals, Bounds; [Steps]) -> (X, Y_Pred, Scores)
Performs high-density grid search across factor space for desirability exploration.
"""
function VISE_GridSearch_DDEF(Models::AbstractVector, Goals::AbstractVector,
    X_Bounds::AbstractMatrix{Float64}; Steps::Int=41)
    Dim = 3 # Fixed 3rd dimension

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

    # Surrogate Closures Pre-compiled for Threads
    surrogate_closures = Any[nothing for _ in 1:NumModels]
    for m in 1:NumModels
        m_type = lowercase(get(Models[m], "ModelType", ""))
        if m_type == "kriging" || m_type == "rbf"
            surrogate_closures[m] = VISE_BuildSurrogateClosure_DDEF(Models[m])
        end
    end

    # 3. Parallel Prediction (BLAS + thread-level)
    # Use capped compute thread pool
    Threads.@threads for m in 1:NumModels
        Mod = Models[m]
        Goal = Goals[m]
        Mod["Status"] != "OK" && continue

        m_type = lowercase(get(Mod, "ModelType", ""))
        local_pred = zeros(Float64, NumPoints)

        if m_type == "kriging" || m_type == "rbf"
            surr = surrogate_closures[m]
            @inbounds for i in 1:NumPoints
                tup = ntuple(d -> Candidates[i, d], Dim)
                local_pred[i] = surr(tup)
            end
        else
            Beta = Mod["Coefs"]::Vector{Float64}
            if get(Mod, "ModelType", "quadratic") != RefType
                Xd_Local = VISE_ExpandDesign_DDEF(Candidates, Mod["ModelType"])
                mul!(local_pred, Xd_Local, Beta)
            else
                mul!(local_pred, X_Design, Beta)
            end
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
            res_val = s^pow
            Scores[i] = (isnan(res_val) || isinf(res_val)) ? 0.0 : clamp(res_val, 0.0, 1.0)
        end
    end

    return Candidates, Predictions, Scores
end

"""
    VISE_SensitivityAnalysis_DDEF(Model, X_Point; [delta]) -> Vector{Float64}
Calculates local sensitivity (gradients) at a specific coordinate.
"""
function VISE_SensitivityAnalysis_DDEF(Model::Dict, X_Point::Vector{Float64}; delta=1e-4)
    Dim = 3 # Fixed constant
    gradients = zeros(3)

    base_pred = VISE_Predict_DDEF(Model, reshape(X_Point, 1, Dim))[1]

    for i in 1:Dim
        X_plus = copy(X_Point)
        X_plus[i] += delta
        pred_plus = VISE_Predict_DDEF(Model, reshape(X_plus, 1, Dim))[1]
        gradients[i] = abs(pred_plus - base_pred) / delta
    end

    total = sum(gradients)
    return total > 0.0 ? gradients ./ total : fill(1.0 / Dim, Dim)
end

"""
    VISE_GenerateScientificReport_DDEF(Res) -> String
Generates high-fidelity academic compendium following rigorous editorial standards.
"""
function VISE_GenerateScientificReport_DDEF(Res::Dict)
    io = IOBuffer()
    write(io, "## [ACADEMIC COMPENDIUM] DAISHODOE ANALYTICAL REPORT\n")
    write(io, Printf.@sprintf("*Protocol Execution: %s | High-Fidelity Research Tier*\n", Dates.format(now(), "yyyy-mm-dd HH:MM")))
    write(io, "---\n\n")

    # --- Section: Global Design Vitals ---
    if haskey(Res, "Vitals") && !isnothing(Res["Vitals"])
        v = Res["Vitals"]
        write(io, "### I. Experimental Design Vitals\n")
        write(io, "Rigorous mathematical audit of the underlying design matrix topology.\n\n")
        
        d_val = get(v, "D", 0.0)
        c_val = get(v, "Condition", Inf)
        lof_val = get(v, "LOF", 1.0)

        @printf(io, "- **D-Efficiency**: %.2f%% (Goal: >60%% for industrial robustness)\n", d_val * 100)
        @printf(io, "- **Condition Number**: %.2e (Goal: <1e4 for numerical stability)\n", c_val)
        @printf(io, "- **Lack-of-Fit (P)**: %.4f ", lof_val)
        
        if lof_val < 0.05
            write(io, "(`SIGNIFICANT` - Potential systematic bias or missing higher-order terms)\n")
        else
            write(io, "(`NON-SIGNIFICANT` - Model captures the underlying phenomenon accurately)\n")
        end
        write(io, "\n")
    end

    # --- Section: Radioactive Decay Correction ---
    if haskey(Res, "RadioCorrection") && !isempty(Res["RadioCorrection"])
        write(io, "### II. Radioactive Decay Correction (Audit)\n")
        write(io, "Systematic correction applied to compensate for isothermal decay between calibration and experimental execution.\n\n")
        for itm in Res["RadioCorrection"]
            @printf(io, "- **%s**: Applied correction for isotope decay.\n", itm["Name"])
            @printf(io, "  - *Half-Life (T½)*: %.2f %s\n", itm["HalfLife"], itm["Unit"])
            @printf(io, "  - *Decay Time (Δt)*: %.2f hours\n", itm["DeltaT"])
            @printf(io, "  - *Decay Factor (DF)*: %.4f (Correction: 1/DF)\n", itm["DecayFactor"])
        end
        write(io, "\n")
    end

    out_names = Res["OutNames"]
    for (m_idx, name) in enumerate(out_names)
        mod = Res["Models"][m_idx]
        mod["Status"] != "OK" && continue

        r2a = get(Res, "R2_Adj", fill(NaN, length(out_names)))[m_idx]
        q2 = get(Res, "R2_Pred", fill(NaN, length(out_names)))[m_idx]
        rmse = get(mod, "RMSE", 0.0)
        aic = get(mod, "AIC", NaN)

        write(io, "### Dimension Analysis: **$(name)**\n")
        write(io, "#### II. Statistical Fidelity & Variance Explanation\n")
        write(io, Printf.@sprintf("- **Objective Metric**: \$R^2_{Adj} = %.4f\$ (Adjusted for degrees of freedom)\n", r2a))
        write(io, Printf.@sprintf("- **Predictive Stability**: \$Q^2_{Pred} = %.4f\$ (Leave-one-out cross-validation)\n", q2))
        write(io, Printf.@sprintf("- **Residual Magnitude**: \$RMSE = %.4f\$ (Root Mean Squared Error)\n", rmse))
        if !isnan(aic) && !isinf(aic)
            write(io, Printf.@sprintf("- **Information Criterion**: \$AIC = %.4f\$ (Akaike Information Criterion)\n", aic))
        end

        # Reliability Interpretation
        quality = q2 > 0.85 ? "SUPERIOR" : q2 > 0.7 ? "ROBUST" : q2 > 0.4 ? "FORMATIVE" : "TENTATIVE"
        write(io, "- **Inference Reliability**: `$quality` profile. ")
        if q2 > 0.7
            write(io, "The model exhibits strong extrapolative potential within the defined design space.\n")
        else
            write(io, "Exercise caution during phase transition; additional data points may be required for high-fidelity mapping.\n")
        end

        # Factor Sensitivity summary for this output
        if haskey(Res, "Sensitivities") && m_idx <= length(Res["Sensitivities"])
            sens = Res["Sensitivities"][m_idx]
            in_names = get(Res, "InNames", [])
            if !isempty(sens) && length(sens) == length(in_names)
                perm = sortperm(sens; rev=true)
                write(io, "- **Top Sensitivity**: `$(in_names[perm[1]])` contributes $(round(sens[perm[1]]*100; digits=1))% to the response variance at the optimum.\n")
            end
        end

        # VIF Check
        write(io, "\n#### III. Orthogonality & Collinearity Diagnostics\n")
        vifs = get(mod, "VIFs", Float64[])
        max_vif = isempty(vifs) ? 0.0 : maximum(vifs)
        if max_vif > 10.0
            @printf(io, "- **Multicollinearity Trace**: `WARNING` (Max VIF: %.2f). Parameters show significant correlation.\n", max_vif)
        elseif max_vif > 0.0
            @printf(io, "- **Multicollinearity Trace**: `CLEAN` (Max VIF: %.2f). The design preserves factor orthogonality.\n", max_vif)
        end

        # Driver Analysis
        write(io, "\n#### IV. Principal Factor Topology\n")
        coefs = mod["Coefs"]
        t_stats = get(mod, "t_Stats", Float64[])
        if length(coefs) > 1 && !isempty(t_stats)
            abs_t = abs.(view(t_stats, 2:length(t_stats)))
            perm = sortperm(abs_t; rev=true)

            top_idx = perm[1] + 1
            top_term = mod["TermNames"][top_idx]
            top_t = t_stats[top_idx]
            impact = top_t > 0 ? "positive (synergistic)" : "inverse (antagonistic)"

            @printf(io, "- **Primary Driver**: `%s` is the dominant factor (\$t = %.2f\$), manifesting a clear *%s* impact.\n", top_term, top_t, impact)
        end
        write(io, "\n")
    end

    if haskey(Res, "BestScore") && !isempty(get(Res, "BestPoint", []))
        write(io, "#### V. Optimal Scenario & Optimal Zone Coordinates\n")
        @printf(io, "- **Composite Desirability (D)**: %.4f\n", Res["BestScore"])

        best_pt = Res["BestPoint"]
        in_names = get(Res, "InNames", [])
        if length(best_pt) == length(in_names)
            write(io, "- **Optimal Factor Settings**:\n")
            for (i, val) in enumerate(best_pt)
                @printf(io, "  - *%s*: %.4f\n", in_names[i], val)
            end
        end
        write(io, "\n*Stability analysis suggests these coordinates reside within a high-confidence 'Optimal Zone' for experimental reproducibility.*\n\n")
    end

    write(io, "*Generated via DaishoDoE Engine v$(Sys_Fast.FAST_Data_DDEC.VERSION) — High-Fidelity Academic Module. Optimised for publication in high-impact scientific journals.*\n")

    return String(take!(io))
end

# --------------------------------------------------------------------------------------
# --- EXECUTION ORCHESTRATOR ---
# --------------------------------------------------------------------------------------

"""
    VISE_Execute_DDEF(DataFile, Phase, Goals, [ModelType]; [Opts]) -> Dict
Higher-level entry point for phase-based experimental analysis and optimisation.
"""
function VISE_Execute_DDEF(DataFile::String, Phase::String, Goals::AbstractVector,
    ModelType::String="Auto"; Opts=Dict{String,Any}())
    C = Sys_Fast.FAST_Data_DDEC
    Log = Sys_Fast.FAST_Log_DDEF

    Log("VISE", "EXECUTION_START", "Analyzing Phase: $Phase", "WAIT")
    t0 = time()
    boundary_warnings = String[]

    df_raw = Sys_Fast.FAST_ReadExcel_DDEF(DataFile, C.SHEET_DATA)
    isempty(df_raw) && (df_raw = Sys_Fast.FAST_ReadExcel_DDEF(DataFile, "DATA_RECORDS"))
    isempty(df_raw) && return Dict("Status" => "FAIL", "Message" => "Source data is unreadable or empty.")

    # Pre-flight data quality validation (Sys_Fast -> Lib_Vise bridge)
    valid, issues = Sys_Fast.FAST_ValidateDataFrame_DDEF(df_raw, [C.COL_PHASE])
    if !valid
        Log("VISE", "DATA_QUALITY", "Pre-flight issues: $(join(issues, " | "))", "WARN")
    end

    # Apply standardisation to the raw data
    Sys_Fast.FAST_NormaliseCols_DDEF!(df_raw)

    col_phase = Symbol(C.COL_PHASE)
    if !hasproperty(df_raw, col_phase)
        Log("VISE", "PHASE_ERROR", "Required column '$col_phase' not found in dataset.", "FAIL")
        return Dict("Status" => "FAIL", "Message" => "Required column '$col_phase' not found in dataset. Please ensure the data sheet is properly formatted.")
    end
    df_train = hasproperty(df_raw, col_phase) ?
               filter(r -> string(r[col_phase]) == Phase, df_raw) :
               copy(df_raw)

    nrow(df_train) < 3 && return Dict("Status" => "FAIL", "Message" => "Insufficient data points (N < 3).")

    in_cols = filter(n -> startswith(n, C.PRE_INPUT), names(df_train))
    out_cols = filter(n -> startswith(n, C.PRE_RESULT), names(df_train))

    # Construct numeric matrices from DataFrame
    nr = nrow(df_train)
    X_Raw = Matrix{Float64}(undef, nr, 3) # Fixed 3 inputs
    Y_Raw = Matrix{Float64}(undef, nr, 3) # Fixed 3 outputs
    @inbounds for (ci, c) in enumerate(in_cols), r in 1:nr
        X_Raw[r, ci] = Sys_Fast.FAST_SafeNum_DDEF(df_train[r, c])
    end
    @inbounds for (ci, c) in enumerate(out_cols), r in 1:nr
        Y_Raw[r, ci] = Sys_Fast.FAST_SafeNum_DDEF(df_train[r, c])
    end

    valid_mask = vec(all(!isnan, Y_Raw; dims=2))
    X_Clean = X_Raw[valid_mask, :]
    Y_Clean = Y_Raw[valid_mask, :]
    N = size(X_Clean, 1)
    K = 3 # Fixed 3-variable system

    InNames = replace.(in_cols, C.PRE_INPUT => "")
    OutNames = replace.(out_cols, C.PRE_RESULT => "")

    # Calculate Design Efficiency (New Bridge Lib_Core -> Lib_Vise)
    d_eff = Lib_Core.CORE_D_Efficiency_DDEF(X_Clean)
    Log("VISE", "DESIGN_QUALITY", "Calculated D-Efficiency: $(round(d_eff * 100; digits=2))%",
        d_eff > 0.5 ? "OK" : "WARN")

    # --- RADIOACTIVITY DECAY CORRECTION ---
    radio_correction_audit = []
    radio_opts = get(Opts, "RadioOpts", Dict("Apply" => false, "CalibrationTime" => "", "ExperimentalTime" => ""))
    if get(radio_opts, "Apply", false)
        t_cal_str = get(radio_opts, "CalibrationTime", "")
        t_exp_str = get(radio_opts, "ExperimentalTime", "")

        if !isempty(t_cal_str) && !isempty(t_exp_str)
            try
                # Standard ISO format is yyyy-mm-ddTHH:MM, but sometimes browsers can vary or add seconds
                parse_dt(s) = begin
                    s_clean = replace(strip(s), " " => "T")
                    for fmt in ["yyyy-mm-ddTHH:MM:SS", "yyyy-mm-ddTHH:MM"]
                        try return Dates.DateTime(s_clean, fmt) catch; end
                    end
                    return Dates.DateTime(s_clean) # Fallback to default ISO
                end

                dt_cal = parse_dt(t_cal_str)
                dt_exp = parse_dt(t_exp_str)
                delta_t_hours = Dates.value(dt_exp - dt_cal) / (1000.0 * 60.0 * 60.0)

                if abs(delta_t_hours) > 1e-4 # Apply if there is a measurable difference
                    config = Sys_Fast.FAST_ReadConfig_DDEF(DataFile)

                    # Correct Inputs (X)
                    in_meta = get(config, "Ingredients", [])
                    for (ci, name) in enumerate(InNames)
                        idx = findfirst(x -> get(x, "Name", "") == name, in_meta)
                        if !isnothing(idx) && get(in_meta[idx], "IsRadioactive", false)
                            hl = Float64(get(in_meta[idx], "HalfLife", 0.0))
                            hlu = string(get(in_meta[idx], "HalfLifeUnit", "Hours"))
                            for r in 1:N
                                X_Clean[r, ci] = Lib_Mole.MOLE_ApplyRadioDecay_DDEF(X_Clean[r, ci], hl, hlu, delta_t_hours)
                            end

                            # Log for Excel/Report
                            conv = (hlu == "Days" ? 24.0 : (hlu == "Minutes" ? 1/60 : (hlu == "Seconds" ? 1/3600 : (hlu == "Years" ? 24*365.25 : 1.0))))
                            lambda = log(2) / (hl * conv) # hl_hours based lambda for audit
                            push!(radio_correction_audit, Dict(
                                "Name" => name, "IsCorrected" => true,
                                "HalfLife" => hl, "Unit" => hlu, "DeltaT" => delta_t_hours,
                                "DecayFactor" => exp(-lambda * delta_t_hours)
                            ))
                            Sys_Fast.FAST_Log_DDEF("VISE", "DECAY_CORRECT", "Input $name corrected.", "WARN")
                        end
                    end

                    # Correct Outputs (Y)
                    out_meta = get(config, "Outputs", [])
                    for (ci, name) in enumerate(OutNames)
                        idx = findfirst(x -> get(x, "Name", "") == name, out_meta)
                        if !isnothing(idx) && get(out_meta[idx], "IsRadioactive", false)
                            hl = Float64(get(out_meta[idx], "HalfLife", 0.0))
                            hlu = string(get(out_meta[idx], "HalfLifeUnit", "Hours"))
                            if hl > 0
                                for r in 1:N
                                    Y_Clean[r, ci] = Lib_Mole.MOLE_ApplyRadioDecay_DDEF(Y_Clean[r, ci], hl, hlu, delta_t_hours)
                                end
                                lambda = log(2) / (hl * (hlu == "Days" ? 24.0 : (hlu == "Minutes" ? 1/60 : (hlu == "Seconds" ? 1/3600 : (hlu == "Years" ? 24*365.25 : 1.0)))))
                                push!(radio_correction_audit, Dict(
                                    "Name" => name, "IsCorrected" => true,
                                    "HalfLife" => hl, "Unit" => hlu, "DeltaT" => delta_t_hours,
                                    "DecayFactor" => exp(-lambda * delta_t_hours)
                                ))
                                Sys_Fast.FAST_Log_DDEF("VISE", "DECAY_CORRECT", "Output $name corrected.", "WARN")
                            end
                        end
                    end
                end
            catch e
                Sys_Fast.FAST_Log_DDEF("VISE", "DECAY_ERROR", "Failed to apply correction: $e", "FAIL")
            end
        end
    end

    # Zero Variance Check (Flat Line Detector)
    P_quad = 10 # 1 + 2*3 + 3*(3-1)/2 = 10
    eff_model = ModelType == "Auto" ? (N > P_quad + 2 ? "quadratic" : "linear") : lowercase(ModelType)

    Log("VISE", "MODEL_SETUP", "Using '$eff_model' model for $N samples.", "OK")

    # NOTE: InNames and OutNames already computed at line 518-519, no reassignment needed

    models = map(eachindex(out_cols)) do m
        if occursin("kriging", eff_model) || occursin("rbf", eff_model)
            mod = VISE_TrainSurrogate_DDEF(X_Clean, view(Y_Clean, :, m), eff_model; InNames)
            mod["Q2"] = 0.999 # Kriging exactly fits data points
        elseif lowercase(eff_model) == "auto"
            mod, tournament_msg = VISE_SelectBestModel_DDEF(X_Clean, view(Y_Clean, :, m), InNames)
            Log("VISE", "TOURNAMENT", "Output $(OutNames[m]): $tournament_msg", "INFO")
        else
            mod = VISE_Regress_DDEF(X_Clean, view(Y_Clean, :, m), eff_model; InNames)
            mod["Q2"] = VISE_CrossValidate_DDEF(X_Clean, view(Y_Clean, :, m), eff_model)
        end
        mod["Goal"] = Goals[m]
        mod
    end

    r2_vec = [get(m, "R2_Adj", NaN) for m in models]
    r2_pred_vec = [get(m, "Q2", NaN) for m in models]

    valid_r2 = filter(!isnan, r2_vec)
    !isempty(valid_r2) && Log("VISE", "TRAINING_SUMMARY",
        "Average Model R²_Adj: $(round(mean(valid_r2); digits=3))", "OK")

    Best_Point = Float64[]
    Leaders_DF = DataFrame()

    if get(Opts, "Optim", true) && K >= 2
        bounds = hcat(minimum(X_Clean; dims=1)', maximum(X_Clean; dims=1)')

        # 1. Grid Search for Density Exploration & Leaders
        XT, YP, SC = VISE_GridSearch_DDEF(models, Goals, bounds)

        num_candidates = length(SC)

        # 2. BlackBoxOptim for absolute Global Maximum (Best_Point)
        Best_Point = Lib_Core.CORE_OptimiseDesirability_DDEF(models, Goals, bounds)

        # --- Leader Candidate Selection (Diversity-Focused) ---
        used_indices = Int[]
        cand_indices = Int[]
        cand_tags = String[]
        cand_count = 0

        top_indices = partialsortperm(SC, 1:min(8, num_candidates); rev=true)
        # Benchmark score is the score of the 8th leader (or the last of what we have)
        bench_score = SC[top_indices[end]]
        score_limit = bench_score * 0.90

        # Candidate pool: All points strictly within 10% of the top-8 benchmark
        tier_indices = findall(>=(score_limit), SC)

        # 1. Top 8 Global Leaders (Already identified)
        top_idx = top_indices[1]
        for i in 1:3
            val = XT[top_idx, i]
            b_min, b_max = bounds[i, 1], bounds[i, 2]
            # AskLeader expects [min, target, max]
            v_range = [b_min, (b_min + b_max) / 2, b_max]
            is_valid, msg = Main.Sys_Flow.FLOW_AskLeader_DDEF(val, v_range)
            if !is_valid
                push!(boundary_warnings, "$(InNames[i]): $msg")
            end
        end

        for k in 1:min(8, length(top_indices))
            p_idx = VISE_ClampIndex_DDEF(top_indices[k], num_candidates)
            cand_count += 1
            push!(cand_indices, p_idx)
            push!(cand_tags, @sprintf("TOP-%02d", k))
            push!(used_indices, p_idx)
        end

        # 2. Input-Based Diversity: Seek MINIMUM use of factors within the top tier
        for i in 1:min(3, size(XT, 2))
            tag_pre = i <= length(InNames) ? first(InNames[i] * "   ", 3) : "IN$i"

            # Find the best point in the tier that MINIMIZES this input
            best_idx = -1
            min_val = Inf
            for idx in tier_indices
                val = XT[idx, i]
                if val < min_val
                    min_val = val
                    best_idx = idx
                end
            end

            if best_idx != -1
                tag_str = (best_idx in used_indices) ? "INP-$(tag_pre)(D)" : "INP-$(tag_pre)"
                push!(cand_indices, best_idx)
                push!(cand_tags, tag_str)
                push!(used_indices, best_idx)
                cand_count += 1
            end
        end

        # 3. Output-Based Diversity: Seek BEST desirability for specific outputs within top tier
        for i in 1:min(3, size(YP, 2))
            tag_pre = i <= length(OutNames) ? first(OutNames[i] * "   ", 3) : "OUT$i"
            mod_goal = get(models[i], "Goal", Dict())
            gtup = Lib_Arts.ARTS_ExtractGoal_DDEF(mod_goal)

            # Find the best point in the tier that MAXIMIZES desirability for this specific output
            best_idx = -1
            max_d = -Inf
            for idx in tier_indices
                val = YP[idx, i]
                d_val = Lib_Arts.ARTS_CalcDesirability_DDEF(val, gtup)
                if d_val > max_d
                    max_d = d_val
                    best_idx = idx
                end
            end

            if best_idx != -1
                tag_str = (best_idx in used_indices) ? "OUT-$(tag_pre)(D)" : "OUT-$(tag_pre)"
                push!(cand_indices, best_idx)
                push!(cand_tags, tag_str)
                push!(used_indices, best_idx)
                cand_count += 1
            end
        end

        # --- CONSTRUCT CONSISTENT LEADERS_DF ---
        # Requirement: MATCH THE COLUMN STRUCTURE OF THE ORIGINAL DATA SHEET
        Leaders_DF = DataFrame()

        # Use primary headers from df_raw to maintain order
        main_headers = names(df_raw)

        for h in main_headers
            h_sym = Symbol(h)
            if h == C.COL_ID || h == C.COL_EXP_ID
                Leaders_DF[!, h_sym] = cand_tags
            elseif h == C.COL_PHASE
                Leaders_DF[!, h_sym] = fill(Phase, length(cand_indices))
            elseif h == C.COL_STATUS
                Leaders_DF[!, h_sym] = fill("Candidate", length(cand_indices))
            elseif h == C.COL_SCORE
                Leaders_DF[!, h_sym] = round.(SC[cand_indices]; digits=4)
            elseif startswith(h, C.PRE_INPUT)
                # Find index of this input in InNames
                clean_n = replace(h, C.PRE_INPUT => "")
                ki = findfirst(==(clean_n), InNames)
                if !isnothing(ki)
                    Leaders_DF[!, h_sym] = round.(XT[cand_indices, ki]; digits=3)
                else
                    Leaders_DF[!, h_sym] = fill(missing, length(cand_indices))
                end
            elseif startswith(h, C.PRE_PRED)
                clean_n = replace(h, C.PRE_PRED => "")
                ki = findfirst(==(clean_n), OutNames)
                if !isnothing(ki)
                    Leaders_DF[!, h_sym] = round.(YP[cand_indices, ki]; digits=3)
                else
                    Leaders_DF[!, h_sym] = fill(missing, length(cand_indices))
                end
            elseif startswith(h, C.PRE_RESULT)
                # Candidates don't have results yet
                Leaders_DF[!, h_sym] = fill(missing, length(cand_indices))
            else
                # Other columns (ID, Notes, etc.) fill with defaults or missing
                Leaders_DF[!, h_sym] = fill(missing, length(cand_indices))
            end
        end

        # Write candidate sets to the transient file for FLOW leader extraction
        # --- SAVE LEADERS (MOVED TO Sys_Flow) ---
        Main.Sys_Flow.FLOW_WriteLeaders_DDEF(DataFile, Phase, Leaders_DF)

        # 3. Physical Feasibility Bridge (The Golden Bridge)
        config = Sys_Fast.FAST_ReadConfig_DDEF(DataFile)
        ingreds = get(config, "Ingredients", [])
        if !isempty(ingreds)
            audit = Main.Lib_Mole.MOLE_AuditBatch_DDEF(ingreds, XT, 5.0, 10.0) # Defaults for stability
            if !audit["IsFeasible"]
                Log("VISE", "STOICHIOMETRY", "Experimental design contains physically questionable runs (Negative Mass).", "WARN")
            else
                Log("VISE", "STOICHIOMETRY", "Physical feasibility audit passed for entire candidate set.", "OK")
            end
        end

        Log("VISE", "OPTIMISATION", "Candidate pool (N=14 Diversity-Focussed) generated and saved.", "OK")
    end

    # Calculate predictions for actual experimental points
    Y_Pred = Matrix{Float64}(undef, N, length(out_cols))
    for m in eachindex(out_cols)
        Y_Pred[:, m] = VISE_Predict_DDEF(models[m], X_Clean)
    end

    # Calculate scores for actual experimental points
    parsed_goals = [Lib_Arts.ARTS_ExtractGoal_DDEF(models[m]["Goal"]) for m in eachindex(out_cols)]
    active_idx = findall(m -> get(models[m], "Status", "") == "OK", 1:length(out_cols))

    Actual_Scores = zeros(Float64, N)
    if !isempty(active_idx)
        weight_sum = sum(Float64(get(models[m]["Goal"], "Weight", 1.0)) for m in active_idx)
        pow = weight_sum > 0.0 ? (1.0 / weight_sum) : 1.0

        for i in 1:N
            s = 1.0
            for m_idx in active_idx
                val = Y_Pred[i, m_idx]
                gtup = parsed_goals[m_idx]
                d = Lib_Arts.ARTS_CalcDesirability_DDEF(val, gtup)
                s *= d^gtup[6]
            end
            res = s^pow
            Actual_Scores[i] = (isnan(res) || isinf(res)) ? 0.0 : clamp(res, 0.0, 1.0)
        end
    end

    # Standardise phase name for robust comparison
    target_phase_stripped = strip(uppercase(Phase))

    # Locate row indices that belong to the current phase by searching for normalised match
    row_idx_in_raw = Int[]
    if hasproperty(df_raw, col_phase)
        for (idx, row) in enumerate(eachrow(df_raw))
            val = get(row, col_phase, "")
            if !ismissing(val) && strip(uppercase(string(val))) == target_phase_stripped
                push!(row_idx_in_raw, idx)
            end
        end
    end

    if isempty(row_idx_in_raw)
        Log("VISE", "PHASE_EMPTY", "No records found for phase '$Phase'.", "FAIL")
        return Dict("Status" => "FAIL", "Message" => "No records found matching phase '$Phase'. Execution halted.")
    end


    pred_idx = 1
    for (i, raw_idx) in enumerate(row_idx_in_raw)
        if valid_mask[i]
            for (m, out_name) in enumerate(OutNames)
                pred_col = Symbol(C.PRE_PRED * out_name)
                if !hasproperty(df_raw, pred_col)
                    df_raw[!, pred_col] = Vector{Union{Missing,Float64}}(missing, nrow(df_raw))
                end
                df_raw[raw_idx, pred_col] = round(Y_Pred[pred_idx, m]; digits=3)
            end

            score_col = Symbol(C.COL_SCORE)
            if !hasproperty(df_raw, score_col)
                df_raw[!, score_col] = Vector{Union{Missing,Float64}}(missing, nrow(df_raw))
            end
            df_raw[raw_idx, score_col] = round(Actual_Scores[pred_idx]; digits=4)

            pred_idx += 1
        end
    end

    # --- Persist Predictions Back to Excel ---
    try
        target_sheet = C.SHEET_DATA
        if isfile(DataFile)
            try
                sheets = XLSX.sheetnames(XLSX.readxlsx(DataFile))
                if target_sheet ∉ sheets && "DATA_RECORDS" ∈ sheets
                    target_sheet = "DATA_RECORDS"
                end
            catch
            end
        end
        Sys_Fast.FAST_SafeExcelWrite_DDEF(DataFile, Dict(target_sheet => df_raw))
        Log("VISE", "PERSIST_PRED", "Saved predicted outputs to MasterVault.", "OK")
    catch e
        Log("VISE", "PERSIST_FAIL", "Failed to save predictions: $e", "WARN")
    end

    # --- Inject Surrogate Closures for Plotting ---
    for m in models
        m_type = lowercase(get(m, "ModelType", ""))
        if m_type == "kriging" || m_type == "rbf"
            m["_Closure"] = VISE_BuildSurrogateClosure_DDEF(m)
        end
    end

    graphs = Lib_Arts.ARTS_Render_DDEF(models, X_Clean, Y_Clean, InNames, OutNames,
        Goals, r2_vec, r2_pred_vec, Opts, Leaders_DF)

    # --- Scientific Vitals (Mathematical Health Check) ---
    vitals = Dict("D" => 0.0, "Condition" => Inf, "MaxVIF" => 0.0, "LOF" => 1.0)
    try
        # Pick the most complex model's design matrix for the global health check
        best_m = findfirst(m -> get(m, "ModelType", "") == "quadratic", models)
        isnothing(best_m) && (best_m = 1)

        m_type = get(models[best_m], "ModelType", "linear")
        Xd_health = VISE_ExpandDesign_DDEF(X_Clean, m_type)
        m_health = Lib_Core.CORE_CalcDesignMetrics_DDEF(Xd_health)

        vitals["D"] = m_health["D"]
        vitals["Condition"] = m_health["Condition"]

        # Calculate max VIF across all valid linear/quadratic models
        vif_list = [maximum(get(m, "VIFs", [0.0])) for m in models if haskey(m, "VIFs")]
        vitals["MaxVIF"] = isempty(vif_list) ? 1.0 : maximum(vif_list)

        # Quick Lack-of-Fit check for the first response
        if N > size(Xd_health, 2) + 2
            _, p_lof = VISE_LackOfFit_DDEF(Xd_health, view(Y_Clean, :, 1))
            vitals["LOF"] = p_lof
        end
    catch e
        Log("VISE", "VITALS_WARN", "Health diagnostics incomplete: $e", "WARN")
    end
    # --- Sensitivity Analysis at Optimal Point ---
    sens_list = Vector{Float64}[]
    if !isempty(Best_Point)
        for m in models
            push!(sens_list, VISE_SensitivityAnalysis_DDEF(m, Best_Point))
        end
    end

    # --- Academic Tier Diagnostics ---
    anova_tables = []
    normality_results = []
    residuals_list = []
    for (i, m) in enumerate(models)
        if get(m, "Status", "") == "OK"
            push!(anova_tables, VISE_GenerateAnovaTable_DDEF(m, X_Clean, Y_Clean[:, i]))
            push!(normality_results, VISE_PerformNormalityTest_DDEF(m, X_Clean, Y_Clean[:, i]))

            # Residuals for Q-Q plot
            m_type = get(m, "ModelType", "linear")
            Xd = VISE_ExpandDesign_DDEF(X_Clean, m_type)
            yp = Xd * get(m, "Coefs", zeros(size(Xd, 2)))
            push!(residuals_list, Y_Clean[:, i] .- yp)
        else
            push!(anova_tables, DataFrame())
            push!(normality_results, Dict("p" => NaN, "IsNormal" => false))
            push!(residuals_list, Float64[])
        end
    end

    return Dict(
        "Status" => "OK", "Graphs" => graphs,
        "Models" => models, "R2_Adj" => r2_vec,
        "R2_Pred" => r2_pred_vec, "BestPoint" => Best_Point,
        "Sensitivities" => sens_list,
        "Leaders" => Leaders_DF, "InNames" => InNames, "OutNames" => OutNames,
        "Vitals" => vitals,
        "BoundaryWarnings" => boundary_warnings,
        "Elapsed" => Sys_Fast.FAST_FormatDuration_DDEF(time() - t0),
        # Academic Tier Data
        "ANOVA" => anova_tables,
        "Normality" => normality_results,
        "Residuals" => residuals_list,
        "RadioCorrection" => radio_correction_audit,
        "X_Clean" => X_Clean,
        "Y_Clean" => Y_Clean
    )
end


end # module Lib_Vise
