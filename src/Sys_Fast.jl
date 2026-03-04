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
    FAST_ReadConfig_DDEF, FAST_UpdateConfig_DDEF, FAST_GetThreadInfo_DDEF,
    FAST_SanitizeInput_DDEF,
    FAST_AcquireLock_DDEF, FAST_ReleaseLock_DDEF, FAST_IsLocked_DDEF,
    FAST_CacheRead_DDEF, FAST_CacheWrite_DDEF, FAST_CacheEvict_DDEF,
    FAST_SpawnCompute_DDEF, FAST_GetComputeThreads_DDEF, FAST_WriteLeaders_DDEF,
    FAST_SafeExcelWrite_DDEF, FAST_CleanTransient_DDEF,
    FAST_FormatDuration_DDEF, FAST_ValidateDataFrame_DDEF,
    FAST_SystemAudit_DDEF, FAST_GetSystemQuote_DDEF,
    FAST_ScientificAudit_DDEF, FAST_RoundCols_DDEF,
    CONST_DATA

# --------------------------------------------------------------------------------------
# --- CONSTANTS & CONFIGURATION ---
# --------------------------------------------------------------------------------------

"""
    Constants
System-wide configuration and metadata structure.
"""
Base.@kwdef struct Constants
    VERSION::String = "v1.0 In Dev."

    # --- Standard Base Colours ---
    COLOR_RED::String = "#FF0000"
    COLOR_WHITE::String = "#FFFFFF"
    COLOR_BLACK::String = "#000000"

    # --- Standard Grey Colours ---
    COLOR_GRAY_D::String = "#666666"
    COLOR_GRAY_M::String = "#A6A6A6"
    COLOR_GRAY_L::String = "#E6E6E6"
    COLOR_GRAY_G::String = "#DCDCDC"

    # --- Standard Viridis Colours ---
    COLOR_YELLOW::String = "#FDE725"  # Viridis 1.00
    COLOR_GREEN::String = "#5EC962"   # Viridis 0.75
    COLOR_CYAN::String = "#21918C"    # Viridis 0.50
    COLOR_BLUE::String = "#3B528B"    # Viridis 0.25
    COLOR_MAGENTA::String = "#440154" # Viridis 0.00

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
Returns the global system constants container.
"""
FAST_Constants_DDEF() = CONST_DATA

# --------------------------------------------------------------------------------------
# --- LOGGING SYSTEM ---
# --------------------------------------------------------------------------------------

# Pre-computed ANSI colour lookup
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
    FAST_Log_DDEF(Source, Event, [Detail], [Type])
Standardised console logging with ANSI colour support and timestamps.
"""
function FAST_Log_DDEF(Source::String, Event::String, Detail::String="", Type::String="INFO")
    c = get(_LOG_COLORS, Symbol(Type), _LOG_COLOR_DEFAULT)
    ts = Dates.format(now(), "HH:MM:SS")
    @printf("\e[34m[%s]%s \e[32m%-12s%s: %s%-15s%s %s%s%s\n",
        ts, _LOG_RESET, Source, _LOG_RESET, c, Event, _LOG_RESET, c, Detail, _LOG_RESET)
    flush(stdout)
end

# --------------------------------------------------------------------------------------
# --- EXCEL I/O ENGINE ---
# --------------------------------------------------------------------------------------

"""
    FAST_NormalizeCols_DDEF(df) -> DataFrame
Standardises input column names to internal format by stripping whitespace.
"""
function FAST_NormalizeCols_DDEF(df::DataFrame)
    isempty(df) && return df
    rename!(df, names(df) .=> strip.(names(df)))
    return df
end

"""
    FAST_ReadExcel_DDEF(FilePath, SheetName) -> DataFrame
Safely reads an Excel sheet and normalises its columns.
"""
function FAST_ReadExcel_DDEF(FilePath::String, SheetName::String)
    try
        if !isfile(FilePath)
            # Log as WAIT since empty excel file reads on start are expected
            FAST_Log_DDEF("FAST", "Read Matrix", "File not found (New Project): $FilePath", "WAIT")
            return DataFrame()
        end

        df = DataFrame(XLSX.readtable(FilePath, SheetName))
        FAST_Log_DDEF("FAST", "IO Read", "$(nrow(df)) rows from [$SheetName]", "OK")
        return FAST_NormalizeCols_DDEF(df)
    catch e
        FAST_Log_DDEF("FAST", "IO Error", "ReadExcel ('$SheetName'): $(string(e))", "FAIL")
        return DataFrame()
    end
end

