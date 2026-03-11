module Sys_Fast

# ======================================================================================
# DAISHODOE - SYSTEM FAST (IO & UTILS)
# ======================================================================================
# Purpose: High-speed I/O (Excel/XLSX), system-wide logging, and transient data orchestration.
# Module Tag: FAST
# ======================================================================================

using Dates
using Printf
using XLSX
using DataFrames
using JSON3
using Base64

export FAST_Log_DDEF, FAST_ReadExcel_DDEF,
    FAST_Constants_DDES, FAST_SafeNum_DDEF, FAST_GetLabDefaults_DDEF,
    FAST_InitialiseMaster_DDEF, FAST_NormaliseCols_DDEF!,
    FAST_SanitiseJson_DDEF, FAST_PrepareDownload_DDEF,
    FAST_GenerateSmartName_DDEF, FAST_GetTransientPath_DDEF, FAST_ReadToStore_DDEF,
    FAST_ReadConfig_DDEF, FAST_UpdateConfig_DDEF, FAST_GetThreadInfo_DDEF,
    FAST_SanitiseInput_DDEF,
    FAST_AcquireLock_DDEF, FAST_ReleaseLock_DDEF,
    FAST_CacheRead_DDEF, FAST_CacheWrite_DDEF, FAST_CacheEvict_DDEF,
    FAST_GetComputeThreads_DDEF,
    FAST_SafeExcelWrite_DDEF, FAST_CleanTransient_DDEF,
    FAST_FormatDuration_DDEF, FAST_ValidateDataFrame_DDEF,
    FAST_GetSystemQuote_DDEF,
    FAST_RoundCols_DDEF!,
    FAST_GetCol_DDEF,
    FAST_InitialiseWorkforce_DDEF, FAST_CleanWorkforce_DDEF,
    FAST_Data_DDEC

# --------------------------------------------------------------------------------------
# --- CONSTANTS & CONFIGURATION ---
# --------------------------------------------------------------------------------------

"""
    FAST_Constants_DDES
System-wide configuration and metadata structure. Daisho Palette.
"""
Base.@kwdef struct FAST_Constants_DDES
    VERSION::String        = "v1.0 In Dev."
    COLOUR_PURWHI::String  = "#FFFFFF"
    COLOUR_LIGHIG::String  = "#E6E6E6"
    COLOUR_LIGLOW::String  = "#DCDCDC"
    COLOUR_DARLOW::String  = "#A6A6A6"
    COLOUR_DARHIG::String  = "#666666"
    COLOUR_PURBLA::String  = "#000000"
    COLOUR_HUERED::String  = "#FF0000"
    COLOUR_SHAMAG::String  = "#440154"
    COLOUR_SHABLU::String  = "#3B528B"
    COLOUR_TONCYA::String  = "#21918C"
    COLOUR_TONGRE::String  = "#5EC962"
    COLOUR_HUEYEL::String  = "#FDE725"
    FONT_DEFAULT::String   = "Inter, sans-serif"
    SHEET_DATA::String     = "DATA"
    SHEET_CONFIG::String   = "CONFIG"
    PRE_INPUT::String      = "VARIA_"
    PRE_FIXED::String      = "FIXED_"
    PRE_FILL::String       = "FILL_"
    PRE_MASS::String       = "MASS_"
    PRE_RESULT::String     = "RESULT_"
    PRE_PRED::String       = "PRED_"
    PREFIX_LEADERS::String = "Leaders_"
    COL_EXP_ID::String     = "EXP_ID"
    COL_PHASE::String      = "PHASE"
    COL_RUN_ORDER::String  = "RUN_ORDER"
    COL_STATUS::String     = "STATUS"
    COL_SCORE::String      = "SCORE"
    COL_NOTES::String      = "NOTES"
    COL_ID::String         = "ID"
    ROLE_VAR::String       = "Variable"
    ROLE_FILL::String      = "Filler"
    ROLE_FIX::String       = "Fixed"
    METHOD_BB15::String    = "BB15"
    METHOD_TL09::String    = "TL09"
    METHOD_DOPT15::String  = "DOPT15"
    METHOD_DOPT09::String  = "DOPT09"
end

const FAST_Data_DDEC = FAST_Constants_DDES()

