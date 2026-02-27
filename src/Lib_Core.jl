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

export CORE_GenDesign_DDEF, CORE_CalcNextRange_DDEF, CORE_MapLevels_DDEF, CORE_ExtractLeader_DDEF

# --------------------------------------------------------------------------------------
# SECTION 1: EXPERIMENTAL DESIGN GENERATOR
# --------------------------------------------------------------------------------------

# Pre-allocated immutable design matrices
const _BB_DESIGN = Int8[
    -1 -1  0;  -1  1  0;  1 -1  0;  1  1  0;
    -1  0 -1;  -1  0  1;  1  0 -1;  1  0  1;
     0 -1 -1;   0 -1  1;  0  1 -1;  0  1  1;
     0  0  0;   0  0  0;  0  0  0
]

const _TL9_DESIGN = Int8[
    -1 -1 -1;  -1  0  0;  -1  1  1;
     0 -1  0;   0  0  1;   0  1 -1;
     1 -1  1;   1  0 -1;   1  1  0
]

"""
    CORE_GenDesign_DDEF(Method::String, FactorCount::Int) -> Matrix{Int8}
Generates a coded (-1, 0, 1) experiment matrix.
Supports: "BoxBehnken" (BB) and "Taguchi_L9" (TL9).
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
# SECTION 2: COORDINATE MAPPING (CODED -> PHYSICAL)
# --------------------------------------------------------------------------------------

"""
    CORE_MapLevels_DDEF(CodedMatrix, Config) -> Matrix{Float64}
Maps coded entries (-1, 0, 1) to physical units based on provided levels config.
"""
function CORE_MapLevels_DDEF(CodedMatrix::AbstractMatrix, Config::AbstractVector)
    rows, cols = size(CodedMatrix)

    if cols > length(Config)
        Sys_Fast.FAST_Log_DDEF("CORE", "MAP_ERROR", "Matrix columns exceed Config length.", "FAIL")
        return zeros(Float64, rows, cols)
    end

    # Pre-allocate result and fill column-by-column (vectorized indexing)
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
# SECTION 3: ADAPTIVE SEARCH LOGIC (ZOOM / SHIFT)
# --------------------------------------------------------------------------------------

"""
    CORE_CalcNextRange_DDEF(LeaderInfo) -> Vector{Dict}
Calculates the search space for the next phase based on the leader run's position.
Applies 'Zoom' (window reduction) or 'Shift' (center translation) logic.
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
            "Var $i -> $(action == "SHIFT" ? "Center shifted" : "Range reduced")", "LIST")

        New_Min = max(0.0, New_Mid - New_Range / 2)
        New_Min == 0.0 && Sys_Fast.FAST_Log_DDEF("CORE", "CLAMP", "Var $i hit negative boundary.", "WARN")

        conf["Levels"] = [New_Min, New_Mid, New_Mid + New_Range / 2]
    end

    Sys_Fast.FAST_Log_DDEF("CORE", "SEARCH_SPACE", "New space configured successfully.", "OK")
    return NewConf
end

# --------------------------------------------------------------------------------------
# SECTION 4: LEADER EXTRACTION
# --------------------------------------------------------------------------------------

"""
    CORE_ExtractLeader_DDEF(FilePath, PhaseCode, [SelectedID]) -> Dict
Retrieves experiment data for the optimal (leader) run from a previous phase.
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
    col_id    = findfirst(c -> occursin("ID", uppercase(c)), cols)

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
        "ID"         => id_str,
        "Score"      => row[col_score],
        "Vals"       => collect(vals),
        "InputNames" => input_cols,
        "OldConfig"  => Any[],
    )
end

end # module