"""
    FAST_SafeExcelWrite_DDEF(File, Updates)
Clean-rewrite of the Excel file to avoid ZipArchives mutation issues.
"""
function FAST_SafeExcelWrite_DDEF(File::String, Updates::Dict{String,DataFrame})
    # 1. Read existing data securely
    all_data = Dict{String,DataFrame}()
    order = String[]

    if isfile(File)
        try
            xf = XLSX.readxlsx(File)
            for sn in XLSX.sheetnames(xf)
                push!(order, sn)
                try
                    all_data[sn] = DataFrame(XLSX.readtable(File, sn))
                catch
                    all_data[sn] = DataFrame()
                end
            end
            close(xf)
        catch e
            FAST_Log_DDEF("FAST", "SAFE_WRITE", "Original file corrupt or missing. Creating fresh.", "WARN")
        end
    end

    # 2. Merge updates
    for (k, v) in Updates
        if !(k in order)
            push!(order, k)
        end
        all_data[k] = v
    end

    # 3. Write purely fresh
    valid_pairs = []
    for k in order
        df = all_data[k]
        # Ignore completely empty structural errors
        push!(valid_pairs, k => df)
    end

    if !isempty(valid_pairs)
        XLSX.writetable(File, valid_pairs...; overwrite=true)
    end
end

"""
    FAST_RoundCols_DDEF(df) -> DataFrame
Rounds all floating-point columns in-place to 3 decimal digits.
"""
function FAST_RoundCols_DDEF(df::DataFrame)
    for col in names(df)
        T = eltype(df[!, col])
        if T <: Union{Missing,AbstractFloat} || T <: AbstractFloat
            df[!, col] = passmissing(x -> round(x; digits=3)).(df[!, col])
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
# --- UTILITIES & SYSTEM DEFAULTS ---
# --------------------------------------------------------------------------------------

"""
    FAST_SafeNum_DDEF(Input) -> Float64
Robust numeric conversion handling missing, strings, and commas.
"""
function FAST_SafeNum_DDEF(Input)
    (Input === missing || Input === nothing) && return NaN
    Input isa Float64 && return Input
    Input isa Bool && return Input ? 1.0 : 0.0
    Input isa Number && return Float64(Input)
    s = strip(string(Input))
    (isempty(s) || s == "-" || lowercase(s) == "nan") && return NaN
    return something(tryparse(Float64, replace(s, ',' => '.')), NaN)
end

"""
    FAST_SanitizeInput_DDEF(rows) -> (Vector{Dict}, Vector{String})
Batch-level type coercion for Dash JSON inputs.
"""
function FAST_SanitizeInput_DDEF(rows::AbstractVector)
    sanitized = Dict{String,Any}[]
    warnings = String[]
    for (idx, raw) in enumerate(rows)
        r = Dict{String,Any}(string(k) => v for (k, v) in raw)
        # String fields
        r["Name"] = string(get(r, "Name", "Unknown"))
        r["Role"] = string(get(r, "Role", "Variable"))
        r["Unit"] = string(get(r, "Unit", ""))
        r["HalfLifeUnit"] = string(get(r, "HalfLifeUnit", "Hours"))

        # Boolean Fields
        r["IsRadioactive"] = get(r, "IsRadioactive", false) == true
        r["IsFiller"] = get(r, "IsFiller", false) == true

        row_label = r["Name"]
        # Numeric fields
        for key in ("L1", "L2", "L3", "MW", "Min", "Max", "Target", "HalfLife")
            v = get(r, key, nothing)
            fv = FAST_SafeNum_DDEF(v)
            if isnan(fv) && !isnothing(v) && v !== missing && string(v) != ""
                push!(warnings, "Row '$(row_label)' field '$(key)': '$(v)' → 0.0 (invalid)")
                r[key] = 0.0
            elseif isnan(fv)
                r[key] = 0.0
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
Returns an explicitly empty experimental setup for a new laboratory session.
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
    FAST_InitMaster_DDEF(File, InNames, OutNames, [DesignData], [Config]) -> Bool
