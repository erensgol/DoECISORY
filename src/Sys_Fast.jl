module Sys_Fast

# ======================================================================================
# DAISHODOE - SYSTEM FAST (IO & UTILS)
# ======================================================================================
# Purpose: Excel I/O, Logging, Constants, and System-wide Utilities.
# Module Tag: FAST
# ======================================================================================

using Dates
using Printf
using XLSX
using DataFrames
using JSON3
using Base64

export FAST_Log_DDEF, FAST_ReadExcel_DDEF,
    FAST_Constants_DDEF, FAST_SafeNum_DDEF, FAST_GetLabDefaults_DDEF,
    FAST_InitMaster_DDEF, FAST_NormalizeCols_DDEF,
    FAST_SanitizeJSON_DDEF, FAST_PrepareDownload_DDEF,
    FAST_GenerateSmartName_DDEF, FAST_GetTransientPath_DDEF, FAST_ReadToStore_DDEF,
    FAST_ReadConfig_DDEF, FAST_GetThreadInfo_DDEF,
    FAST_SanitizeInput_DDEF,
    FAST_AcquireLock_DDEF, FAST_ReleaseLock_DDEF, FAST_IsLocked_DDEF,
    FAST_CacheRead_DDEF, FAST_CacheWrite_DDEF, FAST_CacheEvict_DDEF,
    FAST_SpawnCompute_DDEF, FAST_GetComputeThreads_DDEF,
    CONST_DATA

# --------------------------------------------------------------------------------------
# SECTION 1: CONSTANTS & CONFIGURATION
# --------------------------------------------------------------------------------------

"""
    Constants
System-wide configuration and metadata structure.
"""
Base.@kwdef struct Constants
    VERSION::String = "2.0.0"

    # --- Standard Base Colors ---
    COLOR_RED::String = "#FF0000"
    COLOR_WHITE::String = "#FFFFFF"
    COLOR_BLACK::String = "#000000"

    # --- Standard Gray Colors ---
    COLOR_GRAY_D::String = "#666666"
    COLOR_GRAY_M::String = "#A6A6A6"
    COLOR_GRAY_L::String = "#E6E6E6"
    COLOR_GRAY_G::String = "#DCDCDC"

    # --- Standard Viridis Colors ---
    COLOR_YELLOW::String = "#FDE725"  # Viridis 1.00
    COLOR_GREEN::String = "#5EC962"  # Viridis 0.75
    COLOR_CYAN::String = "#21918C"  # Viridis 0.50
    COLOR_BLUE::String = "#3B528B"  # Viridis 0.25
    COLOR_MAGENTA::String = "#440154"  # Viridis 0.00

    # --- Excel Sheet Names ---
    SHEET_DATA::String = "DATA"
    SHEET_CONFIG::String = "CONFIG"

    # --- Column Prefixes ---
    PRE_INPUT::String = "VARIA_"
    PRE_FIXED::String = "FIXED_"
    PRE_FILL::String = "FILL_"
    PRE_MASS::String = "MASS_"
    PRE_RESULT::String = "RESULT_"
    PRE_PRED::String = "PRED_"
    PREFIX_LEADERS::String = "Leaders_"

    # --- Standard Column Names ---
    COL_EXP_ID::String = "EXP_ID"
    COL_PHASE::String = "PHASE"
    COL_RUN_ORDER::String = "RUN_ORDER"
    COL_STATUS::String = "STATUS"
    COL_SCORE::String = "SCORE"
    COL_NOTES::String = "NOTES"
    COL_ID::String = "ID"

    # --- Role Definitions ---
    ROLE_VAR::String = "Variable"
    ROLE_FILL::String = "Filler"
    ROLE_FIX::String = "Fixed"

    # --- Design Methods ---
    METHOD_BB::String = "BoxBehnken"
    METHOD_TL9::String = "Taguchi_L9"

end

const CONST_DATA = Constants()

"""
    FAST_Constants_DDEF() -> Constants
Returns the global system constants.
"""
FAST_Constants_DDEF() = CONST_DATA

