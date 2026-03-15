module Lib_Mole

# ======================================================================================
# DAISHODOE PROJECT - LIB MOLE
# ======================================================================================
# Description: Engine for stoichiometry, unit-aware mass calculations, and 
#              chemical auditing processes.
# Module Tag:  MOLE
# ======================================================================================

using DataFrames
using Printf
using Unitful
using Statistics
using Main.Sys_Fast

export MOLE_ParseTable_DDEF, MOLE_QuickAudit_DDEF, MOLE_CalcMass_DDEF,
    MOLE_ApproxEq_DDEF, MOLE_ValidatePhysicalUnit_DDEF,
    MOLE_AuditMatrix_DDEF, MOLE_AuditBatch_DDEF, MOLE_ValidateDesignFeasibility_DDEF, MOLE_Ingredient_DDES,
    MOLE_ApplyRadioDecay_DDEF, MOLE_ProcessDesign_DDEF, MOLE_GetPercentageEquivalent_DDEF

# --------------------------------------------------------------------------------------
# DATA STRUCTURES
# --------------------------------------------------------------------------------------

"""
    MOLE_Ingredient_DDES
Represents chemical and operational properties of a single component.
"""
struct MOLE_Ingredient_DDES
    Name::String
    Role::String            # Expected values: "Variable", "Fixed", "Filler"
    Levels::Vector{Float64} # [Min, Mid, Max] values
    MW::Float64             # Molecular Weight (g/mol)
end

# --------------------------------------------------------------------------------------
# PHYSICAL CONRECTIONS & MATHEMATICAL MODELS
# --------------------------------------------------------------------------------------

"""
    MOLE_ConvertTimeToMinutes_DDEF(Value, Unit) -> Float64
Normalises arbitrary time units (Seconds, Hours, Days) to Minutes for system-wide consistency.
"""
function MOLE_ConvertTimeToMinutes_DDEF(Value::Real, Unit::String)
    Value <= 0.0 && return 0.0
    u = uppercase(strip(Unit))
    if occursin("SEC", u)
        return Value / 60.0
    elseif occursin("MIN", u)
        return Float64(Value)
    elseif occursin("DAY", u)
        return Value * 24.0 * 60.0 # Standard Day -> Minutes
    elseif occursin("HOUR", u) || occursin("HR", u)
        return Value * 60.0
    else
        return Float64(Value) # Default: Minutes (Minute-centric)
    end
end

"""
    MOLE_ApplyRadioDecay_DDEF(RawValue, HalfLife, HalfLifeUnit, DeltaTMinutes) -> Float64
Calculates effective mass/activity after isothermal decay (Measured * DF).
"""
function MOLE_ApplyRadioDecay_DDEF(RawValue::Float64, HalfLife::Float64, HalfLifeUnit::String, DeltaTMinutes::Float64)
    hl_minutes = MOLE_ConvertTimeToMinutes_DDEF(HalfLife, HalfLifeUnit)
    hl_minutes <= 0.0 && return RawValue

    lambda       = log(2) / hl_minutes
    decay_factor = exp(-lambda * DeltaTMinutes)
    
    return RawValue * decay_factor
end

# --------------------------------------------------------------------------------------
# TOLERANCE & EQUALITY COMPARATORS
# --------------------------------------------------------------------------------------

const MOLE_StoiTolerance_DDEC = 1e-6   # 0.0001% — sufficient for stoichiometry precision

"""
    MOLE_ApproxEq_DDEF(a::Real, b::Real; atol=1e-6) -> Bool
Tolerance-based equality for floating-point chemical calculations.
"""
MOLE_ApproxEq_DDEF(a::Real, b::Real; atol::Float64=MOLE_StoiTolerance_DDEC) = isapprox(a, b; atol)

# --------------------------------------------------------------------------------------
# CHEMICAL TABLE DATA PARSING
# --------------------------------------------------------------------------------------