# --------------------------------------------------------------------------------------
# --- TRANSIENT STORAGE MANAGEMENT (ANTI-BLOAT) ---
# --------------------------------------------------------------------------------------

"""
    FAST_TempRoot_DDEC
Dedicated directory for all DaishoDoE transient operations to prevent AppData scattering.
"""
const FAST_TempRoot_DDEC = joinpath(tempdir(), "DaishoDoE_Workforce")

"""
    FAST_InitialiseWorkforce_DDEF()
Initialises global transient directories and purges legacy temporary files.
"""
function FAST_InitialiseWorkforce_DDEF()
    FAST_Log_DDEF("SYS", "Initialise", "Synchronising workforce directories...", "INFO")
    try
        if !isdir(FAST_TempRoot_DDEC)
            mkpath(FAST_TempRoot_DDEC)
            FAST_Log_DDEF("FAST", "WORKFORCE", "Created transient bunker: $FAST_TempRoot_DDEC", "OK")
        else
            FAST_CleanWorkforce_DDEF()
            FAST_Log_DDEF("FAST", "WORKFORCE", "Transient bunker scavenged and ready.", "OK")
        end
    catch e
        FAST_Log_DDEF("FAST", "WORKFORCE_FAIL", "Could not initialise temp directory: $e", "FAIL")
    end
end

function FAST_CleanWorkforce_DDEF(all::Bool=false)::Nothing
    !isdir(FAST_TempRoot_DDEC) && return nothing

    try
        targets = filter(isfile, readdir(FAST_TempRoot_DDEC; join=true))
        foreach(f -> rm(f; force=true), targets)

        all && FAST_Log_DDEF("FAST", "CLEAN_DEEP", "Extended workforce sweep executed.", "INFO")
    catch e
        FAST_Log_DDEF("FAST", "CLEAN_WARN", "Workforce scavenging lookup encountered obstacles: $e", "WARN")
    end
    
    return nothing
end

# --------------------------------------------------------------------------------------
# --- LOGGING SYSTEM ---
# --------------------------------------------------------------------------------------

# Pre-computed ANSI colour lookup
const FAST_LogColours_DDEC = (;
    INFO="\e[34m",
    OK="\e[32m",
    WARN="\e[33m",
    FAIL="\e[31m",
    WAIT="\e[36m",
    LIST="\e[37m",
)
const FAST_LogColourDefault_DDEC = "\e[34m"
const FAST_LogReset_DDEC = "\e[0m"

"""
    FAST_Log_DDEF(Source, Event, [Detail], [Type])
Standardised console logging with ANSI colour support and timestamps.
"""
function FAST_Log_DDEF(Source::String, Event::String, Detail::Any="", Type::String="INFO")
    c       = get(FAST_LogColours_DDEC, Symbol(Type), FAST_LogColourDefault_DDEC)
    ts      = Dates.format(now(), "HH:MM:SS.sss")
    det_str = isnothing(Detail) ? "null" : string(Detail)
    
    @printf("\e[34m[%s]%s \e[32m%-12s%s: %s%-15s%s %s%s%s\n",
        ts, FAST_LogReset_DDEC, Source, FAST_LogReset_DDEC, c, Event, FAST_LogReset_DDEC, c, det_str, FAST_LogReset_DDEC)
    
    flush(stdout)
end

# --------------------------------------------------------------------------------------
# --- EXCEL I/O ENGINE ---
# --------------------------------------------------------------------------------------

"""
    FAST_NormaliseCols_DDEF!(df::DataFrame)::DataFrame
Standardises DataFrame column names: Strips whitespace and forces Uppercase.
Mutates the DataFrame in-place for performance.
"""
function FAST_NormaliseCols_DDEF!(df::DataFrame; force_upper::Bool=false)::DataFrame
    isempty(df) && return df
    
    if force_upper
        mapping = [n => Symbol(uppercase(strip(string(n)))) for n in names(df)]
    else
        mapping = [n => Symbol(strip(string(n))) for n in names(df)]
    end
    
    rename!(df, mapping)
    return df
end