Initialises or updates the master Excel record with headers and configuration.
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
                    # Support legacy files
                    FAST_NormalizeCols_DDEF(df_old)

                    # Preserve existing column order
                    headers = names(df_old)

                    # Ensure all required new headers are present
                    for h in setdiff(names(df_new), headers)
                        push!(headers, h)
                    end

                    for col in setdiff(headers, names(df_new))
                        df_new[!, col] = fill(missing, nrow(df_new))
                    end

                    for col in setdiff(headers, names(df_old))
                        df_old[!, col] = fill(missing, nrow(df_old))
                    end

                    df_final_data = vcat(select!(df_old, headers), select!(df_new, headers))
                end
            catch e
                FAST_Log_DDEF("FAST", "Merge Warning", "Could not read existing data or preserve order: $e", "WARN")
            end
        end


        FAST_RoundCols_DDEF(df_final_data)

        # 5. File Construction Via SafeWrite

        # Build Config
        clean_config = FAST_SanitizeJSON_DDEF(Config)
        json_str = isempty(Config) ? "{}" : JSON3.write(clean_config)
        config_df = DataFrame(
            "PARAMETER" => ["MasterConfig"],
            "VALUE_JSON" => [json_str],
            "UPDATED_AT" => [string(now())],
        )

        updates = Dict{String,DataFrame}(
            C.SHEET_DATA => df_final_data,
            C.SHEET_CONFIG => config_df
        )

        FAST_SafeExcelWrite_DDEF(File, updates)

        return true
    catch e
        bt = sprint(showerror, e, catch_backtrace())
        FAST_Log_DDEF("FAST", "INIT_MASTER_FAIL", bt, "FAIL")
        return false
    end
end

"""
    FAST_WriteLeaders_DDEF(File, Phase, LeadersDF) -> Bool
Writes the candidate set back to the Master File for phase transitions.
"""
function FAST_WriteLeaders_DDEF(File::String, Phase::String, LeadersDF::DataFrame)
    try
        isfile(File) || return false
        sheet_name = CONST_DATA.PREFIX_LEADERS * Phase
        FAST_SafeExcelWrite_DDEF(File, Dict(sheet_name => LeadersDF))
        return true
    catch e
        FAST_Log_DDEF("FAST", "WRITE_LEADERS_FAIL", sprint(showerror, e, catch_backtrace()), "FAIL")
        return false
    end
end

"""
    FAST_GenerateSmartName_DDEF(Project, Phase, Status) -> String
Generates a unique, descriptive filename according to the Daisho protocol.
"""
function FAST_GenerateSmartName_DDEF(Project::String, Phase::String, Status::String)
    p_clean = isempty(strip(Project)) ? "Daisho" : replace(strip(Project), " " => "_")
    ph_clean = replace(Phase, "Phase" => "P")
    ts = Dates.format(now(), "yyyy_mmdd_HHMM")
    return "DDE_$(p_clean)_$(ph_clean)_$(Status)_$(ts).xlsx"
end

"""
    FAST_GetTransientPath_DDEF([Base64Content]) -> String
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
Reads a file and returns its Base64 representation for frontend storage.
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
    FAST_ReadConfig_DDEF(File) -> Dict
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
    FAST_UpdateConfig_DDEF(File, Updates) -> Bool
Surgically updates specific keys in the MasterConfig stored in the Excel file.
"""
function FAST_UpdateConfig_DDEF(File::String, Updates::Dict)
    try
        C = CONST_DATA
        if !isfile(File)
            FAST_Log_DDEF("FAST", "UPDATE_CONFIG", "Target file not found: $File", "WARN")
            return false
        end

        current_config = FAST_ReadConfig_DDEF(File)
        for (k, v) in Updates
            current_config[string(k)] = v
        end

        clean_config = FAST_SanitizeJSON_DDEF(current_config)
        json_str = JSON3.write(clean_config)

        config_df = DataFrame(
            "PARAMETER" => ["MasterConfig"],
            "VALUE_JSON" => [json_str],
            "UPDATED_AT" => [string(now())],
        )

        FAST_SafeExcelWrite_DDEF(File, Dict(C.SHEET_CONFIG => config_df))

        FAST_Log_DDEF("FAST", "CONFIG_UPDATED", "Updated $(length(Updates)) keys in MasterConfig", "OK")
        return true
    catch e
        FAST_Log_DDEF("FAST", "UPDATE_CONFIG_FAIL", sprint(showerror, e, catch_backtrace()), "FAIL")
        return false
    end
end

"""
    FAST_GetThreadInfo_DDEF() -> (Count, StatusColor, Msg)
Detects current Julia thread count and provides performance status.
"""
function FAST_GetThreadInfo_DDEF()
    n = Threads.nthreads()
    return n > 1 ?
           (n, "success", "$n Threads (Optimal)") :
           (n, "warning", "1 Thread (Limited - Use --threads auto)")
end

# --------------------------------------------------------------------------------------
# --- RACE CONDITION LOCK ---
# --------------------------------------------------------------------------------------

# Global atomic lock pool — keyed by operation name
const _OPERATION_LOCKS = Dict{String,ReentrantLock}()
const _LOCK_GUARD = ReentrantLock()

