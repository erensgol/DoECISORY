module Sys_Fast

# ==============================================================================
# DAISHODOE PROJECT - SYSTEM FAST (IO & UTILS)
# ==============================================================================
# Description: High-speed I/O (Excel/XLSX), system-wide logging, and transient 
#              data orchestration.
# Module Tag:  FAST
# ==============================================================================

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
    FAST_GenerateSmartName_DDEF, FAST_ExtractProjectFromFilename_DDEF,
    FAST_GetTransientPath_DDEF, FAST_ReadToStore_DDEF,
    FAST_UpdateConfig_DDEF, FAST_GetThreadInfo_DDEF,
    FAST_SanitiseInput_DDEF,
    FAST_AcquireLock_DDEF, FAST_ReleaseLock_DDEF, FAST_ForceReleaseAll_DDEF,
    FAST_CacheRead_DDEF, FAST_CacheWrite_DDEF, FAST_CacheEvict_DDEF,
    FAST_VaultWrite_DDEF, FAST_VaultRead_DDEF,
    FAST_GetComputeThreads_DDEF,
    FAST_SafeExcelWrite_DDEF, FAST_CleanTransient_DDEF,
    FAST_FormatDuration_DDEF, FAST_ValidateDataFrame_DDEF,
    FAST_GetSystemQuote_DDEF,
    FAST_RoundCols_DDEF!,
    FAST_GetCol_DDEF,
    FAST_CleanHeader_DDEF,
    FAST_InitialiseWorkforce_DDEF, FAST_CleanWorkforce_DDEF,
    FAST_Data_DDEC,
    FAST_SanitiseFilename_DDEF,
    FAST_LoadMemoFile_DDEF

# ==============================================================================
# PART A: SYSTEM ARCHITECTURE & TRANSIENT WORKFORCE
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 1: SYSTEM-WIDE CONSTANTS & COLOURS
# ------------------------------------------------------------------------------

"""
    FAST_Constants_DDES
System-wide configuration, metadata structure, and primary colour palettes.
"""
Base.@kwdef struct FAST_Constants_DDES
    VERSION::String        = "v1.0-dev"
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
    PRE_CHRO::String       = "CHRO_"
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

# ------------------------------------------------------------------------------
# SECTION 2: TRANSIENT STORAGE MANAGEMENT
# ------------------------------------------------------------------------------

"""
    FAST_TempRoot_DDEC
Dedicated directory for transient operations to prevent system-wide data scattering.
"""
const FAST_TempRoot_DDEC = joinpath(tempdir(), "DaishoDoE_Workforce")

"""
    FAST_InitialiseWorkforce_DDEF()
Initialises transient directories and clears existing temporary files.
"""
function FAST_InitialiseWorkforce_DDEF()
    ENV["TMP"]    = FAST_TempRoot_DDEC
    ENV["TEMP"]   = FAST_TempRoot_DDEC
    ENV["TMPDIR"] = FAST_TempRoot_DDEC
    
    FAST_Log_DDEF("SYS", "Initialise", "Synchronising workforce directories...", "INFO")
    try
        if !isdir(FAST_TempRoot_DDEC)
            mkpath(FAST_TempRoot_DDEC)
            FAST_Log_DDEF("FAST", "WORKFORCE", "Created transient directory: $FAST_TempRoot_DDEC", "OK")
        else
            FAST_CleanWorkforce_DDEF()
            FAST_Log_DDEF("FAST", "WORKFORCE", "Transient directory prepared for execution.", "OK")
        end
    catch e
        FAST_Log_DDEF("FAST", "WORKFORCE_FAIL", "Could not initialise temp directory: $e", "FAIL")
    end
end

# ------------------------------------------------------------------------------
# SECTION 3: FILESYSTEM CLEANING & GARDENING
# ------------------------------------------------------------------------------

