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
using Main.Sys_Fast

export MOLE_ParseTable_DDEF, MOLE_QuickAudit_DDEF, MOLE_CalcMass_DDEF,
    MOLE_ApproxEq_DDEF, DaishoIngredient

# --------------------------------------------------------------------------------------
# SECTION 1: DATA STRUCTURES
# --------------------------------------------------------------------------------------

"""
    DaishoIngredient
Represents the chemical and operational properties of a single component.
"""
struct DaishoIngredient
    Name::String
    Role::String            # Expected values: "Variable", "Fixed", "Filler"
    Levels::Vector{Float64} # [Min, Mid, Max] values
    MW::Float64             # Molecular Weight (g/mol)
end

# ── Floating-Point Tolerance Comparator ──────────────────────────────────────

const _STOI_TOLERANCE = 1e-6   # 0.0001% — sufficient for stoichiometry precision

"""
    MOLE_ApproxEq_DDEF(a, b; atol=1e-6) -> Bool
Tolerance-based equality for floating-point chemical calculations.
Replaces all exact `==` comparisons in stoichiometric contexts.
"""
MOLE_ApproxEq_DDEF(a::Real, b::Real; atol::Float64=_STOI_TOLERANCE) = isapprox(a, b; atol)

# --------------------------------------------------------------------------------------
# SECTION 2: CHEMICAL TABLE PARSING
# --------------------------------------------------------------------------------------

"""
    MOLE_ParseTable_DDEF(TableData) -> Dict
Parses the structured data from the UI's DataTable into operational categories.
Categorizes ingredients by role (Variable, Fixed, Filler) and molecular properties.
"""
function MOLE_ParseTable_DDEF(TableData::AbstractVector)
    # SanitizeInput returns (clean_data, warnings)
    clean_data, input_warnings = Sys_Fast.FAST_SanitizeInput_DDEF(TableData)

    safe_num = Sys_Fast.FAST_SafeNum_DDEF
    CONST = Sys_Fast.FAST_Constants_DDEF()

    names_vec = string.(get.(clean_data, "Name", "Unknown"))
    roles = string.(get.(clean_data, "Role", "Fixed"))
    mins = Float64.(get.(clean_data, "L1", 0.0))
    mids = Float64.(get.(clean_data, "L2", 0.0))
    maxs = Float64.(get.(clean_data, "L3", 0.0))
    mws = Float64.(get.(clean_data, "MW", 0.0))

    roles_lower = lowercase.(roles)
    tag_var = lowercase(CONST.ROLE_VAR)
    tag_fill = lowercase(CONST.ROLE_FILL)

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
# SECTION 3: GRAVIMETRIC AUDIT (SYSTEM CHECK)
# --------------------------------------------------------------------------------------

"""
    MOLE_QuickAudit_DDEF(TableData, Vol, Conc) -> (Report, ResultDF, TotalMass, FillInfo)
Performs a stoichiometry audit on the current experiment configuration.
Automatically balances 'Filler' components to maintain molar fraction integrity.
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

    # Filler auto-balance with tolerance-safe subtraction
    if !isempty(idx_fill) && is_valid
        other_chems = setdiff(idx_chem, idx_fill)
        other_sum = sum(view(ratios, other_chems))
        filler_val = 100.0 - other_sum
        # Clamp near-zero negatives from FP drift
        ratios[idx_fill[1]] = max(0.0, filler_val)
        # Tolerant balance check
        if !MOLE_ApproxEq_DDEF(ratios[idx_fill[1]] + other_sum, 100.0; atol=1e-4)
            @printf(io, "![WARN] Balance drift: sum=%.8f (expected 100.0)\n",
                ratios[idx_fill[1]] + other_sum)
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
# SECTION 4: STOICHIOMETRY ENGINE (CORE CALCULATIONS)
# --------------------------------------------------------------------------------------

"""
    MOLE_CalcMass_DDEF(Names, MWs, Ratios, Vol, Conc, [Scale]) -> DataFrame
The primary analytical engine for calculating mass from molar concentrations.
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

end # module
