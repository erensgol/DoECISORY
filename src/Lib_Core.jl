module Lib_Core

# ==============================================================================
# DOECISORY - LIB CORE (CORE MATRICES)
# ==============================================================================
# Description: Module for experimental design generation, coordinate mapping, 
#              and adaptive search algorithms.
# Module Tag:  CORE
# ==============================================================================

using Random
using LinearAlgebra
using Printf
using ..Sys_Fast
using BlackBoxOptim

const Main = parentmodule(@__MODULE__)


export CORE_GenDesign_DDEF, CORE_MapLevels_DDEF,
    CORE_ExtractLeader_DDEF, CORE_GenDf14Design_DDEF, CORE_ExpandModelMatrix_DDEF,
    CORE_OptimiseDesirability_DDEF, CORE_ValidateDesign_DDEF,
    CORE_D_Efficiency_DDEF, CORE_CalcDesignMetrics_DDEF, CORE_CodeMatrix_DDEF,
    CORE_CalcDesirability_DDEF, CORE_ExtractGoal_DDEF, CORE_GetModelType_DDEF,
    CORE_ModifierDCYP_DDES, CORE_ApplyDCYP_DDEF, CORE_GetNeighborWeights_DDEF, CORE_StarWeights_DDEC,
    CORE_MethodBB15_DDES, CORE_MethodTL09_DDES, CORE_MethodCD17_DDES, CORE_MethodDF14_DDES

# ==============================================================================
# PART A: DESIGN MATRIX & COORDINATE GENERATION
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 1: DESIGN METHOD & MODEL DISPATCHERS
# ------------------------------------------------------------------------------

abstract type CORE_AbstractDesignMethod_DDET end
struct CORE_MethodBB15_DDES <: CORE_AbstractDesignMethod_DDET end
struct CORE_MethodTL09_DDES <: CORE_AbstractDesignMethod_DDET end
struct CORE_MethodCD17_DDES <: CORE_AbstractDesignMethod_DDET end
struct CORE_MethodDF14_DDES <: CORE_AbstractDesignMethod_DDET end

const CORE_MethodMap_DDEC = Dict{String, CORE_AbstractDesignMethod_DDET}(
    "BB15" => CORE_MethodBB15_DDES(),
    "TL09" => CORE_MethodTL09_DDES(),
    "CD17" => CORE_MethodCD17_DDES(),
    "DF14" => CORE_MethodDF14_DDES()
)

abstract type CORE_AbstractModelType_DDET end
struct CORE_ModelLinear_DDES <: CORE_AbstractModelType_DDET end
struct CORE_ModelQuadratic_DDES <: CORE_AbstractModelType_DDET end

const CORE_ModelMap_DDEC = Dict{String, CORE_AbstractModelType_DDET}(
    "linear"    => CORE_ModelLinear_DDES(),
    "quadratic" => CORE_ModelQuadratic_DDES(),
    "quad"      => CORE_ModelQuadratic_DDES()
)

export CORE_AbstractModelType_DDET, CORE_ModelLinear_DDES, CORE_ModelQuadratic_DDES

# ------------------------------------------------------------------------------
# SECTION 2: CONSTANTS - PRE-ALLOCATED DESIGN MATRICES
# ------------------------------------------------------------------------------

const CORE_Tl09Design_DDEC = Int8[
    -1 -1 -1;
    -1  0  0;
    -1  1  1;
     0 -1  0;
     0  0  1;
     0  1 -1;
     1 -1  1;
     1  0 -1;
     1  1  0
]

const CORE_Bb15Design_DDEC = Int8[
     0  0  0;
    -1 -1  0;
     1 -1  0;
    -1  1  0;
     1  1  0;
     0  0  0;
    -1  0 -1;
     1  0 -1;
    -1  0  1;
     1  0  1;
     0  0  0;
     0 -1 -1;
     0  1 -1;
     0 -1  1;
     0  1  1
]

const CORE_Cd17Design_DDEC = Int8[
     0  0  0;
     1 -1 -1;
    -1  1 -1;
    -1 -1  1;
     1  1  1;
     0  0  0;
     1 -1  1;
    -1  1  1;
     1  1 -1;
    -1 -1 -1;
     0  0  0;
    -1  0  0;
     1  0  0;
     0 -1  0;
     0  1  0;
     0  0 -1;
     0  0  1
]