function FAST_CleanWorkforce_DDEF(all::Bool=false)::Nothing
    !isdir(FAST_TempRoot_DDEC) && return nothing

    try
        for (root, dirs, files) in walkdir(FAST_TempRoot_DDEC; topdown=false)
            for f in files
                # Integrity Protocol: Enforcement of restricted deletion for files non-compliant with DDE patterns.
                if all || startswith(f, "DAISHO_TEMP_") || startswith(f, "DDE_")
                    try
                        rm(joinpath(root, f); force=true)
                    catch
                    end
                end
            end
            for d in dirs
                try
                    if root != FAST_TempRoot_DDEC || all
                         rm(joinpath(root, d); force=true, recursive=true)
                    end
                catch
                end
            end
        end

        all && FAST_Log_DDEF("FAST", "CLEAN_DEEP", "Extended workforce sweep executed.", "INFO")
    catch e
        FAST_Log_DDEF("FAST", "CLEAN_WARN", "Recursive cleaning encountered an error: $e", "WARN")
    end
    
    return nothing
end

"""
    FAST_CleanTransient_DDEF(path)
Surgically removes a specific transient file from the workforce.
"""
function FAST_CleanTransient_DDEF(path::Union{String,Nothing})
    (isnothing(path) || isempty(path) || !isfile(path)) && return nothing
    
    if !startswith(abspath(path), abspath(FAST_TempRoot_DDEC))
        FAST_Log_DDEF("FAST", "GUARD_VIOLATION", "Deletion attempt outside transient scope: $path", "FAIL")
        return nothing
    end

    try
        rm(path; force=true)
    catch
    end
    return nothing
end

# ==============================================================================
# PART B: LOGGING & CONSOLE TELEMETRY
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 4: LOGGING SYSTEM & ANSI COLOURS
# ------------------------------------------------------------------------------

# Static pre-computation of ANSI escape sequences for synchronised console telemetry.
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

# ------------------------------------------------------------------------------
# SECTION 5: FILENAME SANITISATION & COMPATIBILITY
# ------------------------------------------------------------------------------

"""
    FAST_SanitiseFilename_DDEF(name::String) -> String
ASCII-safe filename generator. Converts Turkish characters to ASCII and replaces 
non-alphanumeric characters with underscores. Ensures filesystem compatibility.
"""
function FAST_SanitiseFilename_DDEF(name::AbstractString)
    # Execution of character normalisation map for Turkish-to-ASCII collation.
    mapping = Dict(
        'ç' => 'c', 'Ç' => 'C',
        'ğ' => 'g', 'Ğ' => 'G',
        'ı' => 'i', 'İ' => 'I',
        'ö' => 'o', 'Ö' => 'O',
        'ş' => 's', 'Ş' => 'S',
        'ü' => 'u', 'Ü' => 'U'
    )
    
    res = map(c -> get(mapping, c, c), name)
    res = replace(res, r"[^\w\-_.]" => "_")
    res = replace(res, r"_{2,}" => "_")
    
    return strip(res, ['_'])
end

# ==============================================================================
# PART C: HIGH-FIDELITY I/O & DATA SANITISATION
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 6: EXCEL I/O & DATA NORMALISATION
# ------------------------------------------------------------------------------

"""
    FAST_NormaliseCols_DDEF!(df::DataFrame)::DataFrame
Standardises DataFrame column names: Strips whitespace and forces Uppercase.
Mutates the DataFrame in-place for performance.
"""
function FAST_NormaliseCols_DDEF!(df::DataFrame; force_upper::Bool=false)::DataFrame
    isempty(df) && return df
    
    # Execution of column standardisation protocol: whitespace removal and case-sensitivity normalisation.
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
        FAST_Log_DDEF("FAST", "IO_ERROR", "The selected file type [$ext] is not a valid Excel document (.xlsx/.xlsm).", "FAIL")
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

        # Identification of data-centric sheets for mandatory schema validation.
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
                FAST_Log_DDEF("FAST", "FORMAT_FAIL", "Compatibility error: Mandatory columns (EXP_ID/ID or PHASE) are missing in sheet [$SheetName].", "WARN")
                throw(ArgumentError("Incompatible format in sheet [$SheetName]: Required columns not found."))
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
    FAST_SafeExcelWrite_DDEF(File, Updates) -> Nothing