# --------------------------------------------------------------------------------------
# SECTION 2: LOGGING SYSTEM
# --------------------------------------------------------------------------------------

# Pre-computed ANSI colour lookup (avoid Dict allocation per log call)
const _LOG_COLORS = (;
    INFO="\e[34m",
    OK="\e[32m",
    WARN="\e[33m",
    FAIL="\e[31m",
    WAIT="\e[36m",
    LIST="\e[37m",
)
const _LOG_COLOR_DEFAULT = "\e[34m"
const _LOG_RESET = "\e[0m"

"""
    FAST_Log_DDEF(Source, Event, Detail, Type)
Standardised console logging with ANSI colour support.
"""
function FAST_Log_DDEF(Source::String, Event::String, Detail::String="", Type::String="INFO")
    c = get(_LOG_COLORS, Symbol(Type), _LOG_COLOR_DEFAULT)
    ts = Dates.format(now(), "HH:MM:SS")
    @printf("\e[34m[%s]%s \e[32m%-12s%s: %s%-15s%s %s%s%s\n",
        ts, _LOG_RESET, Source, _LOG_RESET, c, Event, _LOG_RESET, c, Detail, _LOG_RESET)
    flush(stdout)
end

# --------------------------------------------------------------------------------------
# SECTION 3: EXCEL I/O ENGINE
# --------------------------------------------------------------------------------------

"""
    FAST_NormalizeCols_DDEF(df::DataFrame) -> DataFrame
Standardizes input column names to internal English format.
"""
FAST_NormalizeCols_DDEF(df::DataFrame) = df

"""
    FAST_ReadExcel_DDEF(FilePath, SheetName) -> DataFrame
Safely reads an Excel sheet and normalizes its columns.
"""
function FAST_ReadExcel_DDEF(FilePath::String, SheetName::String)
    try
        if !isfile(FilePath)
            FAST_Log_DDEF("FAST", "Error", "File not found: $FilePath", "FAIL")
            return DataFrame()
        end

        df = DataFrame(XLSX.readtable(FilePath, SheetName))
        FAST_Log_DDEF("FAST", "IO Read", "$(nrow(df)) rows from [$SheetName]", "OK")
        return FAST_NormalizeCols_DDEF(df)
    catch e
        FAST_Log_DDEF("FAST", "IO Error", "ReadExcel: $(string(e))", "FAIL")
        return DataFrame()
    end
end

"""
    _round_float_cols!(df::DataFrame)
Round all floating-point columns in-place to 3 decimal digits.
"""
function _round_float_cols!(df::DataFrame)
    for col in names(df)
        T = eltype(df[!, col])
        if T <: Union{Missing,AbstractFloat} || T <: AbstractFloat
            df[!, col] = round.(df[!, col]; digits=3)
        end
    end
    return df
end

"""
    FAST_PrepareDownload_DDEF(FilePath) -> (Success, Content)
Reads file contents for web download action.
"""
function FAST_PrepareDownload_DDEF(FilePath::String)
    try
        isfile(FilePath) || return (false, UInt8[])
        return (true, read(FilePath))
    catch
        return (false, UInt8[])
    end
end

# --------------------------------------------------------------------------------------
# SECTION 4: UTILITIES & SYSTEM DEFAULTS
# --------------------------------------------------------------------------------------

"""
    FAST_SafeNum_DDEF(Input) -> Float64
Robust numeric conversion handling missing, strings, and commas.
Guarantees a Float64 return under ALL circumstances — the core type-safety gate.
"""
function FAST_SafeNum_DDEF(Input)
    (Input === missing || Input === nothing) && return NaN
    Input isa Float64 && return Input
    Input isa Number && return Float64(Input)
    s = strip(string(Input))
    (isempty(s) || s == "-" || lowercase(s) == "nan") && return NaN
    return something(tryparse(Float64, replace(s, ',' => '.')), NaN)
end