function CORE_GenDf14Design_DDEF(direction::AbstractVector=[-1, -1, -1])::Matrix{Int8}
    s1 = Int8(length(direction) >= 1 && direction[1] >= 0 ? 1 : -1)
    s2 = Int8(length(direction) >= 2 && direction[2] >= 0 ? 1 : -1)
    s3 = Int8(length(direction) >= 3 && direction[3] >= 0 ? 1 : -1)
    return Int8[
         0   0   0;
        s1   0   0;
         1  -1  -1;
        -1   1  -1;
         1   1   1;
         0   0   0;
         0  s2   0;
        -1  -1   1;
         1  -1   1;
        -1   1   1;
         0   0   0;
         0   0  s3;
         1   1  -1;
        -1  -1  -1
    ]
end

"""
    CORE_GenDesign_DDEF(Method::AbstractString, FactorCount::Integer=3, Direction::AbstractVector=[-1, -1, -1]) -> Matrix{Int8}
Generates a coded (-1, 0, 1) experimental design matrix for the specified method.
Supports Box-Behnken (BB15), Taguchi (TL09), Central Composite (CD17), and Fractional D-Optimal (DF14).
"""
function CORE_GenDesign_DDEF(Method::AbstractString, FactorCount::Integer=3; Direction::AbstractVector=[-1, -1, -1])
    Main.Sys_Fast.FAST_Log_DDEF("CORE", "DESIGN_GEN", "Generating matrix for $Method (Strict 3-Var Mode)", "WAIT")
    method_type = CORE_GetMethodType_DDEF(Method)
    design = CORE_GenerateMatrix_DDEF(method_type, FactorCount, Direction)
    R, C_dim = size(design)
    Main.Sys_Fast.FAST_Log_DDEF("CORE", "GEN_SUCCESS", "$R Runs x $C_dim Variables created.", "OK")
    return design
end

CORE_GenDesign_DDEF(Method::AbstractString, FactorCount::Integer, Direction::AbstractVector) = 
    CORE_GenDesign_DDEF(Method, FactorCount; Direction=Direction)

function CORE_GetMethodType_DDEF(m::AbstractString)::CORE_AbstractDesignMethod_DDET
    u = uppercase(strip(m))
    haskey(CORE_MethodMap_DDEC, u) && return CORE_MethodMap_DDEC[u]
    throw(ArgumentError("Unknown experimental design method: '$m'. Valid options: TL09, BB15, CD17, DF14."))
end

function CORE_GetModelType_DDEF(m::AbstractString)::CORE_AbstractModelType_DDET
    u = lowercase(strip(m))
    return get(CORE_ModelMap_DDEC, u, CORE_ModelQuadratic_DDES())
end

CORE_GetModelType_DDEF(m::CORE_AbstractModelType_DDET) = m

CORE_GenerateMatrix_DDEF(::CORE_MethodTL09_DDES, fc::Integer, dir::AbstractVector=[-1, -1, -1]) = copy(CORE_Tl09Design_DDEC)
CORE_GenerateMatrix_DDEF(::CORE_MethodBB15_DDES, fc::Integer, dir::AbstractVector=[-1, -1, -1]) = copy(CORE_Bb15Design_DDEC)
CORE_GenerateMatrix_DDEF(::CORE_MethodCD17_DDES, fc::Integer, dir::AbstractVector=[-1, -1, -1]) = copy(CORE_Cd17Design_DDEC)
CORE_GenerateMatrix_DDEF(::CORE_MethodDF14_DDES, fc::Integer, dir::AbstractVector=[-1, -1, -1]) = CORE_GenDf14Design_DDEF(dir)


# ------------------------------------------------------------------------------
# SECTION 3: COORDINATE MAPPING (CODED -> PHYSICAL)
# ------------------------------------------------------------------------------

"""
    CORE_MapLevels_DDEF(CodedMatrix, Config) -> Matrix{Float64}
Maps coded entries in [-1, 1] to physical units via piecewise linear interpolation.
Integer coded coordinates (-1, 0, 1) map directly to discrete level boundaries (L1, L2, L3).
"""
function CORE_MapLevels_DDEF(CodedMatrix::AbstractMatrix, Config::AbstractVector)
    rows = size(CodedMatrix, 1)
    cols = 3

    result = Matrix{Float64}(undef, rows, cols)
    @inbounds for i in 1:cols
        lvls = get(Config[i], "Levels", zeros(3))
        length(lvls) < 3 && (lvls = zeros(3))
        L1, L2, L3 = Float64(lvls[1]), Float64(lvls[2]), Float64(lvls[3])
        for r in 1:rows
            c = Float64(CodedMatrix[r, i])
            result[r, i] = c < 0.0 ? L2 + c * (L2 - L1) : L2 + c * (L3 - L2)
        end
    end
    return result
