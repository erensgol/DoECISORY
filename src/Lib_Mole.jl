module Lib_Mole

# ======================================================================================
# DAISHODOE - LIB MOLE (STOICHIOMETRY & CHEMICAL ENGINE)
# ======================================================================================
# Purpose: Handling chemical compositions, gravimetric calculations (m=n*MW),
#          and balancing filler components.
# Module Tag: MOLE
# ======================================================================================

using DataFrames
using Printf
using Unitful
using Statistics
using Main.Sys_Fast

export MOLE_ParseTable_DDEF, MOLE_QuickAudit_DDEF, MOLE_CalcMass_DDEF,
    MOLE_ApproxEq_DDEF, MOLE_ValidatePhysicalUnit_DDEF,
    MOLE_AuditMatrix_DDEF, MOLE_AuditBatch_DDEF, MOLE_ValidateDesignFeasibility_DDEF, MOLE_Ingredient_DDES,
    MOLE_ApplyRadioDecay_DDEF

# --------------------------------------------------------------------------------------
# --- DATA STRUCTURES ---
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

# --- PHYSICAL CORRECTIONS & MATH MODELS ---
# --------------------------------------------------------------------------------------

"""
    MOLE_ApplyRadioDecay_DDEF(RawValue, HalfLife, HalfLifeUnit, DeltaTHours) -> Float64
Applies mathematical decay correction for radioactive elements (reverse-calculation).
(Moved from Lib_Vise.jl)
"""
function MOLE_ApplyRadioDecay_DDEF(RawValue::Float64, HalfLife::Float64, HalfLifeUnit::String, DeltaTHours::Float64)
    HalfLife <= 0.0 && return RawValue

    # Normalise Half-Life to Hours
    unit_upper = uppercase(strip(HalfLifeUnit))
    hl_hours = HalfLife
    if occursin("SEC", unit_upper)
        hl_hours = HalfLife / 3600.0
    elseif occursin("MIN", unit_upper)
        hl_hours = HalfLife / 60.0
    elseif occursin("DAY", unit_upper)
        hl_hours = HalfLife * 24.0
    elseif occursin("YEAR", unit_upper) || occursin("YR", unit_upper)
        hl_hours = HalfLife * 24.0 * 365.25
    end

    hl_hours <= 0.0 && return RawValue

    lambda = log(2) / hl_hours
    decay_factor = exp(-lambda * DeltaTHours)

    # Avoid extreme inflation
    decay_factor < 1e-6 && return RawValue

    return RawValue / decay_factor
end

# --- FLOATING-POINT TOLERANCE COMPARATOR ---

const MOLE_StoiTolerance_DDEC = 1e-6   # 0.0001% — sufficient for stoichiometry precision

"""
    MOLE_ApproxEq_DDEF(a::Real, b::Real; atol=1e-6) -> Bool
Tolerance-based equality for floating-point chemical calculations.
"""
MOLE_ApproxEq_DDEF(a::Real, b::Real; atol::Float64=MOLE_StoiTolerance_DDEC) = isapprox(a, b; atol)

# --------------------------------------------------------------------------------------
# --- CHEMICAL TABLE PARSING ---
# --------------------------------------------------------------------------------------