"""
    FAST_SanitizeInput_DDEF(rows::AbstractVector) -> (Vector{Dict}, Vector{String})
Batch-level type coercion for Dash JSON inputs.
Returns (clean_rows, warnings) — warnings list all fields where
invalid/blank inputs were silently defaulted, so the UI can alert the user.
"""
function FAST_SanitizeInput_DDEF(rows::AbstractVector)
    sanitized = Dict{String,Any}[]
    warnings = String[]
    for (idx, raw) in enumerate(rows)
        r = Dict{String,Any}(string(k) => v for (k, v) in raw)
        # String fields — guarantee non-nothing
        r["Name"] = string(get(r, "Name", "Unknown"))
        r["Role"] = string(get(r, "Role", "Variable"))
        r["Unit"] = string(get(r, "Unit", ""))
        r["HalfLifeUnit"] = string(get(r, "HalfLifeUnit", "Hours"))

        # Boolean Fields
        r["IsRadioactive"] = get(r, "IsRadioactive", false) == true
        r["IsFiller"] = get(r, "IsFiller", false) == true

        row_label = r["Name"]
        # Numeric fields — guarantee Float64 via safe gate
        for key in ("L1", "L2", "L3", "MW", "Min", "Max", "Target", "HalfLife")
            v = get(r, key, nothing)
            fv = FAST_SafeNum_DDEF(v)
            if isnan(fv) && !isnothing(v) && v !== missing && string(v) != ""
                # Non-blank input that failed to parse → user error!
                push!(warnings, "Row '$(row_label)' field '$(key)': '$(v)' → 0.0 (invalid)")
                r[key] = 0.0
            elseif isnan(fv)
                r[key] = 0.0  # Blank/missing → silent default
            else
                r[key] = fv
            end
        end
        push!(sanitized, r)
    end
    if !isempty(warnings)
        FAST_Log_DDEF("FAST", "INPUT_WARN",
            "$(length(warnings)) field(s) had invalid inputs", "WARN")
    end
    return sanitized, warnings
end

"""
    FAST_GetLabDefaults_DDEF() -> Dict
Returns an explicitly empty experimental setup for a new laboratory session (blank canvas).
"""
function FAST_GetLabDefaults_DDEF()
    return Dict(
        "Inputs" => [
            Dict("Name" => "Var_A", "Role" => "Variable", "Levels" => [10.0, 20.0, 30.0], "MW" => 150.0, "Unit" => "mg"),
            Dict("Name" => "Var_B", "Role" => "Variable", "Levels" => [1.0, 5.0, 9.0], "MW" => 300.0, "Unit" => "mM"),
            Dict("Name" => "Var_C", "Role" => "Variable", "Levels" => [4.0, 7.0, 10.0], "MW" => 50.0, "Unit" => "pH"),
        ],
        "Outputs" => [
            Dict("Name" => "Size", "Unit" => "nm"),
            Dict("Name" => "PDI", "Unit" => "a.u."),
            Dict("Name" => "Zeta", "Unit" => "mV"),
        ],
    )
end

"""
    FAST_SanitizeJSON_DDEF(x)
Recursively replaces NaNs with null for JSON compatibility.
"""
function FAST_SanitizeJSON_DDEF(x)
    x isa AbstractFloat && isnan(x) && return nothing
    x isa Dict && return Dict(k => FAST_SanitizeJSON_DDEF(v) for (k, v) in x)
    x isa AbstractVector && return map(FAST_SanitizeJSON_DDEF, x)
    return x
end