end

# ==============================================================================
# PART B: ALGORITHMIC OPTIMISERS & DESIRABILITY ENGINE
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 4: MULTI-OBJECTIVE DESIRABILITY & OPTIMISATION
# ------------------------------------------------------------------------------

abstract type CORE_AbstractGoalType_DDET end
struct CORE_GoalMaximise_DDES <: CORE_AbstractGoalType_DDET end
struct CORE_GoalMinimise_DDES <: CORE_AbstractGoalType_DDET end
struct CORE_GoalNominal_DDES  <: CORE_AbstractGoalType_DDET end

const CORE_GoalMap_DDEC = Dict{String, CORE_AbstractGoalType_DDET}(
    "maximise" => CORE_GoalMaximise_DDES(),
    "minimise" => CORE_GoalMinimise_DDES(),
    "nominal"  => CORE_GoalNominal_DDES(),
    "target"   => CORE_GoalNominal_DDES()
)

"""
    CORE_ExtractGoal_DDEF(Goal) -> Tuple
Extracts and normalises goal parameters and returns a Trait + Parameter tuple.
"""
function CORE_ExtractGoal_DDEF(Goal::AbstractDict)::Tuple{CORE_AbstractGoalType_DDET, Float64, Float64, Float64, Float64}
    G_Min = Float64(get(Goal, "Min", -Inf))
    G_Max = Float64(get(Goal, "Max", Inf))
    G_Tgt_Raw = get(Goal, "Target", nothing)
    G_Tgt = if !isnothing(G_Tgt_Raw)
        Float64(G_Tgt_Raw)
    elseif isfinite(G_Min) && isfinite(G_Max)
        (G_Min + G_Max) / 2
    else
        0.0
    end
    Type_Str = lowercase(strip(string(get(Goal, "Type", "Nominal"))))
    Weight = max(0.0, Float64(get(Goal, "Weight", 1.0)))
    
    Trait = get(CORE_GoalMap_DDEC, Type_Str, CORE_GoalNominal_DDES())
    return (Trait, G_Min, G_Max, G_Tgt, Weight)
end

CORE_ExtractGoal_DDEF(G::Tuple) = G

"""
    CORE_CalcDesirability_DDEF(Val, Goal) -> Float64
Calculates desirability scores via Multiple Dispatch.
"""
function CORE_CalcDesirability_DDEF(Val::Float64, Goal::AbstractDict)::Float64
    return CORE_CalcDesirability_DDEF(Val, CORE_ExtractGoal_DDEF(Goal))
end

function CORE_CalcDesirability_DDEF(Val::Float64, GoalTup::Tuple{CORE_AbstractGoalType_DDET, Float64, Float64, Float64, Float64})::Float64
    return CORE_CalcDesirability_DDEF(GoalTup[1], Val, GoalTup[2], GoalTup[3], GoalTup[4], GoalTup[5])
end

function CORE_CalcDesirability_DDEF(::CORE_GoalMaximise_DDES, Val::Float64, G_Min::Float64, G_Max::Float64, G_Tgt::Float64, Weight::Float64)::Float64
    Val >= G_Tgt && return 1.0
    Val <= G_Min && return 0.0
    denom = G_Tgt - G_Min
    res = denom > 1e-9 ? ((Val - G_Min) / denom)^Weight : 1.0
    return clamp(res, 0.0, 1.0)
end

function CORE_CalcDesirability_DDEF(::CORE_GoalMinimise_DDES, Val::Float64, G_Min::Float64, G_Max::Float64, G_Tgt::Float64, Weight::Float64)::Float64
    Val <= G_Tgt && return 1.0
    Val >= G_Max && return 0.0
    denom = G_Max - G_Tgt
    res = denom > 1e-9 ? ((G_Max - Val) / denom)^Weight : 1.0
    return clamp(res, 0.0, 1.0)
end