Writes to the Excel file using a buffered approach to prevent data truncation.
"""
function FAST_SafeExcelWrite_DDEF(File::Union{String,Nothing}, Updates::Dict{String,DataFrame})::Nothing
    (isnothing(File) || isempty(File)) && return nothing
    
    all_data    = Dict{String,DataFrame}()
    sheet_order = String[]

    if isfile(File)
        try
            XLSX.openxlsx(File) do xf
                for sn in XLSX.sheetnames(xf)
                    push!(sheet_order, sn)
                    if haskey(Updates, sn)
                        all_data[sn] = Updates[sn]
                    else
                        all_data[sn] = try
                            DataFrame(XLSX.gettable(xf[sn]))
                        catch
                            DataFrame()
                        end
                    end
                end
            end
        catch e
            # Log notification for archival recovery or fresh initialisation requirement.
            FAST_Log_DDEF("FAST", "SAFE_WRITE", "Reference file inaccessible. Initialising fresh.", "WARN")
        end
    end

    for (k, df) in Updates
        if !haskey(all_data, k)
            push!(sheet_order, k)
            all_data[k] = df
        else
        all_data[k] = df
        end
    end

    # Filter out empty dataframes or those with no columns to prevent XLSX errors
    valid_pairs = Pair{String, DataFrame}[]
    for sn in sheet_order
        df = all_data[sn]
        if ncol(df) > 0 && (nrow(df) > 0 || sn == "CONFIG")
            push!(valid_pairs, sn => df)
        elseif ncol(df) == 0
            FAST_Log_DDEF("FAST", "IO_WARN", "Skipping sheet [$sn] - No columns defined.", "WARN")
        end
    end

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

# ------------------------------------------------------------------------------
# SECTION 7: DOWNLOAD PREPARATION & BINARY EXTRACTION
# ------------------------------------------------------------------------------

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

# ==============================================================================
# PART D: SCIENTIFIC UTILITIES & TYPE SAFETY
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 8: NUMERIC COERCION & COMPATIBILITY
# ------------------------------------------------------------------------------

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

    # Resolution of numeric ambiguity involving localised decimal delimiters (comma-to-dot).
    clean_s = replace(s, ',' => '.')
    res     = tryparse(Float64, clean_s)
    
    return something(res, NaN)
end

# ------------------------------------------------------------------------------
# SECTION 9: INPUT SANITISATION ENGINE
# ------------------------------------------------------------------------------

"""
    FAST_SanitiseInput_DDEF(TableData::AbstractVector)::Tuple{Vector{Dict{String,Any}}, Vector{String}}
Transforms raw UI Table data into typed scientific Dictionaries.
Implements automatic feature recognition for radioactivity and filler logic.
"""
function FAST_SanitiseInput_DDEF(TableData::AbstractVector)::Tuple{Vector{Dict{String,Any}},Vector{String}}
    warnings = String[]

    sanitised = map(enumerate(TableData)) do (idx, raw)
        r = Dict{String,Any}(string(k) => v for (k, v) in raw)

        row_name = string(get(r, "Name", "Unnamed_Item_$(idx)"))
        r["Name"] = row_name
        r["Role"] = string(get(r, "Role", "Variable"))
        r["Unit"] = string(get(r, "Unit", ""))
        r["HalfLifeUnit"] = string(get(r, "HalfLifeUnit", "Hours"))

        r["IsRadioactive"] = get(r, "IsRadioactive", false) == true

        num_fields = ("L1", "L2", "L3", "MW", "Min", "Max", "Target", "HalfLife")
        for key in num_fields
            val = get(r, key, nothing)
            clean_val = FAST_SafeNum_DDEF(val)

            if isnan(clean_val) && !isnothing(val) && val !== missing && string(val) != ""
                push!(warnings, "Item '$row_name': Invalid input for '$key' ($val) coerced to 0.0")
            end
            r[key] = isnan(clean_val) ? 0.0 : clean_val
        end

        if r["HalfLife"] > 0.0
            r["IsRadioactive"] = true
        end

        return r
    end

    !isempty(warnings) && FAST_Log_DDEF("FAST", "SANITY", "Resolved $(length(warnings)) data anomalies.", "WARN")
    return (sanitised, warnings)
end

# ------------------------------------------------------------------------------
# SECTION 10: LAB DEFAULTS & SESSION INCEPTION
# ------------------------------------------------------------------------------

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

# ------------------------------------------------------------------------------
# SECTION 11: JSON RECURSIVE SANITISATION
# ------------------------------------------------------------------------------

"""
    FAST_SanitiseJson_DDEF(x::Any)::Any