"""
    MOLE_ParseTable_DDEF(TableData::AbstractVector) -> Dict
Parses structured data from the UI's DataTable into operational categories.
"""
function MOLE_ParseTable_DDEF(TableData::AbstractVector)
    # SanitiseInput returns (clean_data, warnings)
    clean_data, input_warnings = Main.Sys_Fast.FAST_SanitiseInput_DDEF(TableData)

    safe_num = Main.Sys_Fast.FAST_SafeNum_DDEF
    C        = Main.Sys_Fast.FAST_Data_DDEC

    names_vec = string.(get.(clean_data, "Name", "Unknown"))
    roles     = string.(get.(clean_data, "Role", "Fixed"))
    mins      = Float64.(get.(clean_data, "L1", 0.0))
    mids      = Float64.(get.(clean_data, "L2", 0.0))
    maxs      = Float64.(get.(clean_data, "L3", 0.0))
    mws       = Float64.(get.(clean_data, "MW", 0.0))

    roles_lower = lowercase.(roles)
    tag_var     = lowercase(C.ROLE_VAR)
    tag_fill    = lowercase(C.ROLE_FILL)

    idx_var  = findall(==(tag_var), roles_lower)
    idx_fill = findall(==(tag_fill), roles_lower)
    idx_fix  = findall(r -> r ∉ (tag_var, tag_fill), roles_lower)
    idx_chem = findall(>(0), mws)

    return Dict(
        "Names"         => names_vec, 
        "Roles"         => roles,
        "Mins"          => mins, 
        "Mids"          => mids, 
        "Maxs"          => maxs, 
        "MWs"           => mws,
        "Idx_Var"       => idx_var, 
        "Idx_Fix"       => idx_fix,
        "Idx_Fill"      => idx_fill, 
        "Idx_Chem"      => idx_chem,
        "Rows"          => clean_data, 
        "RawTable"      => clean_data,
        "InputWarnings" => input_warnings
    )
end

# --------------------------------------------------------------------------------------
# PHYSICAL DIMENSION VALIDATION (Unitful.jl)
# --------------------------------------------------------------------------------------

"""
    MOLE_GetUnitType_DDEF(UnitStr::String) -> (Symbol, Float64)
Categorises a unit string into :Mass (Fixed), :Molar (Relational), or :Other.
Returns (Type, ScaleToSystemBase) where the base is mg for mass and fractions for molar values.
"""
function MOLE_GetUnitType_DDEF(UnitStr::String)
    u = lowercase(strip(UnitStr))
    isempty(u) && return (:Molar, 1.0)
    
    # Relative / Molar Types (Ratio/Percent)
    if u == "%m" || u == "%"
        return (:Molar, 0.01) # Percentage base
    elseif u == "mr" || u == "ratio" || u == "-"
        return (:Molar, 1.0) # Ratio base
    elseif u == "m" || u == "mol/l" || u == "molar"
        return (:Concentration, 1000.0) # Molar (M) -> mM (x1000)
    elseif u == "mm" || u == "mmol/l" || u == "millimolar"
        return (:Concentration, 1.0) # Millimolar base
    elseif u == "um" || u == "μm" || u == "micromolar" || u == "umol/l"
        return (:Concentration, 0.001) # Micromolar base -> mM
    end

    # Absolute / Mass Types (Unitful supported)
    try
        # Support common chemical variants
        u_mod = replace(u, 
            " " => "*", 
            "_" => "*", 
            "mc" => "μ", 
            "mic" => "μ",
            "u" => "μ",
            "mcg" => "μg",
            "microgram" => "μg"
        )
        # Unitful.jl uses Greek μ for micrograms
        uq = uparse(u_mod)
        if dimension(uq) == dimension(u"g")
            # Convert to mg (our internal base)
            val_mg = ustrip(uconvert(u"mg", 1.0 * uq))
            return (:Mass, Float64(val_mg))
        end
    catch
    end

    return (:Other, 1.0)
end

"""
    MOLE_GetPercentageEquivalent_DDEF(Value, UnitStr, MW, Vol, Conc) -> Float64
Calculates the molar percentage contribution of a component within the system budget.
This is used for accurate baseline validation (rough check) before full matrix generation.
"""
function MOLE_GetPercentageEquivalent_DDEF(Value::Float64, UnitStr::String, MW::Float64, Vol::Float64, Conc::Float64)
    # 0. System Budget in Moles (mmol)
    (isnan(Vol) || isnan(Conc) || Vol <= 0.0 || Conc <= 0.0) && return 0.0
    total_moles_target_mmol = (Vol / 1000.0) * Conc
    (total_moles_target_mmol <= 0.0 || MW <= 0.0) && return 0.0
    
    u_type, u_scale = MOLE_GetUnitType_DDEF(UnitStr)
    u_str = lowercase(strip(UnitStr))
    
    if u_type == :Molar
        if u_str == "%m" || u_str == "%"
            return Value # Already a percentage
        else
            return Value 
        end
    elseif u_type == :Mass
        # Absolute Mass (mg) -> Moles -> Percentage of Target
        MW <= 0.0 && return 0.0
        moles_mmol = (Value * u_scale) / MW
        return (moles_mmol / total_moles_target_mmol) * 100.0
    elseif u_type == :Concentration
        # Absolute Concentration (mM) -> Moles -> Percentage of Target
        # Here u_scale converts to mM
        moles_mmol = (Vol / 1000.0) * (Value * u_scale)
        return (moles_mmol / total_moles_target_mmol) * 100.0
    end
    
    return 0.0
