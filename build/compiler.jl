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

println("[BUILD] Checking PackageCompiler availability...")
try
    @eval using PackageCompiler
    println("[BUILD] PackageCompiler found.")
catch
    println("[BUILD] Installing PackageCompiler...")
    Pkg.add("PackageCompiler")
    @eval using PackageCompiler
end

project_dir   = abspath(joinpath(@__DIR__, ".."))
sysimg_ext    = Sys.iswindows() ? "dll" : "so"
sysimg_name   = "sysimage.$sysimg_ext"
sysimg_path   = joinpath(@__DIR__, sysimg_name)
stmts_path    = joinpath(@__DIR__, "precompile_statements.txt")
workload_file = joinpath(@__DIR__, "workload.jl")

proj_toml     = joinpath(project_dir, "Project.toml")
mani_toml     = joinpath(project_dir, "Manifest.toml")
proj_backup   = joinpath(@__DIR__, "Project.toml.bak")
mani_backup   = joinpath(@__DIR__, "Manifest.toml.bak")

# Pre-run check: Recover from any interrupted prior build
if isfile(proj_backup) || isfile(mani_backup)
    println("[BUILD] Pre-run check: Detected backup files from an interrupted previous build.")
    current_proj_text = isfile(proj_toml) ? read(proj_toml, String) : ""
    if !occursin("PlotlyJS", current_proj_text) && isfile(proj_backup)
        println("[BUILD] Recovering Project.toml and Manifest.toml from backup...")
        cp(proj_backup, proj_toml; force=true)
        isfile(mani_backup) && cp(mani_backup, mani_toml; force=true)
        println("[BUILD] Clean project state recovered.")
    end
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

# --- 3. Backup Project State ------------------------------------------------

println("[BUILD] Backing up Project.toml and Manifest.toml...")
cp(proj_toml, proj_backup; force=true)
cp(mani_toml, mani_backup; force=true)
println("[BUILD] Backups created.")

# --- 4. Build -------------------------------------

try
    # Phase 1: Trace workload (PlotlyJS must be present for Sys_Flow.jl)
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

    # Phase 2: Remove PlotlyJS (Colors/FixedPointNumbers precompile conflict)
    println("[BUILD] Phase 2: Removing PlotlyJS temporarily...")
    try
        Pkg.rm("PlotlyJS"; mode=Pkg.PKGMODE_PROJECT)
    catch
    end
    # Re-resolve after removal so Manifest is consistent
    Pkg.resolve()
    Pkg.instantiate()
    println("[BUILD] PlotlyJS removed. Manifest re-resolved.")

    # Phase 3: Filter precompile statements to eliminate removed or undeclared modules
    if isfile(stmts_path)
        println("[BUILD] Filtering precompile statements (removing PlotlyJS and local Main references)...")
        raw_lines = readlines(stmts_path)
        filtered_lines = filter(raw_lines) do line
            !occursin("Plotly", line) && !occursin("Kaleido", line) && !occursin("JSExpr", line) && !occursin("Main.", line)
        end
        open(stmts_path, "w") do io
            for line in filtered_lines
                println(io, line)
            end
        end
        println("[BUILD] Statements filtered: $(length(raw_lines)) -> $(length(filtered_lines)) clean statements.")
    end

    # Phase 4: Read remaining packages from Project.toml dynamically
    proj_data = TOML.parsefile(proj_toml)
    dep_names = collect(keys(get(proj_data, "deps", Dict())))
    filter!(n -> n != "PackageCompiler", dep_names)
    packages  = Symbol.(sort(dep_names))

    println("[BUILD] Phase 4: Building sysimage ($(length(packages)) packages)...\n")
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
    # ALWAYS restore Project.toml and Manifest.toml
    println("\n[BUILD] Restoring Project.toml and Manifest.toml from backup...")
    isfile(proj_backup) && cp(proj_backup, proj_toml; force=true)
    isfile(mani_backup) && cp(mani_backup, mani_toml; force=true)
    isfile(proj_backup) && rm(proj_backup;  force=true)
    isfile(mani_backup) && rm(mani_backup;  force=true)
    isfile(stmts_path)  && rm(stmts_path;   force=true)
    println("[BUILD] Project state restored. Re-instantiating full dependencies...")
    try
        Pkg.resolve()
        Pkg.instantiate()
        println("[BUILD] Dependency restoration complete.")
    catch e
        println("[BUILD] Warning: Failed to instantiate full dependencies: $e")
    end
end