Recursively filters Julia objects into JSON-compliant structures.
Converts DataFrames to row-dicts and ensures NaNs/Missings map to 'null'.
"""
function FAST_SanitiseJson_DDEF(x::Any)::Any
    # Execution of declarative pattern matching for recursive data structure sanitisation.
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

# ==============================================================================
# PART E: CONFIGURATION SYNC & VAULT OPS
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 12: MASTER RECORD INITIALISATION (XLSX)
# ------------------------------------------------------------------------------

"""
    FAST_InitMaster_DDEF(File, InNames, OutNames, [DesignData], [Config]) -> Bool
Initialises or updates the primary Excel record with headers and configuration metadata.
"""
function FAST_InitMaster_DDEF(File::String, InNames::Vector{String}, OutNames::Vector{String},
    DesignData::Union{DataFrame,Nothing}=nothing, Config::Dict{String,Any}=Dict{String,Any}())::Bool
    try
        C = FAST_Data_DDEC
        FAST_Log_DDEF("FAST", "Init Master", "Target: $File", "WAIT")

        headers = [C.COL_EXP_ID, C.COL_PHASE, C.COL_STATUS, C.COL_NOTES]

        if !isnothing(DesignData)
            data_cols = names(DesignData)
            for col in data_cols
                if startswith(col, C.PRE_MASS) && col ∉ headers
                    push!(headers, col)
                end
            end
            
                # Execution of robust mapping for Inputs/Fixed/Fillers exhibiting unit suffixes.
                for name in InNames
                for pfx in (C.PRE_INPUT, C.PRE_FIXED, C.PRE_FILL)
                    # Find any column that starts with prefix + name
                    target_pfx = pfx * name
                    for col in data_cols
                        if startswith(col, target_pfx) && col ∉ headers
                            push!(headers, col)
                        end
                    end
                end
            end
        else
            for n in InNames
                push!(headers, C.PRE_MASS * n * "_mg")
                push!(headers, C.PRE_INPUT * n)
            end
        end

        for n in OutNames
            push!(headers, C.PRE_RESULT * n)
        end
        for n in OutNames
            push!(headers, C.PRE_PRED * n)
        end
        push!(headers, C.COL_SCORE)

        if !isnothing(DesignData)
            for chr_col in ("CHRO_HOUR", "CHRO_MIN")
                if chr_col ∈ names(DesignData) && chr_col ∉ headers
                    push!(headers, chr_col)
                end
            end
        end

        df_new = isnothing(DesignData) ? DataFrame(Dict(h => [] for h in headers)) : copy(DesignData)

        for col in setdiff(headers, names(df_new))
            df_new[!, col] = fill(missing, nrow(df_new))
        end
        df_final_data = select!(df_new, headers)

        if isfile(File) && !isnothing(DesignData)
            try
                df_old = FAST_ReadExcel_DDEF(File, C.SHEET_DATA)
                if !isempty(df_old)
                    FAST_NormaliseCols_DDEF!(df_old)
                    headers = names(df_old)

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

# ------------------------------------------------------------------------------
# SECTION 13: FILENAME GENERATION (SMART)
# ------------------------------------------------------------------------------

"""
    FAST_GenerateSmartName_DDEF(Project, Phase, Tag, [Extension]) -> String
Generates a unique, descriptive filename according to the project protocol.
Template: DDE_[Proj]_[Phase]_[Tag]_[Timestamp].[Ext]
"""
function FAST_GenerateSmartName_DDEF(Project::String, Phase::String, Tag::String, Ext::String="xlsx")::String
    p_raw    = strip(Project)
    p_clean  = (isempty(p_raw) || lowercase(p_raw) == "daisho") ? "Daisho" : FAST_SanitiseFilename_DDEF(p_raw)
    ph_clean = replace(Phase, "Phase" => "P")
    ts       = Dates.format(now(), "yyyy_mmdd_HHMM")
    
    return "DDE_$(p_clean)_$(ph_clean)_$(Tag)_$(ts).$(Ext)"
end

"""
    FAST_ExtractProjectFromFilename_DDEF(Filename::String) -> String