end

"""
    MOLE_ValidatePhysicalUnit_DDEF(ValueStr::String, ExpectedType::String) -> (Bool, Float64, String)
Uses strict dimensional analysis via Unitful.jl to ensure chemical/physical safety.
"""
function MOLE_ValidatePhysicalUnit_DDEF(ValueStr::String, ExpectedType::String)
    val_clean = strip(ValueStr)
    isempty(val_clean) && return (false, 0.0, "Input is empty.")

    # Convert space/underscore separators to multiplication for Unitful macro parsing
    parse_str = replace(val_clean, " " => "*", "_" => "*", "mc" => "u")

    try
        exp_val = uparse(parse_str)
        if typeof(exp_val) <: Real
            exp_val = exp_val * u"1" # Handle numeric only cases if any
        end

        tgt_unit      = nothing
        expected_name = ""

        if ExpectedType == "Volume"
            tgt_unit      = u"L"
            expected_name = "Volume (e.g., mL, L)"
        elseif ExpectedType == "Concentration"
            tgt_unit      = u"mol/L"
            expected_name = "Concentration (e.g., mM, mol/L)"
        elseif ExpectedType == "Mass"
            tgt_unit      = u"g"
            expected_name = "Mass (e.g., mg, g, kg)"
        elseif ExpectedType == "Time"
            tgt_unit      = u"hr"
            expected_name = "Time (e.g., s, min, hr)"
        elseif ExpectedType == "Ratio" || ExpectedType == "Dimensionless"
            tgt_unit      = u"1"
            expected_name = "Dimensionless Ratio"
        else
            return (false, 0.0, "Unknown physical dimension requested: $ExpectedType")
        end

        # Handle dimensionless cases from Unitful if needed
        if dimension(exp_val) == dimension(u"1")
             return (true, Float64(ustrip(exp_val)), "OK")
        end

        # Strict dimensionality check: is this biologically/physically identical to our target?
        if dimension(exp_val) != dimension(tgt_unit)
            return (false, 0.0, "Dimensional mismatch: Expected $expected_name, got $(dimension(exp_val)).")
        end

        # Convert and strip to raw Float64
        sys_val = uconvert(tgt_unit, 1.0 * exp_val)
        return (true, Float64(ustrip(sys_val)), "OK")
    catch e
        return (false, 0.0, "Unitful Parsing Error: Invalid format or unknown unit ('$val_clean') -> $e")
    end
end

# --------------------------------------------------------------------------------------
# GRAVIMETRIC AUDIT & SYSTEM CHECK
# --------------------------------------------------------------------------------------