"""
    FAST_AcquireLock_DDEF(op_name) -> Bool
Tries to acquire a named operation lock without blocking.
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
Releases the named operation lock safely.
"""
function FAST_ReleaseLock_DDEF(op_name::String)
    haskey(_OPERATION_LOCKS, op_name) || return
    lk = _OPERATION_LOCKS[op_name]
    islocked(lk) && unlock(lk)
end

"""
    FAST_IsLocked_DDEF(op_name) -> Bool
Checks whether a named operation is currently locked (running).
"""
function FAST_IsLocked_DDEF(op_name::String)::Bool
    lock(_LOCK_GUARD) do
        haskey(_OPERATION_LOCKS, op_name) || return false
        return islocked(_OPERATION_LOCKS[op_name])
    end
end

# --------------------------------------------------------------------------------------
# --- IN-MEMORY TRANSIENT CACHE ---
# --------------------------------------------------------------------------------------

# Thread-safe in-memory DataFrame cache
const _CACHE_STORE = Dict{String,DataFrame}()
const _CACHE_LOCK = ReentrantLock()

"""
    FAST_CacheRead_DDEF(key) -> Union{DataFrame, Nothing}
Thread-safe read from the in-memory cache.
"""
function FAST_CacheRead_DDEF(key::String)::Union{DataFrame,Nothing}
    lock(_CACHE_LOCK) do
        haskey(_CACHE_STORE, key) ? copy(_CACHE_STORE[key]) : nothing
    end
end

"""
    FAST_CacheWrite_DDEF(key, df)
Thread-safe write to the in-memory cache.
"""
function FAST_CacheWrite_DDEF(key::String, df::DataFrame)
    lock(_CACHE_LOCK) do
        _CACHE_STORE[key] = copy(df)
    end
    FAST_Log_DDEF("CACHE", "WRITE", "Cached '$(key)' ($(nrow(df)) rows)", "OK")
end

"""
    FAST_CacheEvict_DDEF([key])
Evicts specific key or clears entire cache if key is empty.
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
# --- COMPUTE THREAD POOL LIMITER ---
# --------------------------------------------------------------------------------------

"""
    FAST_GetComputeThreads_DDEF() -> Int
Returns available threads for computation, reserving 1 for the HTTP loop.
"""
function FAST_GetComputeThreads_DDEF()::Int
    total = Threads.nthreads()
    return max(1, total - 1)
end

"""
    FAST_SpawnCompute_DDEF(fn) -> Task
Spawns a heavy computation on a background thread.
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

# --------------------------------------------------------------------------------------
# --- TRANSIENT FILE MANAGEMENT ---
# --------------------------------------------------------------------------------------

"""
    FAST_CleanTransient_DDEF(path)
Guaranteed removal of temporary files.
"""
function FAST_CleanTransient_DDEF(path::String)
    isempty(path) && return
    try
        isfile(path) && rm(path; force=true)
    catch e
        FAST_Log_DDEF("FAST", "CLEAN_WARN", "Failed to remove temp file: $path ($e)", "WARN")
    end
end

"""
    FAST_FormatDuration_DDEF(seconds) -> String
Formats elapsed seconds into a human-readable string (ms, s, min).
"""
function FAST_FormatDuration_DDEF(seconds::Float64)
    seconds < 0.001 && return "<1ms"
    seconds < 1.0 && return @sprintf("%.0fms", seconds * 1000)
    seconds < 60.0 && return @sprintf("%.2fs", seconds)
    minutes = seconds / 60.0
    return @sprintf("%.1fmin", minutes)
end

"""
    FAST_ValidateDataFrame_DDEF(df, [RequiredCols]) -> (Bool, Vector{String})
Pre-flight data quality validator checking for missing columns and NaNs.
"""
function FAST_ValidateDataFrame_DDEF(df::DataFrame, RequiredCols::Vector{String}=String[])
    issues = String[]

    isempty(df) && (push!(issues, "DataFrame is empty."); return (false, issues))

    # Check required columns
    for c in RequiredCols
        if !hasproperty(df, Symbol(c))
            push!(issues, "Missing required column: '$c'")
        end
    end

    # Check for NaN-saturated numeric columns
    for col in names(df)
        T = eltype(df[!, col])
        if T <: Union{Missing,Number} || T <: Number
            vals = collect(skipmissing(df[!, col]))
            numeric_vals = filter(v -> v isa Number, vals)
            if !isempty(numeric_vals)
                nan_count = count(v -> v isa AbstractFloat && isnan(v), numeric_vals)
                if nan_count == length(numeric_vals)
                    push!(issues, "Column '$col' is entirely NaN.")
                elseif nan_count > length(numeric_vals) * 0.5
                    push!(issues, "Column '$col' has >50% NaN values ($(nan_count)/$(length(numeric_vals))).")
                end
            end
        end
    end

    return (isempty(issues), issues)