Extracts the project name from a Daisho standard filename.
Returns empty string if the pattern doesn't match.
"""
function FAST_ExtractProjectFromFilename_DDEF(Filename::String)::String
    # Formulation of the extraction pattern: DDE_ProjectName_Phase_Tag_TS.ext.
    m = match(r"^DDE_(.*?)_P\d+_", Filename)
    return isnothing(m) ? "" : string(m.captures[1])
end

# ------------------------------------------------------------------------------
# SECTION 14: TRANSIENT PATH ORCHESTRATION
# ------------------------------------------------------------------------------

"""
    FAST_GetTransientPath_DDEF([DataHandle]) -> String
Creates an identifiable temporary file path within the transient directory.
If DataHandle is a Hash, it retrieves binary from Vault. If it's Base64, it decodes it.
"""
function FAST_GetTransientPath_DDEF(DataHandle::Union{String,Nothing}=nothing)::String
    # Architectural Enforcement: Verification of transient directory existence prior to allocation.
    isdir(FAST_TempRoot_DDEC) || mkpath(FAST_TempRoot_DDEC)

    ts       = Dates.format(now(), "HHmmss_SSS")
    rnd      = rand(1000:9999)
    tmp_path = joinpath(FAST_TempRoot_DDEC, "DAISHO_TEMP_$(ts)_$(rnd).xlsx")

    if !isnothing(DataHandle) && !isempty(DataHandle)
        vault_binary = FAST_VaultRead_DDEF(DataHandle)
        if !isnothing(vault_binary)
            write(tmp_path, vault_binary)
            return tmp_path
        end

        if contains(DataHandle, ";base64,")
            write(tmp_path, base64decode(split(DataHandle, ',')[end]))
        end
    end
    
    return tmp_path
end

"""
    FAST_ReadToStore_DDEF(Path) -> String
Reads a file, persists it to Server Vault, and returns its Hash handle for frontend.
"""
function FAST_ReadToStore_DDEF(Path::Union{String,Nothing})::String
    try
        (isnothing(Path) || isempty(Path) || !isfile(Path)) && return ""
        
        binary = read(Path)
        h_val  = string(hash(binary))
        FAST_VaultWrite_DDEF(h_val, binary)
        
        return h_val
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
        # Scientific Integrity Check: Detection of binary/PK signatures in JSON-designated fields.
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

# ------------------------------------------------------------------------------
# SECTION 15: HARDWARE AUDIT & THREADING
# ------------------------------------------------------------------------------

"""
    FAST_GetThreadInfo_DDEF()::Tuple{Int, String, String}
Audit check for CPU concurrency status. Returns (Count, Theme_Colour, Status_Message).
"""
function FAST_GetThreadInfo_DDEF()::Tuple{Int,String,String}
    n::Int = Threads.nthreads()
    # Provision of high-performance status telemetry for CPU concurrency.
    n > 1 ? (n, "var(--colour-chr4-tongre)", "$n Threads [OPTIMAL]") : (n, "var(--colour-chr5-hueyel)", "1 Thread [SUB-OPTIMAL]")
end

"""
    FAST_LoadMemoFile_DDEF(FilePath::String) -> Dict{String, Any}
Loads a standardized DDE Memo file (JSON) from the local filesystem.
Returns an empty dictionary if the file is not found or is corrupt.
"""
function FAST_LoadMemoFile_DDEF(FilePath::String)::Dict{String,Any}
    try
        if !isfile(FilePath)
            FAST_Log_DDEF("FAST", "MEMO_NOT_FOUND", "Project reference $FilePath missing.", "WARN")
            return Dict{String,Any}()
        end
        
        json_str = read(FilePath, String)
        return JSON3.read(json_str, Dict{String,Any})
    catch e
        FAST_Log_DDEF("FAST", "MEMO_LOAD_FAIL", "Corruption in $FilePath: $e", "FAIL")
        return Dict{String,Any}()
    end
end

# ------------------------------------------------------------------------------
# SECTION 16: RACE CONDITION LOCK
# ------------------------------------------------------------------------------

# Global atomic lock pool — keyed by operation name
const FAST_OperationLocks_DDEC = Dict{String,ReentrantLock}()
const FAST_LockGuard_DDEC = ReentrantLock()

"""
    FAST_AcquireLock_DDEF(op_name, Reason::String="Unspecified") -> Bool