"""
    FAST_InitMaster_DDEF(File, InNames, OutNames, DesignData, Config) -> Bool
Initializes or updates the master Excel record with headers and config.
Supports appending new phases if the file already exists.
"""
function FAST_InitMaster_DDEF(File::String, InNames::Vector{String}, OutNames::Vector{String},
    DesignData::Union{DataFrame,Nothing}=nothing, Config::Dict{String,Any}=Dict{String,Any}())
    try
        C = CONST_DATA
        FAST_Log_DDEF("FAST", "Init Master", "Target: $File", "WAIT")

        # 1. Base Meta Columns (Strict Order)
        headers = [C.COL_EXP_ID, C.COL_PHASE, C.COL_STATUS, C.COL_NOTES]

        # 2. Extract and Categorise provided data columns
        if !isnothing(DesignData)
            data_cols = names(DesignData)
            for col in data_cols
                if startswith(col, C.PRE_MASS) && col ∉ headers
                    push!(headers, col)
                end
            end
            for name in InNames, pfx in (C.PRE_INPUT, C.PRE_FIXED, C.PRE_FILL)
                col = pfx * name
                if col ∈ data_cols && col ∉ headers
                    push!(headers, col)
                end
            end
        else
            for n in InNames
                push!(headers, C.PRE_MASS * n * "_mg")
                push!(headers, C.PRE_INPUT * n)
            end
        end

        # 3. Append Performance/Result/Prediction/Score
        for n in OutNames
            push!(headers, C.PRE_RESULT * n)
        end
        for n in OutNames
            push!(headers, C.PRE_PRED * n)
        end
        push!(headers, C.COL_SCORE)

        # 4. Data Integration (Smart Appending)
        df_new = isnothing(DesignData) ? DataFrame(Dict(h => [] for h in headers)) : copy(DesignData)

        for col in setdiff(headers, names(df_new))
            df_new[!, col] = fill(missing, nrow(df_new))
        end
        df_final_data = select!(df_new, headers)

        if isfile(File) && !isnothing(DesignData)
            try
                df_old = FAST_ReadExcel_DDEF(File, C.SHEET_DATA)
                if !isempty(df_old)
                    for col in setdiff(headers, names(df_old))
                        df_old[!, col] = fill(missing, nrow(df_old))
                    end
                    df_final_data = vcat(select!(df_old, headers), df_final_data)
                end
            catch e
                FAST_Log_DDEF("FAST", "Merge Warning", "Could not read existing data: $e", "WARN")
            end
        end

        _round_float_cols!(df_final_data)

        # 5. File Construction
        XLSX.openxlsx(File; mode=isfile(File) ? "rw" : "w") do xf
            # DATA SHEET
            sheet_data = C.SHEET_DATA
            if isfile(File) && sheet_data ∈ XLSX.sheetnames(xf)
                XLSX.writetable!(xf[sheet_data], df_final_data; anchor_cell=XLSX.CellRef("A1"))
            else
                ws = isfile(File) ? XLSX.addsheet!(xf, sheet_data) : xf[1]
                isfile(File) || XLSX.rename!(ws, sheet_data)
                XLSX.writetable!(ws, df_final_data; anchor_cell=XLSX.CellRef("A1"))
            end

            # CONFIG SHEET
            sheet_conf = C.SHEET_CONFIG
            clean_config = FAST_SanitizeJSON_DDEF(Config)
            json_str = isempty(Config) ? "{}" : JSON3.write(clean_config)
            config_df = DataFrame(
                "PARAMETER" => ["MasterConfig"],
                "VALUE_JSON" => [json_str],
                "UPDATED_AT" => [string(now())],
            )

            if sheet_conf ∈ XLSX.sheetnames(xf)
                XLSX.writetable!(xf[sheet_conf], config_df)
            else
                XLSX.addsheet!(xf, sheet_conf)
                XLSX.writetable!(xf[sheet_conf], config_df)
            end
        end

        return true
    catch e
        bt = sprint(showerror, e, catch_backtrace())
        FAST_Log_DDEF("FAST", "INIT_MASTER_FAIL", bt, "FAIL")
        return false
    end
end