function CORE_CalcDesirability_DDEF(::CORE_GoalNominal_DDES, Val::Float64, G_Min::Float64, G_Max::Float64, G_Tgt::Float64, Weight::Float64)::Float64
    (Val <= G_Min || Val >= G_Max) && return 0.0
    abs(Val - G_Tgt) < 1e-12 && return 1.0
    if Val < G_Tgt
        denom = G_Tgt - G_Min
        res = denom > 1e-9 ? ((Val - G_Min) / denom)^Weight : 1.0
    else
        denom = G_Max - G_Tgt
        res = denom > 1e-9 ? ((G_Max - Val) / denom)^Weight : 1.0
    end
    return clamp(res, 0.0, 1.0)
end

const CORE_StarWeights_DDEC = Float64[0.50, 0.75, 1.00, 1.50, 2.00]

function CORE_GetNeighborWeights_DDEF(Weight::Float64)::Tuple{Float64, Float64, Float64}
    idx = findmin(abs.(CORE_StarWeights_DDEC .- Weight))[2]
    w_minus = CORE_StarWeights_DDEC[max(1, idx - 1)]
    w_curr  = CORE_StarWeights_DDEC[idx]
    w_plus  = CORE_StarWeights_DDEC[min(5, idx + 1)]
    return (w_minus, w_curr, w_plus)
end

# ------------------------------------------------------------------------------
# SECTION 5: DECAY-COUPLED OPTIMISATION MODIFIER
# ------------------------------------------------------------------------------

"""
    CORE_ModifierDCYP_DDES
Carries radioactive decay parameters into the optimisation loop for the DCYP mechanism.
When a reaction time variable is identified among the design factors, this struct
enables the objective function to penalise composite desirability by the exponential
decay factor e^(-lambda * t), solving the incubation time-yield paradox described in
radiopharmaceutical DoE literature.

Fields:
- TimeIndex:   Column index of the reaction time variable in the X matrix.
- Lambda:      Decay constant in minutes (ln(2) / half_life_minutes).
- IsotopeName: Display name for logging and audit trail.
"""
struct CORE_ModifierDCYP_DDES
    TimeIndex::Int
    Lambda::Float64
    IsotopeName::String
end

"""
    CORE_ApplyDCYP_DDEF(Score, Mod, x) -> Float64
Applies the exponential decay penalty e^(-lambda * t) to a composite desirability score
based on the reaction incubation time extracted from candidate point x at Mod.TimeIndex.
"""
function CORE_ApplyDCYP_DDEF(Score::Float64, Mod::CORE_ModifierDCYP_DDES, x)::Float64
    (Mod.TimeIndex < 1 || Mod.TimeIndex > length(x)) && return Score
    t_val = Float64(x[Mod.TimeIndex])
    t_val <= 0.0 && return Score
    return Score * exp(-Mod.Lambda * t_val)
end