Attempts to acquire a named operation lock without blocking. Status telemetry is documented for system transparency.
"""
function FAST_AcquireLock_DDEF(op_name::Union{String,Nothing}, Reason::String="Unspecified")::Bool
    (isnothing(op_name) || isempty(op_name)) && return false
    
    lock(FAST_LockGuard_DDEC) do
        haskey(FAST_OperationLocks_DDEC, op_name) || (FAST_OperationLocks_DDEC[op_name] = ReentrantLock())
    end
    
    lk = FAST_OperationLocks_DDEC[op_name]
    success = trylock(lk)
    
    if success
        FAST_Log_DDEF("SYS", "LOCK_ACQUIRE", "Lock: $op_name | Reason: $Reason", "OK")
    else
        FAST_Log_DDEF("SYS", "LOCK_REJECT", "Lock: $op_name | Active Process Detected", "WARN")
    end
    
    return success
end

"""
    FAST_ReleaseLock_DDEF(op_name::Union{String,Nothing})
Releases the named operation lock safely. Telemetry records release status and handles reentrancy or ownership violations.
"""
function FAST_ReleaseLock_DDEF(op_name::Union{String,Nothing})
    (isnothing(op_name) || isempty(op_name)) && return nothing
    haskey(FAST_OperationLocks_DDEC, op_name) || return
    
    lk = FAST_OperationLocks_DDEC[op_name]
    
    if islocked(lk)
        try
            unlock(lk)
            # Re-validation of lock status for archival telemetry reporting.
            still_locked = islocked(lk)
            if still_locked
                FAST_Log_DDEF("SYS", "LOCK_RELEASE_PARTIAL", "Lock: $op_name (Reentrancy Level Decreased)", "INFO")
            else
                FAST_Log_DDEF("SYS", "LOCK_RELEASE", "Lock: $op_name (Active Lock: OFF)", "INFO")
            end
        catch e
            FAST_Log_DDEF("SYS", "LOCK_RELEASE_FAIL", "Lock: $op_name | Error: $(string(e))", "FAIL")
        end
    else
        # Provision for logging attempts to release an idle lock state.
        # FAST_Log_DDEF("SYS", "LOCK_RELEASE_IDLE", "Lock: $op_name already free.", "LIST")
    end
    
    return nothing
end

"""
    FAST_ForceReleaseAll_DDEF()
Clears all operation locks from the global pool. Reserved exclusively for system recovery protocols.
"""
function FAST_ForceReleaseAll_DDEF()
    lock(FAST_LockGuard_DDEC) do
        empty!(FAST_OperationLocks_DDEC)
    end
    FAST_Log_DDEF("SYS", "LOCK_FLUSH", "All operation locks successfully cleared during system recovery.", "WARN")
    return nothing
end

# ------------------------------------------------------------------------------
# SECTION 17: IN-MEMORY TRANSIENT CACHE
# ------------------------------------------------------------------------------

# Provision of a thread-safe in-memory cache for high-velocity DataFrame access.
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

# ------------------------------------------------------------------------------
# SECTION 18: BINARY VAULT (SERVER-SIDE BLOB STORAGE)
# ------------------------------------------------------------------------------

# Repository for large-scale binary objects (Excel archives) designed to preserve application performance.
const FAST_BinaryVault_DDEC = Dict{String, Vector{UInt8}}()
const FAST_VaultLock_DDEC   = ReentrantLock()

"""
    FAST_VaultWrite_DDEF(key, binary)
Thread-safe write to binary vault.
"""
function FAST_VaultWrite_DDEF(key::String, binary::Vector{UInt8})::Nothing
    lock(FAST_VaultLock_DDEC) do
        FAST_BinaryVault_DDEC[key] = binary
    end
    FAST_Log_DDEF("VAULT", "STORE", "Binary persisted ($key) | Size: $(length(binary) ÷ 1024) KB", "OK")
    return nothing
end

"""
    FAST_VaultRead_DDEF(key) -> Vector{UInt8}