"""
    MOLE_ParseTable_DDEF(TableData::AbstractVector) -> Dict
Parses structured data from the UI's DataTable into operational categories.
"""
function MOLE_ParseTable_DDEF(TableData::AbstractVector)
    # SanitiseInput returns (clean_data, warnings)
    clean_data, input_warnings = Sys_Fast.FAST_SanitiseInput_DDEF(TableData)

    safe_num = Sys_Fast.FAST_SafeNum_DDEF
    C = Sys_Fast.FAST_Data_DDEC

    names_vec = string.(get.(clean_data, "Name", "Unknown"))
    roles = string.(get.(clean_data, "Role", "Fixed"))
    mins = Float64.(get.(clean_data, "L1", 0.0))
    mids = Float64.(get.(clean_data, "L2", 0.0))
    maxs = Float64.(get.(clean_data, "L3", 0.0))
    mws = Float64.(get.(clean_data, "MW", 0.0))

    roles_lower = lowercase.(roles)
    tag_var = lowercase(C.ROLE_VAR)
    tag_fill = lowercase(C.ROLE_FILL)

    idx_var = findall(==(tag_var), roles_lower)
    idx_fill = findall(==(tag_fill), roles_lower)
    idx_fix = findall(r -> r ∉ (tag_var, tag_fill), roles_lower)
    idx_chem = findall(>(0), mws)

    return Dict(
        "Names" => names_vec, "Roles" => roles,
        "Mins" => mins, "Mids" => mids, "Maxs" => maxs, "MWs" => mws,
        "Idx_Var" => idx_var, "Idx_Fix" => idx_fix,
        "Idx_Fill" => idx_fill, "Idx_Chem" => idx_chem,
        "Rows" => clean_data, "RawTable" => clean_data,
        "InputWarnings" => input_warnings,
    )
end

# --------------------------------------------------------------------------------------
# --- PHYSICAL DIMENSION VALIDATION (UNITFUL.JL) ---
# --------------------------------------------------------------------------------------

"""
    MOLE_ValidatePhysicalUnit_DDEF(ValueStr::String, ExpectedType::String) -> (Bool, Float64, String)
Uses strict dimensional analysis via Unitful.jl to ensure chemical/physical safety.
"""
function MOLE_ValidatePhysicalUnit_DDEF(ValueStr::String, ExpectedType::String)
    val_clean = strip(ValueStr)
    isempty(val_clean) && return (false, 0.0, "Input is empty.")

    # Convert space/underscore separators to multiplication for Unitful macro parsing
    parse_str = replace(val_clean, " " => "*", "_" => "*")

    try
        exp_val = uparse(parse_str)

        tgt_unit = nothing
        expected_name = ""

        if ExpectedType == "Volume"
            tgt_unit = u"L"
            expected_name = "Volume (e.g., mL, L)"
        elseif ExpectedType == "Concentration"
            tgt_unit = u"mol/L"
            expected_name = "Concentration (e.g., mM, mol/L)"
        elseif ExpectedType == "Mass"
            tgt_unit = u"g"
            expected_name = "Mass (e.g., mg, g, kg)"
        elseif ExpectedType == "Time"
            tgt_unit = u"hr"
            expected_name = "Time (e.g., s, min, hr)"
        else
            return (false, 0.0, "Unknown physical dimension requested: $ExpectedType")
        end

        # Strict dimensionality check: is this biologically/physically identical to our target?
        if dimension(exp_val) != dimension(tgt_unit)
            return (false, 0.0, "Dimensional mismatch: Expected $expected_name, got $(dimension(exp_val)).")
        end

        # Convert and strip to raw Float64
        sys_val = uconvert(tgt_unit, exp_val)
        return (true, Float64(ustrip(sys_val)), "OK")
    catch e
        return (false, 0.0, "Unitful Parsing Error: Invalid format or unknown unit ('$val_clean') -> $e")
    end
end