"""
    MOLE_QuickAudit_DDEF(TableData, Vol, Conc) -> (Success, Report, ResultDF, TotalMass, FillInfo)
Performs a stoichiometry audit and automatically balances 'Filler' components.
"""
function MOLE_QuickAudit_DDEF(TableData::AbstractVector, Vol::Float64, Conc::Float64)
    D = MOLE_ParseTable_DDEF(TableData)
    ratios = Float64.(D["Mids"]) # Use mid-points for the audit

    idx_fill = D["Idx_Fill"]
    idx_chem = D["Idx_Chem"]
    num_vars = length(D["Idx_Var"])
    num_fills = length(idx_fill)

    io = IOBuffer()
    write(io, "=== SYSTEM GRAVIMETRIC AUDIT ===\n")
    @printf(io, "Environment: %.2f mL | Target: %.2f mM\n", Vol, Conc)
    write(io, "--------------------------------------\n")

    is_valid = true
    if num_vars != 3
        write(io, "![ERROR] Exactly 3 Variables required (Found: $num_vars)\n")
        is_valid = false
    end
    if num_fills > 1
        write(io, "![ERROR] Maximum 1 Filler allowed (Found: $num_fills)\n")
        is_valid = false
    end

    # Unit and MW validation audit
    for r in D["Rows"]
        unit = lowercase(strip(string(get(r, "Unit", ""))))
        mw = Float64(get(r, "MW", 0.0))
        name = string(get(r, "Name", "Unknown"))
        
        # --- NEGATIVE MW GUARD ---
        if mw < 0.0
            @printf(io, "![ERROR] Physical Impossibility: Component '%s' has negative Molecular Weight (%.2f). Calculation aborted.\n", name, mw)
            is_valid = false
        end

        # --- MW REQUIREMENT FOR RELATIONAL & CONCENTRATION UNITS ---
        if (unit == "%m" || unit == "mr" || unit == "ratio" || unit == "m") && mw <= 0.0
            @printf(io, "![ERROR] Stoichiometry Error: Component '%s' uses unit '%s' (Molar/Ratio) but has no Molecular Weight (MW). MW is mandatory for these calculations.\n", name, unit)
            is_valid = false
        end

        if mw > 0.0 && !isempty(unit) && unit != "-" && unit != "%m" && unit != "mr" && unit != "ratio" && unit != "m"
            u_type, _ = MOLE_GetUnitType_DDEF(unit)
            if u_type == :Other
                @printf(io, "![WARN] Unit Error: Component '%s' has invalid chemical unit '%s'.\n", name, unit)
            end
        end
    end

    # Filler auto-balance logic - SCIENTIFIC Molar Budget Awareness
    if !isempty(idx_fill) && is_valid
        fill_idx = idx_fill[1]
        consumed_pct = 0.0
        for k in eachindex(ratios)
            (k == fill_idx || D["MWs"][k] <= 0.0) && continue
            
            u_str = string(get(D["Rows"][k], "Unit", "-"))
            mw    = D["MWs"][k]
            val   = ratios[k]
            
            consumed_pct += MOLE_GetPercentageEquivalent_DDEF(val, u_str, mw, Vol, Conc)
        end
        
        if consumed_pct > 100.0 * (1.0 + 1e-6)
            @printf(io, "![ERROR] Filler balance failed: Consumed molar budget (%.2f%%) exceeds 100%%\n", consumed_pct)
            is_valid = false
            ratios[fill_idx] = 0.0
        else
            # The filler becomes the balancer to reach exactly 100%
            ratios[fill_idx] = max(0.0, 100.0 - consumed_pct)
        end
    end

    units = [string(get(r, "Unit", "")) for r in D["Rows"]]
    # Pass 0.0 for Scale as we use raw values in audit
    mass_results = MOLE_CalcMass_DDEF(
        D["Names"][idx_chem], D["MWs"][idx_chem], ratios[idx_chem], Vol, Conc, units[idx_chem]
    )

    # Check for over/under-concentration (Scientific Budget Integrity)
    total_moles_target_mmol = (Vol / 1000.0) * Conc
    if total_moles_target_mmol > 0 && is_valid
        total_moles_calc = sum(mass_results[!, :Moles_mmol])
        # Detect Over-concentration
        if total_moles_calc > total_moles_target_mmol * (1.0 + 1e-6) + 1e-9
            @printf(io, "![WARN] Over-Concentrated: Total moles (%.6f mmol) exceeds target (%.6f mmol). Breakdown reflects absolute input excess.\n", total_moles_calc, total_moles_target_mmol)
        # Detect Under-concentration (Budget Gap)
        elseif total_moles_calc < total_moles_target_mmol * (1.0 - 1e-6) - 1e-9
            @printf(io, "![WARN] Under-Concentrated: Total moles (%.6f mmol) is below target budget. Ensure a 'Filler' or sufficient 'Ratio' components are defined.\n", total_moles_calc)
        end
    end

    total_mass_mg = sum(mass_results[!, :TARGET_MASS_mg])

    write(io, "\n[CHEMICAL BREAKDOWN]\n")
    for (i, row) in enumerate(eachrow(mass_results))
        role = D["Roles"][idx_chem[i]]
        u_label = if role == "Filler"
            "(System Filler)"
        else
            row[:IsFixed] ? "(Absolute/Fixed)" : "(Relational MR)"
        end
        u_raw   = lowercase(strip(units[idx_chem][i]))
        
        # Mandatory units for MW
        is_relational = (u_raw == "%m" || u_raw == "mr" || u_raw == "ratio" || u_raw == "m")
        mw_missing    = is_relational && (D["MWs"][idx_chem][i] <= 0.0 || isnan(D["MWs"][idx_chem][i]))
        mw_warn       = mw_missing ? " [⚠️ MW MISSING]" : ""
        
        @printf(io, "> %-15s: %9.3f mg %-15s (Ratio: %6.1f%%)%s\n",
            row[:Component], row[:TARGET_MASS_mg], u_label, row[:Molar_Ratio], mw_warn)
    end

    write(io, "\n[SOLVENT / MATRIX]\n")
    if Vol > 0
        # Assume density approx 1.0 g/mL (water-based) for estimation if needed.
        @printf(io, "> Solvent Req.   : Fill up to %.2f mL total volume\n", Vol)
    else
        write(io, "> No liquid environment defined.\n")
    end

    write(io, "--------------------------------------\n")
    @printf(io, "SUM DRY MASS : %9.4f mg\n", total_mass_mg)

    # Tolerance-based fraction validation
    target_moles_mmol = (Vol / 1000.0) * Conc
    if target_moles_mmol > 0
        moles_sum = sum(mass_results[!, :Moles_mmol])
        # Use isapprox with relative tolerance for different scales (uM to M)
        frac_ok = isapprox(moles_sum, target_moles_mmol; rtol=1e-6, atol=1e-10)
        if !frac_ok
            @printf(io, "\n[WARN] Meticulous check: Molar balance deviation. Sum = %.8f (targeted %.8f)\n", moles_sum, target_moles_mmol)
        end
    end

    fill_status = if isempty(idx_fill)
        "Direct Fractions (No filler)"
    else
        f_name, f_val = D["Names"][idx_fill[1]], ratios[idx_fill[1]]
        write(io, "\n[SYSTEM] Filler '$f_name' auto-balanced to $(round(f_val; digits=2))%")
        "$f_name: $(round(f_val; digits=2))%"
    end

    Main.Sys_Fast.FAST_Log_DDEF("MOLE", "AUDIT_COMPLETE",
        "Total Mass: $(round(total_mass_mg; digits=2)) mg", "OK")

    return (
        is_valid && total_mass_mg > 0 && !isempty(mass_results),
        String(take!(io)),
        mass_results,
        total_mass_mg,
        fill_status,
    )