"""
    FAST_ReadExcel_DDEF(FilePath::String, SheetName::String)::DataFrame
Reads an Excel sheet into a DataFrame with normalised column names.
Returns an empty DataFrame if the file doesn't exist.
"""
function FAST_ReadExcel_DDEF(FilePath::Union{String,Nothing}, SheetName::String)::DataFrame
    (isnothing(FilePath) || isempty(FilePath) || !isfile(FilePath)) && return DataFrame()

    ext = lowercase(splitext(FilePath)[2])
    if ext != ".xlsx" && ext != ".xlsm"
        FAST_Log_DDEF("FAST", "IO_ERROR", "Selected file [$ext] is not a valid Excel (.xlsx/.xlsm) document.", "FAIL")
        return DataFrame()
    end

    try
        xf           = XLSX.readxlsx(FilePath)
        sheet_exists = SheetName ∈ XLSX.sheetnames(xf)

        if !sheet_exists
            FAST_Log_DDEF("FAST", "IO_ERROR", "Target sheet [$SheetName] not found in workbook.", "FAIL")
            return DataFrame()
        end

        df = DataFrame(XLSX.readtable(FilePath, SheetName))        
        
        is_data_sheet = SheetName == FAST_Data_DDEC.SHEET_DATA || startswith(SheetName, FAST_Data_DDEC.PREFIX_LEADERS)
        
        if is_data_sheet
            has_id = false
            has_ph = false
            for col in names(df)
                uc = uppercase(strip(string(col)))
                if uc == "EXP_ID" || uc == "ID"
                    has_id = true
                elseif uc == "PHASE"
                    has_ph = true
                end
            end
            
            if !has_id || !has_ph
                FAST_Log_DDEF("FAST", "FORMAT_FAIL", "Excel incompatible! Required columns (EXP_ID/ID or PHASE) missing in sheet [$SheetName].", "WARN")
                throw(ArgumentError("Incompatible Format in sheet [$SheetName]: Required columns not found."))
            end
        end

        FAST_Log_DDEF("FAST", "IO_READ", "$(nrow(df)) rows extracted from [$SheetName].", "OK")
        
        return FAST_NormaliseCols_DDEF!(df) 
    catch e
        FAST_Log_DDEF("FAST", "IO_ERROR", "Scientific I/O Failure: $(first(string(e), 150))", "FAIL")
        return DataFrame()
    end
end

"""
    FAST_SafeExcelWrite_DDEF(File::String, Updates::Dict{String,DataFrame})::Nothing
Rewrites Excel vault using a fresh buffer to prevent archive truncation.
"""
function FAST_SafeExcelWrite_DDEF(File::Union{String,Nothing}, Updates::Dict{String,DataFrame})::Nothing
    (isnothing(File) || isempty(File)) && return nothing
    
    all_data    = Dict{String,DataFrame}()
    sheet_order = String[]

    if isfile(File)
        try
            xf = XLSX.readxlsx(File)
            for sn in XLSX.sheetnames(xf)
                push!(sheet_order, sn)
                all_data[sn] = try
                    DataFrame(XLSX.readtable(File, sn))
                catch
                    DataFrame()
                end
            end
        catch e
            FAST_Log_DDEF("FAST", "SAFE_WRITE", "Reference file inaccessible. Initialising fresh.", "WARN")
        end
    end

    foreach(keys(Updates)) do k
        k ∉ sheet_order && push!(sheet_order, k)
        all_data[k] = Updates[k]
    end

    valid_pairs = [sn => all_data[sn] for sn in sheet_order if !isempty(all_data[sn]) || sn == "CONFIG"]

    if !isempty(valid_pairs)
        XLSX.writetable(File, valid_pairs...; overwrite=true)
    end
    
    return nothing
end

"""
    FAST_RoundCols_DDEF!(df::DataFrame)::DataFrame
Rounds float columns to academic standard (3 decimal places).
Mutates input for memory efficiency.
"""
function FAST_RoundCols_DDEF!(df::DataFrame)::DataFrame
    mapcols!(df) do col
        if eltype(col) <: Union{Missing,AbstractFloat}
            return passmissing(x -> round(x; digits=3)).(col)
        end
        return col
    end
    
    return df
end

"""
    FAST_PrepareDownload_DDEF(FilePath) -> (Success, Content)
Reads file contents for web download action.
"""
function FAST_PrepareDownload_DDEF(FilePath::Union{String,Nothing})
    try
        (isnothing(FilePath) || isempty(FilePath) || !isfile(FilePath)) && return (false, UInt8[])
        return (true, read(FilePath))
    catch
        return (false, UInt8[])
    end