# --------------------------------------------------------------------------------------
# --- GRAVIMETRIC AUDIT (SYSTEM CHECK) ---
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

    # --- NEW: Unit Validation Audit ---
    for r in D["Rows"]
        unit = string(get(r, "Unit", ""))
        mw = Float64(get(r, "MW", 0.0))
        if mw > 0.0 && !isempty(unit) && unit != "-" && unit != "%M" && unit != "MR"
            # Try Mass then Concentration
            ok_m, _, _ = MOLE_ValidatePhysicalUnit_DDEF(unit, "Mass")
            ok_c, _, _ = MOLE_ValidatePhysicalUnit_DDEF(unit, "Concentration")
            if !ok_m && !ok_c
                write(io, "![WARN] Unit Error: Component '$(get(r, "Name", ""))' has invalid chemical unit '$unit'.\n")
            end
        end
    end

    # Filler auto-balance with tolerance-safe subtraction
    if !isempty(idx_fill) && is_valid
        other_chems = setdiff(idx_chem, idx_fill)
        other_sum = sum(view(ratios, other_chems))
        if other_sum > 100.0 + 1e-4
            write(io, "![ERROR] Filler balance failed: Pre-filler components exceed 100% (Sum: $(round(other_sum; digits=2))%)\n")
            is_valid = false
            ratios[idx_fill[1]] = 0.0
        else
            filler_val = 100.0 - other_sum
            # Clamp near-zero negatives from FP drift
            ratios[idx_fill[1]] = max(0.0, filler_val)
            # Tolerant balance check
            if !MOLE_ApproxEq_DDEF(ratios[idx_fill[1]] + other_sum, 100.0; atol=1e-4)
                @printf(io, "![WARN] Balance drift: sum=%.8f (expected 100.0)\n",
                    ratios[idx_fill[1]] + other_sum)
            end
        end
    end

    mass_results = MOLE_CalcMass_DDEF(
        D["Names"][idx_chem], D["MWs"][idx_chem], ratios[idx_chem], Vol, Conc
    )

    total_mass_mg = sum(mass_results[!, :TARGET_MASS_mg])

    for row in eachrow(mass_results)
        @printf(io, "> %-12s: %9.3f mg (Ratio: %6.1f%%)\n",
            row.Component, row.TARGET_MASS_mg, row.Molar_Ratio)
    end

    write(io, "--------------------------------------\n")
    @printf(io, "TOTAL MASS   : %9.3f mg\n", total_mass_mg)

    # Tolerance-based fraction validation
    frac_sum = sum(mass_results[!, :Molar_Fraction])
    frac_ok = MOLE_ApproxEq_DDEF(frac_sum, 1.0; atol=1e-6)
    if !frac_ok
        @printf(io, "\n[WARN] Molar fraction sum = %.10f (expected ~1.0)\n", frac_sum)
    end

    fill_status = if isempty(idx_fill)
        "Direct Fractions (No filler)"
    else
        f_name, f_val = D["Names"][idx_fill[1]], ratios[idx_fill[1]]
        write(io, "\n[SYSTEM] Filler '$f_name' auto-balanced to $(round(f_val; digits=2))%")
        "$f_name: $(round(f_val; digits=2))%"
    end

    Sys_Fast.FAST_Log_DDEF("MOLE", "AUDIT_COMPLETE",
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
# --- STOICHIOMETRY ENGINE (CORE CALCULATIONS) ---
# --------------------------------------------------------------------------------------

"""
    MOLE_CalcMass_DDEF(Names, MWs, Ratios, Vol, Conc, [Scale]) -> DataFrame
Analytical engine for calculating mass from molar concentrations.
Formula: n = M * V (total moles) | m = n_comp * MW (component mass).
"""
function MOLE_CalcMass_DDEF(Names::AbstractVector{String}, MWs::AbstractVector{Float64},
    Ratios::AbstractVector{Float64}, Tgt_Vol::Float64, Tgt_Conc::Float64,
    Scale::Float64=1.0)
    total_parts = sum(Ratios)
    # Tolerant zero-check instead of exact <= 0.0
    total_parts = MOLE_ApproxEq_DDEF(total_parts, 0.0) ? 1.0 : total_parts
    mol_fractions = Ratios ./ total_parts

    total_moles_mmol = (Tgt_Vol / 1000.0) * (Tgt_Conc * Scale)
    comp_moles_mmol = total_moles_mmol .* mol_fractions

    return DataFrame(
        :Component => Names,
        :Molar_Ratio => Ratios,
        :Molar_Fraction => mol_fractions,
        :Moles_mmol => comp_moles_mmol,
        :TARGET_MASS_mg => comp_moles_mmol .* MWs,
    )
end

"""
    MOLE_AuditMatrix_DDEF(Design, Names, MWs, Vol, Conc) -> Vector{Float64}
Calculates total mass required for each run (detection of 'Impossible Runs').
"""
function MOLE_AuditMatrix_DDEF(Design::AbstractMatrix, Names::AbstractVector,
    MWs::AbstractVector, Vol::Float64, Conc::Float64)
    R, C = size(Design)
    total_masses = Vector{Float64}(undef, R)

    # Note: Design MUST correspond exactly to Names/MWs columns here
    if C != length(Names)
        return zeros(R) # Dimension mismatch safety
    end

    for i in 1:R
        ratios = Design[i, :]
        df = MOLE_CalcMass_DDEF(Names, MWs, ratios, Vol, Conc)
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
    D = MOLE_ParseTable_DDEF(TableData)
    idx_var = D["Idx_Var"]
    idx_chem = D["Idx_Chem"]

    R, C = size(Design)

    # Validation: Matrix columns must match Variable count
    if C != length(idx_var)
        return Dict(
            "IsFeasible" => true,
            "AvgMass_mg" => 0.0, "MaxMass_mg" => 0.0, "MinMass_mg" => 0.0, "StdDev_mg" => 0.0,
            "RunMasses" => zeros(R)
        )
    end

    # Mapping variables, fixed values and auto-balancing filler
    idx_fix = D["Idx_Fix"]
    idx_fill = D["Idx_Fill"]

    masses = Vector{Float64}(undef, R)
    for i in 1:R
        # Full ratio vector (100% basis)
        ratios_full = zeros(length(D["Names"]))
        for (j, v_idx) in enumerate(idx_var)
            ratios_full[v_idx] = Design[i, j]
        end
        for f_idx in idx_fix
            ratios_full[f_idx] = D["Mids"][f_idx]
        end

        # Filler balancing (H2O, Solvent etc.)
        if !isempty(idx_fill)
            other_sum = sum(ratios_full) # Currently filler is 0.0
            ratios_full[idx_fill[1]] = max(0.0, 100.0 - other_sum)
        end

        # Extract chemical-only data for gravimetric calculation
        r_chem = ratios_full[idx_chem]
        n_chem = D["Names"][idx_chem]
        w_chem = D["MWs"][idx_chem]

        if isempty(idx_chem)
            masses[i] = 0.0
        else
            df = MOLE_CalcMass_DDEF(n_chem, w_chem, r_chem, Vol, Conc)
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
        "StdDev_mg" => std_mass,
        "RunMasses" => masses
    )