end

# --------------------------------------------------------------------------------------
# STOICHIOMETRY ENGINE (Core Calculations)
# --------------------------------------------------------------------------------------

"""
    MOLE_CalcMass_DDEF(Names, MWs, Ratios, Vol, Conc, Units, [Scale]) -> DataFrame
Universal Stoichiometry Engine (Three-Pass Hybrid Model).
1. Pass 1: Resolve Absolute Mass (mg) & Molarity (mM) components.
2. Pass 2: Resolve Fixed Molar Percent (%M) components (Slices of total budget).
3. Pass 3: Resolve Relative Molar Ratios (MR) (Dividing the residual budget).
"""
function MOLE_CalcMass_DDEF(Names::AbstractVector{String}, MWs::AbstractVector{Float64},
    Ratios::AbstractVector{Float64}, Tgt_Vol::Float64, Tgt_Conc::Float64,
    Units::AbstractVector{String}, Scale::Float64=1.0; SuppressLog::Bool=false)
    
    n_comp = length(Names)
    res_mass_mg = zeros(n_comp)
    res_moles_mmol = zeros(n_comp)
    is_fixed = fill(false, n_comp)

    # 0. System Budget
    (isnan(Tgt_Vol) || isnan(Tgt_Conc) || Tgt_Vol <= 0.0 || Tgt_Conc <= 0.0) && return DataFrame(
        :Component      => Names,
        :Molar_Ratio    => zeros(n_comp),
        :Moles_mmol     => zeros(n_comp),
        :TARGET_MASS_mg => zeros(n_comp),
        :IsFixed        => [true for _ in 1:n_comp]
    )
    total_moles_target_mmol = (Tgt_Vol / 1000.0) * (Tgt_Conc * Scale)

    # Pass 1: Resolve Absolute (Fixed Mass / Molarity) components
    for i in 1:n_comp
        u_type, u_scale = MOLE_GetUnitType_DDEF(Units[i])
        if u_type == :Mass
            res_mass_mg[i]    = Ratios[i] * u_scale
            res_moles_mmol[i] = MWs[i] > 0 ? res_mass_mg[i] / MWs[i] : 0.0
            is_fixed[i]      = true
        elseif u_type == :Concentration
            # Absolute Molarity (M -> mM)
            target_mM = Ratios[i] * u_scale
            res_moles_mmol[i] = (Tgt_Vol / 1000.0) * target_mM
            res_mass_mg[i]    = MWs[i] > 0 ? res_moles_mmol[i] * MWs[i] : 0.0
            is_fixed[i]      = true
        end
    end

    # Pass 2: Resolve Absolute Molar % (%M) components
    for i in 1:n_comp
        if !is_fixed[i]
            u_str = lowercase(strip(Units[i]))
            if u_str == "%m" || u_str == "%"
                if MWs[i] > 0
                    # %M is literally Molar Percentage of the Target Concentration
                    res_moles_mmol[i] = total_moles_target_mmol * (Ratios[i] / 100.0)
                    res_mass_mg[i]    = res_moles_mmol[i] * MWs[i]
                    is_fixed[i]       = true # Mark as resolved for the next pass
                else
                    # Fallback or Error: MW is required for molar percent
                    res_moles_mmol[i] = 0.0
                    res_mass_mg[i]    = 0.0
                end
            end
        end
    end

    # Pass 3: Resolve Relative Molar Relational components (MR / Ratio)
    fixed_moles_sum_mmol = sum(res_moles_mmol)
    residual_moles_mmol  = total_moles_target_mmol - fixed_moles_sum_mmol

    # --- SCIENTIFIC GUARD: OVER-CONCENTRATION ---
    if residual_moles_mmol < -1e-7
        if !SuppressLog
            Main.Sys_Fast.FAST_Log_DDEF("MOLE", "BUDGET_EXCEEDED", 
                "Molar budget overflow: sum of absolute components ($(round(fixed_moles_sum_mmol; digits=4)) mmol) exceeds target ($(round(total_moles_target_mmol; digits=4)) mmol).", "WARN")
        end
        residual_moles_mmol = 0.0
    end

    molar_indices = findall(.!is_fixed)
    if !isempty(molar_indices)
        total_molar_parts = sum(Ratios[molar_indices])
        total_molar_parts = MOLE_ApproxEq_DDEF(total_molar_parts, 0.0) ? 1.0 : total_molar_parts

        for i in molar_indices
            if MWs[i] > 0
                ratio_frac = Ratios[i] / total_molar_parts
                res_moles_mmol[i] = residual_moles_mmol * ratio_frac
                res_mass_mg[i]    = res_moles_mmol[i] * MWs[i]
            else
                res_moles_mmol[i] = 0.0
                res_mass_mg[i]    = 0.0
            end
        end
    end

    # Final Molar Ratio representation (Force back-calculation for information context)
    final_ratios = copy(Ratios)
    if total_moles_target_mmol > 0
        for i in 1:n_comp
             final_ratios[i] = (res_moles_mmol[i] / total_moles_target_mmol) * 100.0
        end
    end

    return DataFrame(
        :Component      => Names,
        :Molar_Ratio    => final_ratios,
        :Moles_mmol     => res_moles_mmol,
        :TARGET_MASS_mg => res_mass_mg,
        :IsFixed        => is_fixed
    )