end

# --------------------------------------------------------------------------------------
# --- UTILITIES & SYSTEM DEFAULTS ---
# --------------------------------------------------------------------------------------

"""
    FAST_SafeNum_DDEF(Input::Any)::Float64
Type-safe numeric conversion. Handles missing, nothing, and localised string formats.
"""
function FAST_SafeNum_DDEF(Input::Any)::Float64
    (Input === missing || Input === nothing) && return NaN

    Input isa AbstractFloat && return Float64(Input)
    Input isa Integer       && return Float64(Input)
    Input isa Bool          && return Input ? 1.0 : 0.0

    s::String = strip(string(Input))
    (isempty(s) || s == "-" || lowercase(s) == "nan") && return NaN

    # Handle comma/dot ambiguity
    clean_s = replace(s, ',' => '.')
    res     = tryparse(Float64, clean_s)
    
    return something(res, NaN)
end

"""
    FAST_SanitiseInput_DDEF(TableData::AbstractVector)::Tuple{Vector{Dict{String,Any}}, Vector{String}}
Transforms raw UI Table data into typed scientific Dictionaries.
Implements automatic feature recognition for radioactivity and filler logic.
"""
function FAST_SanitiseInput_DDEF(TableData::AbstractVector)::Tuple{Vector{Dict{String,Any}},Vector{String}}
    warnings = String[]

    sanitized = map(enumerate(TableData)) do (idx, raw)
        # Idiomatic key conversion
        r = Dict{String,Any}(string(k) => v for (k, v) in raw)

        # 1. Structural Normalisation
        row_name = string(get(r, "Name", "Unnamed_Item_$(idx)"))
        r["Name"] = row_name
        r["Role"] = string(get(r, "Role", "Variable"))
        r["Unit"] = string(get(r, "Unit", ""))
        r["HalfLifeUnit"] = string(get(r, "HalfLifeUnit", "Hours"))

        # Boolean Logic
        r["IsRadioactive"] = get(r, "IsRadioactive", false) == true
        r["IsFiller"] = get(r, "IsFiller", false) == true

        # 2. Safe Numeric Coercion Loop
        num_fields = ("L1", "L2", "L3", "MW", "Min", "Max", "Target", "HalfLife")
        for key in num_fields
            val = get(r, key, nothing)
            clean_val = FAST_SafeNum_DDEF(val)

            # Warn on data loss/corruption
            if isnan(clean_val) && !isnothing(val) && val !== missing && string(val) != ""
                push!(warnings, "Item '$row_name': Invalid input for '$key' ($val) coerced to 0.0")
            end
            r[key] = isnan(clean_val) ? 0.0 : clean_val
        end

        # 3. Intelligence Layers
        if r["HalfLife"] > 0.0
            r["IsRadioactive"] = true
        end

        return r
    end

    !isempty(warnings) && FAST_Log_DDEF("FAST", "SANITY", "Rectified $(length(warnings)) data anomalies.", "WARN")
    return (sanitized, warnings)
end

"""
    FAST_GetLabDefaults_DDEF()::Dict{String,Any}
Provides the canonical initial state for a fresh Daisho session.
"""
function FAST_GetLabDefaults_DDEF()::Dict{String,Any}
    # Using explicit types for standard return
    return Dict{String,Any}(
        "Inputs" => [
            Dict{String,Any}("Name" => "Var_A", "Role" => "Variable", "L1" => 10.0, "L2" => 20.0, "L3" => 30.0, "Min" => 0.0, "Max" => 50.0, "MW" => 150.0, "Unit" => "mg"),
            Dict{String,Any}("Name" => "Var_B", "Role" => "Variable", "L1" => 1.0, "L2" => 5.0, "L3" => 9.0, "Min" => 0.0, "Max" => 15.0, "MW" => 300.0, "Unit" => "mM"),
            Dict{String,Any}("Name" => "Var_C", "Role" => "Variable", "L1" => 4.0, "L2" => 7.0, "L3" => 10.0, "Min" => 0.0, "Max" => 14.0, "MW" => 50.0, "Unit" => "pH"),
        ],
        "Outputs" => [
            Dict{String,Any}("Name" => "Size", "Unit" => "nm"),
            Dict{String,Any}("Name" => "PDI", "Unit" => "a.u."),
            Dict{String,Any}("Name" => "Zeta", "Unit" => "mV"),
        ],
    )