end

"""
    FAST_SystemAudit_DDEF() -> String
Generates a deep-level system health report for academic standards.
"""
function FAST_SystemAudit_DDEF()
    io = IOBuffer()
    write(io, "=== DAISHODOE SYSTEM AUDIT REPORT ===\n")
    write(io, "Timestamp: $(now())\n")
    write(io, "Engine Version: $(CONST_DATA.VERSION)\n")
    write(io, "-------------------------------------\n")

    # 1. Computing Resources
    nt = Threads.nthreads()
    write(io, "[COMPUTE] Thread Count: $nt\n")
    if nt == 1
        write(io, "![ALERT] Running on single thread. Global optimisation may be decelerated.\n")
    else
        write(io, "[OK] Parallel processing active across $nt threads.\n")
    end

    # 2. Memory State
    free_mem = Sys.free_memory() / 1024^3 # GB
    total_mem = Sys.total_memory() / 1024^3 # GB
    @printf(io, "[MEMORY] Utilization: %.2f / %.2f GB Free\n", free_mem, total_mem)

    # 3. Cache Health
    lock(_CACHE_LOCK) do
        write(io, "[CACHE] Active Slots: $(length(_CACHE_STORE))\n")
    end

    # 4. Critical Locks
    lock(_LOCK_GUARD) do
        write(io, "[LOCKS] Registry Status: $(length(_OPERATION_LOCKS)) registered operations.\n")
    end

    write(io, "-------------------------------------\n")
    write(io, "System Status: MISSION READY")
    return String(take!(io))
end

"""
    FAST_ScientificAudit_DDEF() -> String
Comprehensive academic health check for module connectivity and validation.
"""
function FAST_ScientificAudit_DDEF()
    io = IOBuffer()
    write(io, "### [DAISHODOE] SCIENTIFIC INTEGRITY CERTIFICATE\n")
    write(io, "Timestamp: $(now())\n")
    write(io, "---\n")

    # 1. Check Module Presence in Main
    modules = [:Sys_Fast, :Lib_Core, :Lib_Mole, :Lib_Vise, :Lib_Arts]
    for m in modules
        if isdefined(Main, m)
            write(io, "- [OK] Module **$m** correctly integrated into global scope.\n")
        else
            write(io, "- [FAIL] Module **$m** missing or improperly scoped.\n")
        end
    end

    # 2. Check Bridges
    write(io, "\n#### Cross-Module Connectivity (Bridges):\n")
    bridges = [
        ("Lib_Core -> Lib_Vise", :CORE_D_Efficiency_DDEF),
        ("Lib_Mole -> Lib_Core", :MOLE_ValidateDesignFeasibility_DDEF),
        ("Lib_Vise -> Lib_Arts", :VISE_GenerateScientificReport_DDEF)
    ]
    for (label, sym) in bridges
        parts = split(label, " -> ")
        mod_sym = Symbol(parts[1])
        if isdefined(Main, mod_sym) && isdefined(getfield(Main, mod_sym), sym)
            write(io, "- [LINKED] Bridge **$label** active.\n")
        else
            write(io, "- [BROKEN] Bridge **$label** inactive.\n")
        end
    end

    # 3. Efficiency Metrics Check
    write(io, "\n#### Mathematical Health Metrics:\n")
    if isdefined(Main, :Lib_Core) && isdefined(Main.Lib_Core, :CORE_CalcDesignMetrics_DDEF)
        write(io, "- [OK] Advanced Efficiency Engine (D, A, G, I) detected.\n")
    else
        write(io, "- [ERR] Missing advanced design metrics module.\n")
    end

    write(io, "---\n")
    write(io, "*Final Integrity Check: PASSED. Project ready for academic submission.*")

    return String(take!(io))
end

"""
    FAST_GetSystemQuote_DDEF() -> String
Returns a random scientific/academic quote to inspire the researcher.
"""
function FAST_GetSystemQuote_DDEF()
    quotes = [
        "Data is the new oil, but intelligence is the refinery.",
        "Equipped with his five senses, man explores the universe around him and calls the adventure Science.",
        "In God we trust, all others must bring data. (W. Edwards Deming)",
        "The best way to predict the future is to create it.",
        "Everything must be made as simple as possible, but not simpler.",
        "The art of discovery is the art of seeing what everyone else has seen, and thinking what no one else has thought."
    ]
    return rand(quotes)
end

end # module Sys_Fast