end

"""
    MOLE_AuditMatrix_DDEF(Design, Names, MWs, Vol, Conc, [Units]) -> Vector{Float64}
Calculates total mass required for each run (detection of 'Impossible Runs').
"""
function MOLE_AuditMatrix_DDEF(Design::AbstractMatrix, Names::AbstractVector,
    MWs::AbstractVector, Vol::Float64, Conc::Float64, Units::AbstractVector=fill("-", length(Names)))
    R, C         = size(Design)
    total_masses = Vector{Float64}(undef, R)

    # Note: Design MUST correspond exactly to Names/MWs columns here
    if C != length(Names)
        return zeros(R) # Dimension mismatch safety
    end

    for i in 1:R
        ratios          = Design[i, :]
        df              = MOLE_CalcMass_DDEF(Names, MWs, ratios, Vol, Conc, Units)
        total_masses[i] = sum(df.TARGET_MASS_mg)
    end
    
    return total_masses
end

"""
    MOLE_AuditBatch_DDEF(TableData, Design, Vol, Conc) -> Dict
Performs high-level feasibility audit on a proposed experimental batch.
"""
function MOLE_AuditBatch_DDEF(TableData::AbstractVector, Design::AbstractMatrix,
    Vol::Float64, Conc::Float64)
    D       = MOLE_ParseTable_DDEF(TableData)
    idx_var = D["Idx_Var"]
    idx_chem = D["Idx_Chem"]

    R, C = size(Design)

    # Validation: Matrix columns must match Variable count
    if C != length(idx_var)
        return Dict(
            "IsFeasible" => true,
            "AvgMass_mg" => 0.0, 
            "MaxMass_mg" => 0.0, 
            "MinMass_mg" => 0.0, 
            "StdDev_mg"  => 0.0,
            "RunMasses"  => zeros(R)
        )
    end

    # Mapping variables, fixed values and auto-balancing filler
    idx_fix  = D["Idx_Fix"]
    idx_fill = D["Idx_Fill"]

    masses = Vector{Float64}(undef, R)
    for i in 1:R
        # Initialise full ratio vector for the current run
        ratios_full = zeros(length(D["Names"]))
        for (j, v_idx) in enumerate(idx_var)
            ratios_full[v_idx] = Design[i, j]
        end
        for f_idx in idx_fix
            ratios_full[f_idx] = D["Mids"][f_idx]
        end

        if !isempty(idx_fill)
            consumed_pct = 0.0
            for k in eachindex(ratios_full)
                (k == idx_fill[1] || D["MWs"][k] <= 0.0) && continue
                
                u_str = string(get(D["Rows"][k], "Unit", "-"))
                mw    = D["MWs"][k]
                val   = ratios_full[k]
                
                consumed_pct += MOLE_GetPercentageEquivalent_DDEF(val, u_str, mw, Vol, Conc)
            end
            
            # Balance filler to reach 100% of the target molar concentration
            ratios_full[idx_fill[1]] = max(0.0, 100.0 - consumed_pct)
        end

        # Extract chemical-only data for gravimetric calculation
        r_chem = ratios_full[idx_chem]
        n_chem = D["Names"][idx_chem]
        w_chem = D["MWs"][idx_chem]
        u_chem = [string(get(r, "Unit", "-")) for r in D["Rows"][idx_chem]]

        if isempty(idx_chem)
            masses[i] = 0.0
        else
            df        = MOLE_CalcMass_DDEF(n_chem, w_chem, r_chem, Vol, Conc, u_chem; SuppressLog=true)
            masses[i] = sum(df.TARGET_MASS_mg)
        end
    end

    avg_mass = isempty(masses) ? 0.0 : mean(masses)
    max_mass = isempty(masses) ? 0.0 : maximum(masses)
    min_mass = isempty(masses) ? 0.0 : minimum(masses)
    std_mass = length(masses) > 1 ? std(masses) : 0.0

    # Tolerance-safe feasibility check
    is_feasible = isempty(idx_chem) || (min_mass >= -1e-6 && avg_mass >= 0.0)

    return Dict(
        "IsFeasible" => is_feasible,
        "AvgMass_mg" => avg_mass,
        "MaxMass_mg" => max_mass,
        "MinMass_mg" => min_mass,
        "StdDev_mg"  => std_mass,
        "RunMasses"  => masses
    )