"""
    CORE_OptimiseDesirability_DDEF(Models, Goals, X_Bounds; MaxTime, PenaltyFn, ModifiersDCYP) -> (Vector{Float64}, Float64)
Globally optimises parameters by maximising composite desirability using BlackBoxOptim.
When ModifiersDCYP are supplied, the objective function applies exponential decay
penalties to composite desirability, enabling the solver to locate the peak time point
where chemical conversion and radioactive preservation intersect.
"""
function CORE_OptimiseDesirability_DDEF(Models::AbstractVector, Goals::AbstractVector, X_Bounds::AbstractMatrix{Float64};
    MaxTime::Float64=2.0, PenaltyFn::Union{Function,Nothing}=nothing,
    ModifiersDCYP::Vector{CORE_ModifierDCYP_DDES}=CORE_ModifierDCYP_DDES[])
    Dim       = 3
    NumModels = length(Models)

    active_indices = Int[]
    parsed_goals = [CORE_ExtractGoal_DDEF(m <= length(Goals) ? Goals[m] : get(Models[m], "Goal", Dict{String, Any}())) for m in 1:NumModels]
    base_goals   = [(g[1], g[2], g[3], g[4], 1.0) for g in parsed_goals]
    for m in 1:NumModels
        if get(Models[m], "Status", "") == "OK"
            push!(active_indices, m)
        end
    end
    num_active = length(active_indices)
    inv_k      = num_active > 0 ? (1.0 / num_active) : 1.0
    neighbor_weights = [CORE_GetNeighborWeights_DDEF(parsed_goals[m][5]) for m in active_indices]

    closures = Any[nothing for _ in 1:NumModels]
    for m in 1:NumModels
        mod_status = get(Models[m], "Status", "")
        mod_status != "OK" && continue
        
        # Defensive acquisition of model coefficients
        private_beta = collect(Float64, get(Models[m], "Coefs", Float64[]))
        isempty(private_beta) && continue
        
        mod_type = CORE_GetModelType_DDEF(lowercase(get(Models[m], "ModelType", "quadratic")))
        closures[m] = CORE_GetPredictor_DDEF(mod_type, private_beta)
    end

    function CORE_CalcObjective_DDEF(x)
        prod_u = 1.0
        prod_e = 1.0
        for (j, m) in enumerate(active_indices)
            c = closures[m]
            isnothing(c) && continue
            val = c(x)
            (isnan(val) || isinf(val)) && return 0.0

            b = CORE_CalcDesirability_DDEF(val, base_goals[m])
            if b <= 1e-12
                prod_u = 0.0
                prod_e = 0.0
                break
            end

            w_m, w_c, w_p = neighbor_weights[j]
            u = b^(w_c * inv_k)
            e = (b^(w_m * inv_k) + u + b^(w_p * inv_k)) / 3.0
            prod_u *= u
            prod_e *= e
        end
        score = clamp(0.50 * prod_u + 0.50 * prod_e, 0.0, 1.0)

        # Decay-Coupled Optimization: Penalise composite desirability directly by reaction time decay
        for dm in ModifiersDCYP
            score = CORE_ApplyDCYP_DDEF(score, dm, x)
        end

        if PenaltyFn !== nothing
            score *= PenaltyFn(x)
        end

        return -score
    end

    search_range = [(X_Bounds[i, 1], X_Bounds[i, 2]) for i in 1:Dim]

    decay_msg = isempty(ModifiersDCYP) ? "" : " [DCYP: $(join([dm.IsotopeName for dm in ModifiersDCYP], ", "))]"
    Main.Sys_Fast.FAST_Log_DDEF("CORE", "BBO_START", "Initiating BlackBoxOptim for Global Desirability (MaxTime: $(MaxTime)s)...$(decay_msg)", "WAIT")

    try
        res = bboptimize(CORE_CalcObjective_DDEF; SearchRange=search_range, NumDimensions=Dim, MaxTime=MaxTime, Method=:adaptive_de_rand_1_bin_radiuslimited, TraceMode=:silent)
        best_x = best_candidate(res)
        best_score = -best_fitness(res)
        Main.Sys_Fast.FAST_Log_DDEF("CORE", "BBO_SUCCESS", "Global Optimum Found -> Score: $(round(best_score, digits=4))", "OK")
        
        refined_x, refined_score = CORE_LocalRefinement_DDEF(CORE_CalcObjective_DDEF, best_candidate(res), search_range)
        
        if refined_score > best_score + 1e-6
            Main.Sys_Fast.FAST_Log_DDEF("CORE", "LOCAL_REFINE", "Optimum Polished: $(round(best_score; digits=4)) -> $(round(refined_score; digits=4))", "OK")
            return refined_x, refined_score
        end
        return best_x, best_score
    catch e
        Main.Sys_Fast.FAST_Log_DDEF("CORE", "BBO_FAIL", "BlackBoxOptim encountered a critical failure: $e. Reverting to geometric centre.", "FAIL")
        return [ (X_Bounds[i, 1] + X_Bounds[i, 2]) / 2.0 for i in 1:Dim ], 0.0
    end
end

function CORE_LocalRefinement_DDEF(obj_fn, start_x, range; iters=100)
    dim = length(start_x)
    current_x = copy(start_x)
    current_score = -obj_fn(current_x)
    
    # Adaptive step size starting at 5% of the total span
    step_sizes = [(r[2] - r[1]) * 0.05 for r in range]
    
    for _ in 1:iters
        improved = false
        for d in 1:dim
            for sign in [-1, 1]
                test_x = copy(current_x)
                test_x[d] = clamp(test_x[d] + sign * step_sizes[d], range[d][1], range[d][2])
                
                test_score = -obj_fn(test_x)
                if test_score > current_score + 1e-7
                    current_x[d] = test_x[d]
                    current_score = test_score
                    improved = true
                end
            end
        end
        !improved && (step_sizes .*= 0.5)
        all(s < 1e-6 for s in step_sizes) && break
    end
    
    return current_x, current_score
end