"""
    FAST_WriteLeaders_DDEF(File::String, Phase::String, LeadersDF::DataFrame)
Writes the candidate set back to the Master File for the Next Phase transition.
"""
function FAST_WriteLeaders_DDEF(File::String, Phase::String, LeadersDF::DataFrame)
    try
        isfile(File) || return false
        sheet_name = CONST_DATA.PREFIX_LEADERS * Phase
        XLSX.openxlsx(File; mode="rw") do xf
            if sheet_name ∈ XLSX.sheetnames(xf)
                XLSX.writetable!(xf[sheet_name], LeadersDF)
            else
                XLSX.addsheet!(xf, sheet_name)
                XLSX.writetable!(xf[sheet_name], LeadersDF)
            end
        end
        return true
    catch e
        FAST_Log_DDEF("FAST", "WRITE_LEADERS_FAIL", sprint(showerror, e, catch_backtrace()), "FAIL")
        return false
    end
end

"""
    FAST_GenerateSmartName_DDEF(Project, Phase, Status) -> String
Generates a unique, descriptive filename according to the DDE protocol.
"""
function FAST_GenerateSmartName_DDEF(Project::String, Phase::String, Status::String)
    p_clean = isempty(strip(Project)) ? "Daisho" : replace(strip(Project), " " => "_")
    ph_clean = replace(Phase, "Phase" => "P")
    ts = Dates.format(now(), "yyyy_mmdd_HHMM")
    return "DDE_$(p_clean)_$(ph_clean)_$(Status)_$(ts).xlsx"
end

"""
    FAST_GetTransientPath_DDEF(Base64Content=nothing) -> String
Creates a temporary file path and optionally writes content to it.
"""
function FAST_GetTransientPath_DDEF(Base64Content::Union{String,Nothing}=nothing)
    tmp_path = joinpath(tempdir(), "DDE_TEMP_$(Dates.format(now(), "HHmmss_SSS"))_$(rand(1000:9999)).xlsx")
    if !isnothing(Base64Content)
        write(tmp_path, base64decode(split(Base64Content, ',')[end]))
    end
    return tmp_path
end

"""
    FAST_ReadToStore_DDEF(Path) -> String
Reads a file and returns its Base64 representation for browser storage.
"""
function FAST_ReadToStore_DDEF(Path::String)
    try
        isfile(Path) || return ""
        return "data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64," * base64encode(read(Path))
    catch
        return ""
    end
end

"""
    FAST_ReadConfig_DDEF(File::String) -> Dict{String, Any}
Reads the MasterConfig from an existing Excel file's CONFIG sheet.
"""
function FAST_ReadConfig_DDEF(File::String)
    try
        C = CONST_DATA
        df = FAST_ReadExcel_DDEF(File, C.SHEET_CONFIG)
        isempty(df) && return Dict{String,Any}()

        hasproperty(df, :PARAMETER) || return Dict{String,Any}()
        idx = findfirst(==("MasterConfig"), string.(df[!, :PARAMETER]))
        isnothing(idx) && return Dict{String,Any}()

        json_str = df[idx, :VALUE_JSON]
        return JSON3.read(string(json_str), Dict{String,Any})
    catch e
        FAST_Log_DDEF("FAST", "READ_CONFIG_FAIL", "Error reading config from $File: $e", "WARN")
        return Dict{String,Any}()
    end
end

"""
    FAST_GetThreadInfo_DDEF() -> (Count, StatusColor, Msg)
Detects the current Julia thread count and provides optimisation feedback.
"""
function FAST_GetThreadInfo_DDEF()
    n = Threads.nthreads()
    return n > 1 ?
           (n, "success", "$n Threads (Optimal)") :
           (n, "warning", "1 Thread (Limited - Use --threads auto)")
end

# --------------------------------------------------------------------------------------
# SECTION 5: RACE CONDITION LOCK
# --------------------------------------------------------------------------------------

# Global atomic lock pool — keyed by operation name
const _OPERATION_LOCKS = Dict{String,ReentrantLock}()
const _LOCK_GUARD = ReentrantLock()           # Meta-lock for the pool itself

"""
    FAST_AcquireLock_DDEF(op_name) -> Bool
Tries to acquire a named operation lock without blocking.
Returns `true` if the lock was acquired (caller owns it),
or `false` if the operation is already running (reject/queue the request).
"""
function FAST_AcquireLock_DDEF(op_name::String)::Bool
    lock(_LOCK_GUARD) do
        haskey(_OPERATION_LOCKS, op_name) || (_OPERATION_LOCKS[op_name] = ReentrantLock())
    end
    lk = _OPERATION_LOCKS[op_name]
    return trylock(lk)