end

"""
    MOLE_ValidateDesignFeasibility_DDEF(DesignMatrix, InMeta, [Vol], [Conc]) -> (Bool, String)
Advanced stoichiometric feasibility check for design matrices. 
Validated against actual run coordinates to ensure operational safety.
"""
function MOLE_ValidateDesignFeasibility_DDEF(DesignMatrix::AbstractMatrix, InMeta::AbstractVector, Vol::Float64=100.0, Conc::Float64=10.0)
    R, C   = size(DesignMatrix)
    chems  = [m for m in InMeta if get(m, "Role", "") != "Result"]
    
    # Identify indices
    var_indices   = findall(m -> get(m, "Role", "") == "Variable", chems)
    fill_index    = findfirst(m -> get(m, "Role", "") == "Filler", chems)
    fixed_indices = findall(m -> get(m, "Role", "") == "Fixed", chems)

    issues = String[]

    for i in 1:R
        ratios = zeros(length(chems))
        # Map matrix columns back to Variable positions
        for (j, matrix_col) in enumerate(var_indices)
            ratios[matrix_col] = DesignMatrix[i, j]
        end
        # Add Fixed values
        for idx in fixed_indices
            ratios[idx] = Main.Sys_Fast.FAST_SafeNum_DDEF(get(chems[idx], "L2", 0.0))
        end

        # Run-Specific Stoichiometric Budget Check
        total_consumed_pct = 0.0
        for k in eachindex(chems)
            role = get(chems[k], "Role", "")
            mw   = Sys_Fast.FAST_SafeNum_DDEF(get(chems[k], "MW", 0.0))
            (role == "Filler" || mw <= 0.0) && continue
            
            val  = ratios[k]
            unit = string(get(chems[k], "Unit", "-"))
            
            total_consumed_pct += MOLE_GetPercentageEquivalent_DDEF(val, unit, mw, Vol, Conc)
        end
        
        if total_consumed_pct > 100.0 + 1e-4
            push!(issues, "Run $i: Stoichiometric budget overflow ($(round(total_consumed_pct; digits=2))%).")
        end

        # Check for negative ratios
        if any(<(0.0), ratios)
            push!(issues, "Run $i: Contains negative chemical gradients.")
        end
    end

    valid = isempty(issues)
    msg   = valid ? "Stoichiometric feasibility confirmed for all runs." : join(unique(issues), " | ")

    return (valid, msg)