function CORE_GetPredictor_DDEF(::CORE_ModelLinear_DDES, b::Vector{Float64})
    length(b) < 4 && throw(ArgumentError("Linear coefficients vector must have at least 4 elements, got $(length(b))"))
    return (x::AbstractVector{Float64}) -> (b[1] + b[2]*x[1] + b[3]*x[2] + b[4]*x[3])::Float64
end

function CORE_GetPredictor_DDEF(::CORE_ModelQuadratic_DDES, b::Vector{Float64})
    length(b) < 10 && throw(ArgumentError("Quadratic coefficients vector must have at least 10 elements, got $(length(b))"))
    return (x::AbstractVector{Float64}) -> (@inbounds (b[1] + b[2]*x[1] + b[3]*x[2] + b[4]*x[3] + b[5]*x[1]*x[2] + b[6]*x[1]*x[3] + b[7]*x[2]*x[3] + b[8]*x[1]*x[1] + b[9]*x[2]*x[2] + b[10]*x[3]*x[3]))::Float64
end

# ------------------------------------------------------------------------------
# SECTION 6: LEADER DATA EXTRACTION
# ------------------------------------------------------------------------------

"""
    CORE_ExtractLeader_DDEF(FilePath, PhaseCode, [SelectedID], [VarNames]) -> Dict
Retrieves experiment data for the optimal (leader) run from a previous phase record.
"""
function CORE_ExtractLeader_DDEF(FilePath::AbstractString, PhaseCode::AbstractString, SelectedID::AbstractString="", VarNames::AbstractVector{<:AbstractString}=String[])
    C     = Main.Sys_Fast.FAST_Data_DDEC
    sheet = C.PREFIX_LEADERS * PhaseCode

    df = Main.Sys_Fast.FAST_ReadExcel_DDEF(FilePath, sheet)
    if isempty(df)
        Main.Sys_Fast.FAST_Log_DDEF("CORE", "EXTRACTION_FAIL", "Sheet '$sheet' not found or empty.", "FAIL")
        return Dict{String,Any}()
    end

    cols      = names(df)
    col_score = findfirst(c -> occursin("SCORE", uppercase(strip(string(c)))), cols)
    col_id    = findfirst(c -> uppercase(strip(string(c))) in ("ID", "EXP_ID"), cols)

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
# SECTION 7: DESIGN MATRIX VALIDATION
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
# SECTION 8: DESIGN QUALITY METRICS (D, A, G, I Efficiency)
# ------------------------------------------------------------------------------

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
        col_safe  = clamp.(col, b_min, b_max)
        
        if range_val < 1e-9
            X_coded[:, j] .= col_safe
        elseif b_min >= -1.0001 && b_max <= 1.0001 && abs(b_min + b_max) < 1e-3
            X_coded[:, j] .= col_safe
        else
            X_coded[:, j] .= 2.0 .* (col_safe .- b_min) ./ range_val .- 1.0
        end
    end
    return X_coded
end

"""
    CORE_ExpandModelMatrix_DDEF(X::AbstractMatrix, ModelType::CORE_AbstractModelType_DDET) -> Matrix{Float64}
Expands coded 3-factor design matrix to full linear (p=4) or quadratic (p=10) model matrix.
Columns for Quadratic: [1, x1, x2, x3, x1*x2, x1*x3, x2*x3, x1^2, x2^2, x3^2].
Columns for Linear:    [1, x1, x2, x3].
"""
function CORE_ExpandModelMatrix_DDEF(X::AbstractMatrix, ModelType::CORE_AbstractModelType_DDET=CORE_ModelQuadratic_DDES())::Matrix{Float64}
    R, C = size(X)
    C != 3 && throw(ArgumentError("DoECISORY model matrix expansion requires exactly 3 factor columns. Found: $C"))

    if isa(ModelType, CORE_ModelLinear_DDES)
        X_exp = Matrix{Float64}(undef, R, 4)
        @inbounds for i in 1:R
            X_exp[i, 1] = 1.0
            X_exp[i, 2] = Float64(X[i, 1])
            X_exp[i, 3] = Float64(X[i, 2])
            X_exp[i, 4] = Float64(X[i, 3])
        end
        return X_exp
    else
        X_exp = Matrix{Float64}(undef, R, 10)
        @inbounds for i in 1:R
            x1, x2, x3 = Float64(X[i, 1]), Float64(X[i, 2]), Float64(X[i, 3])
            X_exp[i, 1]  = 1.0
            X_exp[i, 2]  = x1
            X_exp[i, 3]  = x2
            X_exp[i, 4]  = x3
            X_exp[i, 5]  = x1 * x2
            X_exp[i, 6]  = x1 * x3
            X_exp[i, 7]  = x2 * x3
            X_exp[i, 8]  = x1 * x1
            X_exp[i, 9]  = x2 * x2
            X_exp[i, 10] = x3 * x3
        end
        return X_exp
    end