Thread-safe read from binary vault.
"""
function FAST_VaultRead_DDEF(key::String)::Union{Vector{UInt8}, Nothing}
    lock(FAST_VaultLock_DDEC) do
        return haskey(FAST_BinaryVault_DDEC, key) ? FAST_BinaryVault_DDEC[key] : nothing
    end
end

# ------------------------------------------------------------------------------
# SECTION 19: COMPUTE RESOURCES & SYSTEM DIAGNOSTICS
# ------------------------------------------------------------------------------

"""
    FAST_GetComputeThreads_DDEF() -> Int
Returns available threading resources for parallel computation, reserving a primary thread for the HTTP loop.
"""
function FAST_GetComputeThreads_DDEF()::Int
    total = Threads.nthreads()
    return max(1, total - 1)
end

function FAST_FormatDuration_DDEF(seconds::Float64)::String
    seconds < 0.001 && return "<1ms"
    seconds < 1.0   && return @sprintf("%.0fms", seconds * 1000)
    seconds < 60.0  && return @sprintf("%.2fs", seconds)
    minutes = seconds / 60.0
    return @sprintf("%.1fmin", minutes)
end

function FAST_ValidateDataFrame_DDEF(df::DataFrame, RequiredCols::Vector{String}=String[])::Tuple{Bool,Vector{String}}
    issues = String[]

    isempty(df) && (push!(issues, "DataFrame is empty."); return (false, issues))

    # Verification of mandatory column presence against experimental schema requirements.
    for c in RequiredCols
        if !hasproperty(df, Symbol(c))
            push!(issues, "Missing required column: '$c'")
        end
    end

    # Execution of density audits for NaN-saturated numeric columns to ensure data fidelity.
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
Provides a stochastic selection of scientific and academic citations to reinforce research focus.
"""
function FAST_GetSystemQuote_DDEF()::String
    quotes = [
        "Mathematics is the language of the universe. - G.G.",
        "Everything should be as simple as possible, but not simpler. - A.E.",
        "Errors with data are better than errors without it. - F.N.",
        "The best way to predict the future is to create it. - P.D.",
        "Measure what is measurable, and make measurable what is not. - G.G.",
        "Science is a way of thinking, not a body of knowledge. - C.S.",
        "All science is the refinement of everyday thinking. - A.E.",
        "An investment in knowledge pays the best interest. - B.F.",
        "I have no special talent, I am only passionately curious. - A.E.",
        "The science of today is the technology of tomorrow. - E.T.",
    ]
    return rand(quotes)
end

"""
    FAST_GetCol_DDEF(df::DataFrame, Target::String)::String
Identifies the formalised column name in a DataFrame matching the target criterion (Non-destructive operation).
"""
function FAST_GetCol_DDEF(df::DataFrame, Target::String)::String
    isempty(df) && return ""
    
    t_up = uppercase(strip(Target))
    for n in names(df)
        n_str = string(n)
        if uppercase(strip(n_str)) == t_up
            return n_str
        end
    end
    
    for n in names(df)
        n_str = string(n)
        n_up = uppercase(strip(n_str))
        if startswith(n_up, t_up * "_")
            return n_str
        end
    end
    
    return ""
end

"""
    FAST_CleanHeader_DDEF(Header::String) -> String
Standardises column headers through the removal of internal prefixes and dimensional unit metadata.
"""
function FAST_CleanHeader_DDEF(Header::AbstractString)
    h = strip(string(Header))
    isempty(h) && return ""
    
    idx = findlast('_', h)
    isnothing(idx) && return h
    
    C = FAST_Data_DDEC
    matched_prefix = false
    for pfx in (C.PRE_INPUT, C.PRE_FIXED, C.PRE_FILL, C.PRE_MASS, C.PRE_RESULT, C.PRE_PRED)
        if startswith(uppercase(h), uppercase(pfx))
            matched_prefix = true
            break
        end
    end
    
    if matched_prefix
        underscores = findall('_', h)
        if length(underscores) >= 2
            last_u = underscores[end]
            return h[1:prevind(h, last_u)]
        end
    end

    return h
end

end