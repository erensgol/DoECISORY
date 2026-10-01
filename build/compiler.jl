# ==============================================================================
# DoECISORY Sysimage Compiler
# ==============================================================================
# Usage:  julia --threads auto --project=. build/compiler.jl
# Output: build/sysimage.dll (Windows) / .so (Linux)
# ==============================================================================

using Pkg
using TOML

println("\n" * "="^60)
println("  DoECISORY Sysimage Compiler")
println("="^60 * "\n")

# --- 1. Setup ---------------------------------------------------------------

println("[BUILD] Checking PackageCompiler availability in Julia depot...")
try
    @eval using PackageCompiler
    println("[BUILD] PackageCompiler is available.")
catch
    println("\n" * "!"^60)
    println("  [NOTICE] PackageCompiler is not installed.")
    println("  To preserve DoECISORY's lightweight package dependencies,")
    println("  PackageCompiler is not bundled in Project.toml.")
    println("  Please install it once in your global environment:")
    println("    julia -e \"using Pkg; Pkg.add(\\\"PackageCompiler\\\")\"")
    println("!"^60 * "\n")
    error("[BUILD] PackageCompiler not found. Please install it globally and re-run.")
end

project_dir   = abspath(joinpath(@__DIR__, ".."))
sysimg_ext    = Sys.iswindows() ? "dll" : "so"
sysimg_name   = "sysimage.$sysimg_ext"
sysimg_path   = joinpath(@__DIR__, sysimg_name)
stmts_path    = joinpath(@__DIR__, "precompile_statements.txt")
workload_file = joinpath(@__DIR__, "workload.jl")
proj_toml     = joinpath(project_dir, "Project.toml")

# Pre-run check: Recover from any interrupted prior build
proj_backup = joinpath(@__DIR__, "Project.toml.bak")
mani_backup = joinpath(@__DIR__, "Manifest.toml.bak")
if isfile(proj_backup) || isfile(mani_backup)
    println("[BUILD] Pre-run check: Cleaning obsolete backup files...")
    rm(proj_backup; force=true)
    rm(mani_backup; force=true)
end

println("[BUILD] Target: $sysimg_path")

# --- 2. Ensure project is fully resolved ------------------------------------

println("[BUILD] Activating project environment: $project_dir")
Pkg.activate(project_dir)

println("[BUILD] Resolving and instantiating project dependencies...")
Pkg.resolve()
Pkg.instantiate()
println("[BUILD] Project dependencies resolved.")

# --- 3. Build Workflow ------------------------------------------------------

try
    # Phase 1: Trace workload to capture precompile statements
    println("[BUILD] Phase 1: Tracing workload to capture precompile statements...")
    t_trace = time()
    trace_cmd = Cmd(`$(Base.julia_cmd()) --project=$project_dir
        --trace-compile=$stmts_path
        --startup-file=no
        -O0
        $workload_file`; dir=project_dir)
    try
        run(trace_cmd)
        n = countlines(stmts_path)
        println("[BUILD] Phase 1 complete — $n statements ($(round(time()-t_trace; digits=1))s)")
    catch e
        if isfile(stmts_path) && filesize(stmts_path) > 0
            n = countlines(stmts_path)
            println("[BUILD] Phase 1 partial — $n statements ($(round(time()-t_trace; digits=1))s)")
        else
            error("[BUILD] Phase 1 failed — no statements captured: $e")
        end
    end

    # Phase 2: Filter precompile statements
    # Exclude non-sysimage modules (PlotlyJS/Kaleido/WebIO) and dynamic/local Main scopes
    if isfile(stmts_path)
        println("[BUILD] Phase 2: Filtering precompile statements (excluding non-sysimage modules)...")
        raw_lines = readlines(stmts_path)
        excluded_patterns = [
            "Plotly", "Kaleido", "JSExpr", "WebIO", "Blink", "Hiccup", "Mustache",
            "AssetRegistry", "Colors", "ColorTypes", "ColorVectorSpace", "ColorSchemes",
            "FixedPointNumbers", "Main.", "DoECISORY."
        ]
        filtered_lines = filter(raw_lines) do line
            !any(pat -> occursin(pat, line), excluded_patterns)
        end
        open(stmts_path, "w") do io
            for line in filtered_lines
                println(io, line)
            end
        end
        println("[BUILD] Statements filtered: $(length(raw_lines)) -> $(length(filtered_lines)) clean statements.")
    end

    # Phase 3: Dynamic package discovery (excluding PackageCompiler and PlotlyJS)
    proj_data = TOML.parsefile(proj_toml)
    dep_names = collect(keys(get(proj_data, "deps", Dict())))
    filter!(n -> !(n in ["PackageCompiler", "PlotlyJS"]), dep_names)
    packages  = Symbol.(sort(dep_names))

    println("[BUILD] Phase 3: Building sysimage ($(length(packages)) packages):")
    println("        $(join(string.(packages), ", "))\n")
    t0 = time()

    create_sysimage(
        packages;
        sysimage_path              = sysimg_path,
        project                    = project_dir,
        precompile_statements_file = stmts_path,
        cpu_target                 = PackageCompiler.default_app_cpu_target(),
        incremental                = true,
    )

    elapsed     = round(time() - t0; digits=1)
    filesize_mb = round(filesize(sysimg_path) / 1024^2; digits=1)

    println("\n" * "="^60)
    println("  SYSIMAGE BUILD COMPLETE")
    println("="^60)
    println("  File:  $sysimg_name")
    println("  Size:  $(filesize_mb) MB")
    println("  Time:  $(elapsed)s")
    println("  Path:  $sysimg_path")
    println()
    println("  Launch: julia --sysimage build/$sysimg_name --threads auto --project=. app.jl")
    println("  Or double-click Run_DoE.bat (auto-detects sysimage).")
    println("="^60 * "\n")

finally
    # Clean up temporary precompile statements
    if isfile(stmts_path)
        rm(stmts_path; force=true)
    end
end