end

function CORE_ExpandModelMatrix_DDEF(X::AbstractMatrix, ModelType::AbstractString)::Matrix{Float64}
    return CORE_ExpandModelMatrix_DDEF(X, CORE_GetModelType_DDEF(ModelType))
end

"""
    CORE_D_Efficiency_DDEF(X::AbstractMatrix, [ModelType]) -> Float64
Calculates academic D-Efficiency based on normalized Fisher information determinant:
D = (|X'X| / N^p)^(1/p) where N is run count and p is number of model parameters (10 for quadratic, 4 for linear).
"""
function CORE_D_Efficiency_DDEF(X::AbstractMatrix, ModelType::CORE_AbstractModelType_DDET=CORE_ModelQuadratic_DDES())::Float64
    R, _ = size(X)
    effective_model = (R < 10 && ModelType isa CORE_ModelQuadratic_DDES) ? CORE_ModelLinear_DDES() : ModelType
    X_sc = CORE_CodeMatrix_DDEF(X)
    X_exp = CORE_ExpandModelMatrix_DDEF(X_sc, effective_model)
    p = size(X_exp, 2)
    R < p && return 0.0

    try
        M = X_exp' * X_exp
        det_val = det(M)
        det_val <= 0.0 && return 0.0
        eff = (det_val / (Float64(R)^p))^(1.0 / p)
        return clamp(eff, 0.0, 1.0)
    catch
        return 0.0
    end
end

function CORE_D_Efficiency_DDEF(X::AbstractMatrix, ModelType::AbstractString)::Float64
    return CORE_D_Efficiency_DDEF(X, CORE_GetModelType_DDEF(ModelType))
end

"""
    CORE_CalcDesignMetrics_DDEF(X::AbstractMatrix, [ModelType]) -> Dict
Calculates a comprehensive suite of design quality metrics including D, A, G, and I efficiency
using the expanded model matrix (10 parameters for quadratic, 4 parameters for linear).
"""
function CORE_CalcDesignMetrics_DDEF(X::AbstractMatrix, ModelType::CORE_AbstractModelType_DDET=CORE_ModelQuadratic_DDES())
    R, C = size(X)
    res  = Dict("D" => 0.0, "A" => 0.0, "G" => 0.0, "I" => 0.0, "Condition" => Inf)
    C != 3 && return res

    effective_model = (R < 10 && ModelType isa CORE_ModelQuadratic_DDES) ? CORE_ModelLinear_DDES() : ModelType
    X_sc = CORE_CodeMatrix_DDEF(X)
    X_exp = CORE_ExpandModelMatrix_DDEF(X_sc, effective_model)
    p = size(X_exp, 2)
    R < p && return res

    try
        XtX = X_exp' * X_exp
        res["Condition"] = cond(XtX)

        det_val = det(XtX)
        res["D"] = det_val > 0.0 ? clamp((det_val / (Float64(R)^p))^(1.0 / p), 0.0, 1.0) : 0.0

        inv_XtX = pinv(XtX)
        tr_inv = tr(inv_XtX)
        res["A"] = tr_inv > 0.0 ? clamp(p / (R * tr_inv), 0.0, 1.0) : 0.0

        lev = diag(X_exp * inv_XtX * X_exp')
        max_var = maximum(lev)
        res["G"] = max_var > 0.0 ? clamp(p / (R * max_var), 0.0, 1.0) : 0.0

        mean_lev = sum(lev) / length(lev)
        res["I"] = mean_lev > 0.0 ? clamp(p / (R * mean_lev), 0.0, 1.0) : 0.0
    catch e
        Main.Sys_Fast.FAST_Log_DDEF("CORE", "METRICS_ERR", "Stability error in design metrics: $e", "WARN")
    end
    return res
end

function CORE_CalcDesignMetrics_DDEF(X::AbstractMatrix, ModelType::AbstractString)
    return CORE_CalcDesignMetrics_DDEF(X, CORE_GetModelType_DDEF(ModelType))
end

end