end

"""
    FAST_ReleaseLock_DDEF(op_name)
Releases the named operation lock after the computation finishes.
"""
function FAST_ReleaseLock_DDEF(op_name::String)
    haskey(_OPERATION_LOCKS, op_name) || return
    lk = _OPERATION_LOCKS[op_name]
    islocked(lk) && unlock(lk)
end

"""
    FAST_IsLocked_DDEF(op_name) -> Bool
Check whether a named operation is currently running.
"""
function FAST_IsLocked_DDEF(op_name::String)::Bool
    lock(_LOCK_GUARD) do
        haskey(_OPERATION_LOCKS, op_name) || return false
        return islocked(_OPERATION_LOCKS[op_name])
    end
end

# --------------------------------------------------------------------------------------
# SECTION 6: IN-MEMORY TRANSIENT CACHE
# --------------------------------------------------------------------------------------

# Thread-safe in-memory DataFrame cache — keyed by (file_tag, sheet_name)
const _CACHE_STORE = Dict{String,DataFrame}()
const _CACHE_LOCK = ReentrantLock()

"""
    FAST_CacheRead_DDEF(key) -> Union{DataFrame, Nothing}
Thread-safe read from the in-memory cache.
Returns `nothing` if the key does not exist.
"""
function FAST_CacheRead_DDEF(key::String)::Union{DataFrame,Nothing}
    lock(_CACHE_LOCK) do
        haskey(_CACHE_STORE, key) ? copy(_CACHE_STORE[key]) : nothing
    end
end

"""
    FAST_CacheWrite_DDEF(key, df)
Thread-safe write to the in-memory cache.
Stores a deep copy to prevent external mutation of cached data.
"""
function FAST_CacheWrite_DDEF(key::String, df::DataFrame)
    lock(_CACHE_LOCK) do
        _CACHE_STORE[key] = copy(df)
    end
    FAST_Log_DDEF("CACHE", "WRITE", "Cached '$(key)' ($(nrow(df)) rows)", "OK")
end

"""
    FAST_CacheEvict_DDEF(key="")
Evicts a specific key or clears the entire cache if key is empty.
"""
function FAST_CacheEvict_DDEF(key::String="")
    lock(_CACHE_LOCK) do
        if isempty(key)
            empty!(_CACHE_STORE)
            FAST_Log_DDEF("CACHE", "FLUSH", "Entire cache cleared.", "WARN")
        elseif haskey(_CACHE_STORE, key)
            delete!(_CACHE_STORE, key)
            FAST_Log_DDEF("CACHE", "EVICT", "Evicted '$key'", "INFO")
        end
    end
end

# --------------------------------------------------------------------------------------
# SECTION 7: COMPUTE THREAD POOL LIMITER
# --------------------------------------------------------------------------------------

"""
    FAST_GetComputeThreads_DDEF() -> Int
Returns the number of threads available for heavy computation,
reserving at least 1 thread for the HTTP server event loop.
"""
function FAST_GetComputeThreads_DDEF()::Int
    total = Threads.nthreads()
    return max(1, total - 1)  # Reserve 1 for HTTP
end

"""
    FAST_SpawnCompute_DDEF(fn::Function) -> Task
Spawns a heavy computation on a background thread via `Threads.@spawn`,
allowing the Dash HTTP server to remain responsive.
The caller should `fetch(task)` to get the result.
"""
function FAST_SpawnCompute_DDEF(fn::Function)
    return Threads.@spawn begin
        try
            fn()
        catch e
            bt = sprint(showerror, e, catch_backtrace())
            FAST_Log_DDEF("COMPUTE", "TASK_FAIL", bt, "FAIL")
            rethrow(e)
        end
    end
end

end # module Sys_Fast