end

"""
    MOLE_ProcessDesign_DDEF(DesignMatrix::AbstractMatrix, TableData::AbstractVector, Vol::Float64, Conc::Float64) -> DataFrame
Expands a design matrix into a full experimental protocol with mass calculations and filler balancing.
Centralises stoichiometry logic to ensure scientific consistency across the system.
"""
function MOLE_ProcessDesign_DDEF(DesignMatrix::AbstractMatrix, TableData::AbstractVector, Vol::Float64, Conc::Float64)
    D = MOLE_ParseTable_DDEF(TableData)
    C = Main.Sys_Fast.FAST_Data_DDEC
    R, C_dim = size(DesignMatrix)
    
    # 1. Structural Container (Columns in Scientific Order)
    df = DataFrame()
    
    # Variable Headers
    for (k, v_idx) in enumerate(D["Idx_Var"])
        u = string(get(D["Rows"][v_idx], "Unit", ""))
        h = (isempty(u) || u == "-") ? C.PRE_INPUT * D["Names"][v_idx] : C.PRE_INPUT * D["Names"][v_idx] * "_" * u
        df[!, h] = DesignMatrix[:, k]
    end
    
    # Fixed Headers
    for idx in D["Idx_Fix"]
        u = string(get(D["Rows"][idx], "Unit", ""))
        h = (isempty(u) || u == "-") ? C.PRE_FIXED * D["Names"][idx] : C.PRE_FIXED * D["Names"][idx] * "_" * u
        df[!, h] = fill(Main.Sys_Fast.FAST_SafeNum_DDEF(D["Rows"][idx]["L2"]), R)
    end
    
    # Filler Headers
    for idx in D["Idx_Fill"]
        u = string(get(D["Rows"][idx], "Unit", ""))
        h = (isempty(u) || u == "-") ? C.PRE_FILL * D["Names"][idx] : C.PRE_FILL * D["Names"][idx] * "_" * u
        df[!, h] = fill(0.0, R)
    end

    # 2. RUN-TIME COMPUTATION (Pass: Filler -> Moles -> Mass)
    mass_cols = Dict{String, Vector{Float64}}()
    
    for i in 1:R
        # Assemble local stoichiometry vector
        current_ratios = zeros(length(D["Names"]))
        for (k, v_idx) in enumerate(D["Idx_Var"])
            current_ratios[v_idx] = DesignMatrix[i, k]
        end
        for idx in D["Idx_Fix"]
            current_ratios[idx] = Main.Sys_Fast.FAST_SafeNum_DDEF(D["Rows"][idx]["L2"])
        end
        
        # Filler Balancing: Centralised budget subtraction
        if !isempty(D["Idx_Fill"])
            consumed_pct = 0.0
            for r_idx in D["Idx_Chem"]
                (r_idx == D["Idx_Fill"][1] || D["MWs"][r_idx] <= 0.0) && continue
                val  = current_ratios[r_idx]
                unit = string(get(D["Rows"][r_idx], "Unit", "-"))
                mw   = D["MWs"][r_idx]
                consumed_pct += MOLE_GetPercentageEquivalent_DDEF(val, unit, mw, Vol, Conc)
            end
            
            f_idx = D["Idx_Fill"][1]
            f_val = max(0.0, 100.0 - consumed_pct)
            current_ratios[f_idx] = f_val
            
            # Sync value back to the main dataframe
            u = string(get(D["Rows"][f_idx], "Unit", ""))
            h = (isempty(u) || u == "-") ? C.PRE_FILL * D["Names"][f_idx] : C.PRE_FILL * D["Names"][f_idx] * "_" * u
            df[i, h] = f_val
        end
        
        # CONVERSION TO MASS (mg)
        chems = D["Idx_Chem"]
        units = [string(get(r, "Unit", "-")) for r in D["Rows"][chems]]
        m_df  = MOLE_CalcMass_DDEF(D["Names"][chems], D["MWs"][chems], current_ratios[chems], Vol, Conc, units)
        
        for r in eachrow(m_df)
            k = C.PRE_MASS * r.Component * "_mg"
            haskey(mass_cols, k) || (mass_cols[k] = zeros(R))
            mass_cols[k][i] = r.TARGET_MASS_mg
        end
    end
    
    # Merge mass audit columns
    for (ckey, cval) in mass_cols
        df[!, ckey] = cval
    end
    
    return df
end

end # module Lib_Mole