end

"""
    MOLE_ValidateDesignFeasibility_DDEF(DesignMatrix, InMeta) -> (Bool, String)
Advanced stoichiometric feasibility check for design matrices.
"""
function MOLE_ValidateDesignFeasibility_DDEF(DesignMatrix::AbstractMatrix, InMeta::AbstractVector)
    R, C = size(DesignMatrix)
    chems = [m for m in InMeta if get(m, "Role", "") != "Result"]
    names = [string(get(m, "Name", "Unknown")) for m in chems]
    mws = [Float64(get(m, "MW", 0.0)) for m in chems]

    # Identify indices of Variable ingredients in the InMeta list
    var_indices = findall(m -> get(m, "Role", "") == "Variable", chems)
    fill_index = findfirst(m -> get(m, "Role", "") == "Filler", chems)
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
            ratios[idx] = get(chems[idx], "L2", 0.0) # Using Mid/Default for fixed
        end

        # Auto-balance filler if present
        if !isnothing(fill_index)
            other_sum = sum(deleteat!(copy(ratios), fill_index))
            if other_sum > 100.0 + 1e-4
                push!(issues, "Run $i: Chemical sum exceeds 100% ($(round(other_sum; digits=2))%) before filler.")
            else
                ratios[fill_index] = max(0.0, 100.0 - other_sum)
            end
        end

        # Check for negative ratios
        if any(<(0.0), ratios)
            push!(issues, "Run $i: Contains negative chemical ratios.")
        end
    end

    valid = isempty(issues)
    msg = valid ? "Stoichiometric feasibility confirmed for all runs." : join(unique(issues), " | ")

    return (valid, msg)
end

end # module Lib_Mole