end


"""
    FAST_SanitiseJson_DDEF(x::Any)::Any
Recursively filters Julia objects into JSON-compliant structures.
Converts DataFrames to row-dicts and ensures NaNs/Missings map to 'null'.
"""
function FAST_SanitiseJson_DDEF(x::Any)::Any
    # Declarative pattern matching for JSON sanitization
    if x === missing || x === nothing || (x isa AbstractFloat && isnan(x))
        return nothing
    elseif x isa DataFrame
        return [FAST_SanitiseJson_DDEF(Dict(string(k) => v for (k, v) in zip(keys(r), values(r)))) for r in eachrow(x)]
    elseif x isa Dict
        return Dict(string(k) => FAST_SanitiseJson_DDEF(v) for (k, v) in x)
    elseif x isa AbstractMatrix
        # Convert matrix to nested vector (row-major) for JSON compatibility
        return [FAST_SanitiseJson_DDEF(x[i, :]) for i in axes(x, 1)]
    elseif x isa AbstractVector
        return map(FAST_SanitiseJson_DDEF, x)
    elseif x isa Union{Tuple,NamedTuple,Pair}
        return FAST_SanitiseJson_DDEF(collect(x))
    else
        return x
    end
end

"""
    FAST_InitMaster_DDEF(File, InNames, OutNames, [DesignData], [Config]) -> Bool
Initialises or updates the master Excel record with headers and configuration.
"""
function FAST_InitMaster_DDEF(File::String, InNames::Vector{String}, OutNames::Vector{String},
    DesignData::Union{DataFrame,Nothing}=nothing, Config::Dict{String,Any}=Dict{String,Any}())::Bool
    try
        C = FAST_Data_DDEC
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
                    FAST_NormaliseCols_DDEF!(df_old)

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

        FAST_RoundCols_DDEF!(df_final_data)

        # 5. File Construction Via SafeWrite
        
        # Build Config
        clean_config = FAST_SanitiseJson_DDEF(Config)
        json_str     = isempty(Config) ? "{}" : JSON3.write(clean_config)
        config_df    = DataFrame(
            "PARAMETER"  => ["MasterConfig"],
            "VALUE_JSON" => [json_str],
            "UPDATED_AT" => [string(now())],
        )

        updates = Dict{String,DataFrame}(
            C.SHEET_DATA   => df_final_data,
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

# --- WRITELEADERS MOVED TO Sys_Flow.jl ---

"""
    FAST_GenerateSmartName_DDEF(Project, Phase, Status) -> String
Generates a unique, descriptive filename according to the Daisho protocol.
"""
function FAST_GenerateSmartName_DDEF(Project::String, Phase::String, Status::String)::String
    p_clean  = isempty(strip(Project)) ? "Daisho" : replace(strip(Project), " " => "_")
    ph_clean = replace(Phase, "Phase" => "P")
    ts       = Dates.format(now(), "yyyy_mmdd_HHMM")
    
    return "DDE_$(p_clean)_$(ph_clean)_$(Status)_$(ts).xlsx"
end

"""
    FAST_GetTransientPath_DDEF([Base64Content]) -> String
Creates a identifiable temporary file path inside the Workforce bunker.
"""
function FAST_GetTransientPath_DDEF(Base64Content::Union{String,Nothing}=nothing)::String
    # Ensure directory exists (failsafe)
    isdir(FAST_TempRoot_DDEC) || mkpath(FAST_TempRoot_DDEC)

    ts       = Dates.format(now(), "HHmmss_SSS")
    rnd      = rand(1000:9999)
    tmp_path = joinpath(FAST_TempRoot_DDEC, "DAISHO_TEMP_$(ts)_$(rnd).xlsx")

    if !isnothing(Base64Content)
        write(tmp_path, base64decode(split(Base64Content, ',')[end]))
    end
    
    return tmp_path
end

"""
    FAST_ReadToStore_DDEF(Path) -> String
Reads a file and returns its Base64 representation for frontend storage.
"""
function FAST_ReadToStore_DDEF(Path::Union{String,Nothing})::String
    try
        (isnothing(Path) || isempty(Path) || !isfile(Path)) && return ""
        return "data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64," * base64encode(read(Path))
    catch
        return ""
    end
end

"""
    FAST_ReadConfig_DDEF(File) -> Dict
Reads the MasterConfig from an existing Excel file's CONFIG sheet.
"""
function FAST_ReadConfig_DDEF(File::Union{String,Nothing})::Dict{String,Any}
    try
        (isnothing(File) || isempty(File)) && return Dict{String,Any}()
        
        C  = FAST_Data_DDEC
        df = FAST_ReadExcel_DDEF(File, C.SHEET_CONFIG)
        isempty(df) && return Dict{String,Any}()

        hasproperty(df, :PARAMETER) || return Dict{String,Any}()
        idx = findfirst(==("MasterConfig"), string.(df[!, :PARAMETER]))
        isnothing(idx) && return Dict{String,Any}()

        json_str = df[idx, :VALUE_JSON]
        # Robustness: ensure we are not trying to parse a binary/PK stream as JSON
        js_val = string(json_str)
        if startswith(js_val, "PK")
            FAST_Log_DDEF("FAST", "READ_CONFIG_WARN", "Binary signature detected in JSON field. Aborting parse.", "WARN")
            return Dict{String,Any}()
        end
        
        return JSON3.read(js_val, Dict{String,Any})
    catch e
        FAST_Log_DDEF("FAST", "READ_CONFIG_FAIL", "Error reading config from $File: $e", "WARN")
        return Dict{String,Any}()
    end
end

"""
    FAST_UpdateConfig_DDEF(File, Updates) -> Bool
Surgically updates specific keys in the MasterConfig stored in the Excel file.
"""
function FAST_UpdateConfig_DDEF(File::Union{String,Nothing}, Updates::Dict)::Bool
    try
        (isnothing(File) || isempty(File) || !isfile(File)) && return false
        C = FAST_Data_DDEC

        current_config = FAST_ReadConfig_DDEF(File)
        for (k, v) in Updates
            current_config[string(k)] = v
        end

        clean_config = FAST_SanitiseJson_DDEF(current_config)
        json_str     = JSON3.write(clean_config)

        config_df = DataFrame(
            "PARAMETER"  => ["MasterConfig"],
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
    FAST_GetThreadInfo_DDEF()::Tuple{Int, String, String}
Audit check for CPU concurrency status. Returns (Count, Theme_Colour, Status_Message).
"""
function FAST_GetThreadInfo_DDEF()::Tuple{Int,String,String}
    n::Int = Threads.nthreads()
    # High-performance status reporting
    n > 1 ? (n, "var(--colour-chr4-tongre)", "$n Threads [OPTIMAL]") : (n, "var(--colour-chr5-hueyel)", "1 Thread [SUB-OPTIMAL]")
end

# --------------------------------------------------------------------------------------
# --- RACE CONDITION LOCK ---
# --------------------------------------------------------------------------------------

# Global atomic lock pool — keyed by operation name
const FAST_OperationLocks_DDEC = Dict{String,ReentrantLock}()
const FAST_LockGuard_DDEC = ReentrantLock()

"""
    FAST_AcquireLock_DDEF(op_name) -> Bool
Tries to acquire a named operation lock without blocking.
"""
function FAST_AcquireLock_DDEF(op_name::Union{String,Nothing})::Bool
    (isnothing(op_name) || isempty(op_name)) && return false
    
    lock(FAST_LockGuard_DDEC) do
        haskey(FAST_OperationLocks_DDEC, op_name) || (FAST_OperationLocks_DDEC[op_name] = ReentrantLock())
    end
    
    lk = FAST_OperationLocks_DDEC[op_name]
    return trylock(lk)
end

"""
    FAST_ReleaseLock_DDEF(op_name)
Releases the named operation lock safely.
"""
function FAST_ReleaseLock_DDEF(op_name::Union{String,Nothing})::Nothing
    (isnothing(op_name) || isempty(op_name)) && return nothing
    haskey(FAST_OperationLocks_DDEC, op_name) || return
    
    lk = FAST_OperationLocks_DDEC[op_name]
    islocked(lk) && unlock(lk)
    
    return nothing
end

# --------------------------------------------------------------------------------------
# --- IN-MEMORY TRANSIENT CACHE ---
# --------------------------------------------------------------------------------------

# Thread-safe in-memory DataFrame cache
const FAST_CacheStore_DDEC = Dict{String,DataFrame}()
const FAST_CacheLock_DDEC  = ReentrantLock()

"""
    FAST_CacheRead_DDEF(key) -> Union{DataFrame, Nothing}
Thread-safe read from the in-memory cache.
"""
function FAST_CacheRead_DDEF(key::Union{String,Nothing})::Union{DataFrame,Nothing}
    (isnothing(key) || isempty(key)) && return nothing
    
    lock(FAST_CacheLock_DDEC) do
        haskey(FAST_CacheStore_DDEC, key) ? copy(FAST_CacheStore_DDEC[key]) : nothing
    end
end

"""
    FAST_CacheWrite_DDEF(key, df)
Thread-safe write to the in-memory cache.
"""
function FAST_CacheWrite_DDEF(key::Union{String,Nothing}, df::DataFrame)::Nothing
    (isnothing(key) || isempty(key)) && return nothing
    
    lock(FAST_CacheLock_DDEC) do
        FAST_CacheStore_DDEC[key] = copy(df)
    end
    
    FAST_Log_DDEF("CACHE", "WRITE", "Cached '$(key)' ($(nrow(df)) rows)", "OK")
end

"""
    FAST_CacheEvict_DDEF(key)
Evicts specific key or clears entire cache if key is empty.
"""
function FAST_CacheEvict_DDEF(key::Union{String,Nothing}="")::Nothing
    k_val = isnothing(key) ? "" : key
    lock(FAST_CacheLock_DDEC) do
        if isempty(k_val)
            empty!(FAST_CacheStore_DDEC)
            FAST_Log_DDEF("CACHE", "FLUSH", "Entire cache cleared.", "WARN")
        elseif haskey(FAST_CacheStore_DDEC, key)
            delete!(FAST_CacheStore_DDEC, key)
            FAST_Log_DDEF("CACHE", "EVICT", "Evicted '$key'", "INFO")
        end
    end
    
    return nothing
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

# --------------------------------------------------------------------------------------
# --- TRANSIENT FILE MANAGEMENT ---
# --------------------------------------------------------------------------------------

"""
    FAST_CleanTransient_DDEF(path)
Guaranteed removal of temporary files.
"""
function FAST_CleanTransient_DDEF(path::Union{String,Nothing})::Nothing
    (isnothing(path) || isempty(path)) && return nothing
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
function FAST_FormatDuration_DDEF(seconds::Float64)::String
    seconds < 0.001 && return "<1ms"
    seconds < 1.0   && return @sprintf("%.0fms", seconds * 1000)
    seconds < 60.0  && return @sprintf("%.2fs", seconds)
    
    minutes = seconds / 60.0
    return @sprintf("%.1fmin", minutes)
end

"""
    FAST_ValidateDataFrame_DDEF(df, [RequiredCols]) -> (Bool, Vector{String})
Pre-flight data quality validator checking for missing columns and NaNs.
"""
function FAST_ValidateDataFrame_DDEF(df::DataFrame, RequiredCols::Vector{String}=String[])::Tuple{Bool,Vector{String}}
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
            vals         = collect(skipmissing(df[!, col]))
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
    FAST_GetSystemQuote_DDEF() -> String
Returns a random scientific/academic quote to inspire the researcher.
"""
function FAST_GetSystemQuote_DDEF()::String
    quotes = [
        "Data is the new oil, but intelligence is the refinery.",
        "Equipped with his five senses, man explores the universe around him and calls the adventure Science.",
        "The art of discovery is the art of seeing what everyone else has seen, and thinking what no one else has thought.",
        "Everything must be made as simple as possible, but not simpler.",
        "The best way to predict the future is to create it."
    ]
    return rand(quotes)
end

"""
    FAST_GetCol_DDEF(df::DataFrame, Target::String)::String
Finds the actual column name in DataFrame that matches Target case-insensitively.
(Non-destructive: does not modify the DataFrame).
"""
function FAST_GetCol_DDEF(df::DataFrame, Target::String)::String
    isempty(df) && return ""
    t_up = uppercase(strip(Target))
    for n in names(df)
        if uppercase(strip(string(n))) == t_up
            return string(n)
        end
    end
    return ""
end

end # module Sys_Fast
