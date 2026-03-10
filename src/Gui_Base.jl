module Gui_Base

# ======================================================================================
# DAISHODOE - GUI BASE (SHARED COMPONENTS)
# ======================================================================================
# Purpose: Reusable Dash-Bootstrap components and high-fidelity styling tokens.
# Module Tag: BASE
# ======================================================================================

using Dash
using DashBootstrapComponents
using Main.Sys_Fast

export BASE_StyleCell_DDEC, BASE_StyleInput_DDEC, BASE_StyleInputCentre_DDEC
export BASE_StyleHeader_DDEC, BASE_StyleDatatableCell_DDEC, BASE_StyleInlineHeader_DDEC, BASE_StyleHr_DDEC, BASE_EmptyFigure_DDEC
export BASE_SafeRows_DDEF, BASE_GetTrigger_DDEF
export BASE_PageHeader_DDEF, BASE_GlassPanel_DDEF, BASE_DataTable_DDEF, BASE_Modal_DDEF
export BASE_ConvertThemePlotlyWhite!_DDEF, BASE_MiniVitals_DDEF, BASE_Loading_DDEF
export BASE_StatusIcon_DDEF, BASE_IconButton_DDEF, BASE_TableHeader_DDEF, BASE_ControlGroup_DDEF, BASE_ActionButton_DDEF
export BASE_Separator_DDEF, BASE_SidebarHeader_DDEF, BASE_Upload_DDEF, BASE_NextButton_DDEF
export BASE_BuildIdRow_DDEF, BASE_BuildLevelRow_DDEF, BASE_BuildLimitsRow_DDEF, BASE_BuildGoalRow_DDEF

# --------------------------------------------------------------------------------------
# --- SHARED STYLE CONSTANTS ---
# --------------------------------------------------------------------------------------

const BASE_StyleCell_DDEC = Dict(
    "backgroundColor" => "var(--colour-val0-purwhi)",
    "border" => "1px solid var(--colour-val1-lighig)",
    "verticalAlign" => "middle",
    "padding" => "0px",
)

const BASE_StyleInput_DDEC = Dict(
    "backgroundColor" => "transparent",
    "border" => "none",
    "color" => "var(--colour-val5-purbla)",
    "fontSize" => "10px",
    "width" => "100%",
    "outline" => "none",
    "fontFamily" => "var(--font-sans)",
)

const BASE_StyleInputCentre_DDEC = merge(BASE_StyleInput_DDEC, Dict("textAlign" => "center"))

const BASE_StyleHeader_DDEC = Dict(
    "backgroundColor" => "var(--colour-val0-purwhi)", "color" => "var(--colour-val4-darhig)",
    "borderBottom" => "2px solid var(--colour-val1-lighig)",
    "fontSize" => "0.70rem", "padding" => "6px 5px",
    "fontWeight" => "600",
)

const BASE_StyleDatatableCell_DDEC = Dict(
    "backgroundColor" => "var(--colour-val0-purwhi)", "color" => "var(--colour-val5-purbla)",
    "border" => "none",
    "borderBottom" => "none",
    "fontFamily" => "var(--font-sans)", "fontSize" => "10px", "padding" => "6px 5px",
)

const BASE_StyleInlineHeader_DDEC = Dict(
    "backgroundColor" => "var(--colour-val0-purwhi)",
    "color" => "var(--colour-val4-darhig)",
    "fontWeight" => "600",
    "fontSize" => "0.65rem",
    "letterSpacing" => "0.05em",
    "border" => "none",
    "borderBottom" => "none",
)

const BASE_StyleHr_DDEC = Dict("borderColor" => "var(--colour-val1-lighig)", "margin" => "6px 0")

const BASE_EmptyFigure_DDEC = Dict(
    "data" => [],
    "layout" => Dict(
        "paper_bgcolor" => "var(--colour-val0-purwhi)",
        "plot_bgcolor" => "var(--colour-val2-liglow)",
        "xaxis" => Dict("visible" => false, "showgrid" => false, "zeroline" => false),
        "yaxis" => Dict("visible" => false, "showgrid" => false, "zeroline" => false),
        "margin" => Dict("l" => 0, "r" => 0, "t" => 0, "b" => 0),
        "annotations" => [Dict(
            "text" => "<b>No Visualisation Data</b><br><span style='font-size:12px'>Run analysis to generate plots</span>",
            "showarrow" => false,
            "xref" => "paper", "yref" => "paper", "x" => 0.5, "y" => 0.5,
            "font" => Dict("color" => "var(--colour-val4-darhig)", "size" => 16, "family" => "var(--font-sans)"),
        )],
    ),
)

# --------------------------------------------------------------------------------------
# --- UI WIDGET BUILDERS ---
# --------------------------------------------------------------------------------------

"""
    BASE_PageHeader_DDEF(title, subtitle)
Standardised page header layout with title and secondary description.
"""
function BASE_PageHeader_DDEF(title::String, subtitle::String)
    return dbc_row(dbc_col([
                html_h3(title, className="mb-1"),
                html_p([
                        subtitle,
                        html_br(),
                        html_span([html_i(className="fas fa-exclamation-triangle me-1"), " Stateless architecture: Refreshing the browser will clear all inputted parameters and unsaved analyses."],
                            className="text-secondary small fst-italic", style=Dict("fontSize" => "0.75rem"))
                    ], className="text-secondary small"),
            ], xs=12), className="mb-3")
end

"""
    BASE_GlassPanel_DDEF(title, content; [right_node], [panel_class], [content_class], [overflow])
Standardised 'glass-panel' component wrapper for UI sections.
"""
function BASE_GlassPanel_DDEF(title::Union{String,Vector{Any}}, content; right_node=nothing, panel_class="h-100", content_class="glass-content p-2 p-md-3", overflow="hidden")
    header_content = Any[html_span(title, className="glass-caption")]
    !isnothing(right_node) && push!(header_content, right_node)

    return html_div([
            html_div(header_content, className="glass-header d-flex justify-content-between align-items-center mb-2"),
            html_div(content, className=content_class)
        ], className="glass-panel $panel_class", style=Dict("overflow" => overflow))
end

"""
    BASE_DataTable_DDEF(id, columns, data; kwargs...)
Dash DataTable wrapper enforcing DaishoDoE CSS consistency and responsiveness.
"""
function BASE_DataTable_DDEF(id::String, columns::Vector, data; kwargs...)
    return dash_datatable(;
        id=id, columns=columns, data=data,
        style_table=Dict("overflowX" => "auto", "overflowY" => "visible", "borderCollapse" => "collapse", "width" => "100%"),
        style_header=BASE_StyleHeader_DDEC,
        style_cell=BASE_StyleDatatableCell_DDEC,
        css=[
            Dict("selector" => ".dash-spreadsheet-container .dash-spreadsheet-inner th", "rule" => "padding: 0.25rem; font-size: 0.70rem; letter-spacing: 0.05em;"),
            Dict("selector" => ".dash-spreadsheet-container .dash-spreadsheet-inner td", "rule" => "padding: 0.25rem; font-size: 10px;")
        ],
        kwargs...
    )
end

"""
    BASE_Modal_DDEF(id, title, body, footer; [size], [is_open], [centred], [close_button])
Standardised modal constructor for popup dialogs.
"""
function BASE_Modal_DDEF(id::String, title, body, footer; size="lg", is_open=false, centred=true, close_button=true)
    return dbc_modal([
            dbc_modalheader(dbc_modaltitle(title); close_button=close_button),
            dbc_modalbody(body),
            dbc_modalfooter(footer)
        ]; id=id, is_open=is_open, size=size, centered=centred)
end

# --------------------------------------------------------------------------------------
# --- SHARED HELPER FUNCTIONS ---
# --------------------------------------------------------------------------------------

"""
    BASE_SafeRows_DDEF(d) -> Vector{Dict{String,Any}}
Safely converts raw callback table data to string-keyed dictionary vectors.
"""
BASE_SafeRows_DDEF(d) = isnothing(d) ? Dict{String,Any}[] :
                        [Dict{String,Any}(string(k) => v for (k, v) in r) for r in d]

"""
    BASE_GetTrigger_DDEF(ctx) -> String
Identifies the component ID that triggered the current Dash callback.
"""
function BASE_GetTrigger_DDEF(ctx)
    isempty(ctx.triggered) && return ""
    return ctx.triggered[1].prop_id |> x -> split(x, ".")[1]
end

"""
    BASE_ConvertThemePlotlyWhite!_DDEF(fig_dict)
Mutates a PlotlyJS figure object into a standardised white theme for academic reports.
"""
function BASE_ConvertThemePlotlyWhite!_DDEF(fig_dict)
    if haskey(fig_dict, "layout")
        C = Sys_Fast.FAST_Data_DDEC
        lay = fig_dict["layout"]
        lay["template"] = "plotly_white"
        lay["paper_bgcolor"] = C.COLOUR_PURWHI
        lay["plot_bgcolor"] = C.COLOUR_PURWHI
        lay["font"] = Dict("color" => C.COLOUR_PURBLA, "family" => "Arial", "size" => 16)

        if haskey(lay, "scene")
            lay["scene"]["bgcolor"] = C.COLOUR_PURWHI
            for ax in ("xaxis", "yaxis", "zaxis")
                if haskey(lay["scene"], ax)
                    lay["scene"][ax]["color"] = C.COLOUR_PURBLA
                    lay["scene"][ax]["gridcolor"] = C.COLOUR_LIGHIG
                    lay["scene"][ax]["zerolinecolor"] = C.COLOUR_LIGHIG
                    lay["scene"][ax]["backgroundcolor"] = C.COLOUR_PURWHI
                end
            end
        end

        for ax in ("xaxis", "yaxis")
            if haskey(lay, ax)
                lay[ax]["color"] = C.COLOUR_PURBLA
                lay[ax]["gridcolor"] = C.COLOUR_LIGHIG
                lay[ax]["zerolinecolor"] = C.COLOUR_LIGHIG
            end
        end
    end
    return fig_dict
end

"""
    BASE_MiniVitals_DDEF(label, value, color) -> dbc_card
Compact metric display unit for scientific dashboards.
"""
function BASE_MiniVitals_DDEF(label::String, value::String, color::String="info")
    return dbc_card([
            html_div(label, className="small text-muted text-uppercase fw-bold", style=Dict("fontSize" => "0.6rem", "letterSpacing" => "0.5px")),
            html_div(value, className="h6 mb-0 fw-bold text-$color")
        ], body=true, className="p-2 border-0 shadow-sm bg-white text-center")
end

"""
    BASE_Loading_DDEF(id, content; [color]) -> dcc_loading
Standardised loading spinner with consistent theme colors.
"""
function BASE_Loading_DDEF(id::String, content; color::String="var(--colour-chr3-toncya)", class="mt-2 small")
    return dbc_row(dbc_col(dcc_loading(html_div(content, id=id, className=class), type="default", color=color), xs=12))
end

"""
    BASE_StatusIcon_DDEF(symbol, id; [color], [size], [tip]) -> html_span
Small status indicator used for matrix properties (radioactivity, filler, etc).
"""
function BASE_StatusIcon_DDEF(symbol::String, id::String; color::String="var(--colour-val4-darhig)", size::String="0.45rem", tip=nothing)
    icon = html_span(symbol, id=id, style=Dict("color" => color, "fontSize" => size, "marginRight" => "1px"))
    isnothing(tip) && return icon
    return dbc_tooltip(tip, target=id, placement="top")
end

"""
    BASE_IconButton_DDEF(id, icon_class; [color], [size], [tip]) -> html_button
Compact button containing only a FontAwesome icon, primarily for grid property cogs.
"""
function BASE_IconButton_DDEF(id::String, icon_class::String; color="var(--colour-val3-darlow)", size="0.80rem", tip=nothing)
    btn = html_button(html_i(className=icon_class, style=Dict("fontSize" => size, "color" => color)),
        id=id, n_clicks=0,
        style=Dict("cursor" => "pointer", "background" => "none", "border" => "none", "padding" => "2px"))
    isnothing(tip) && return btn
    return html_span([btn, dbc_tooltip(tip, target=id)])
end

"""
    BASE_TableHeader_DDEF(label; [width], [textAlign]) -> html_th
Standardised table header cell with consistent typography and padding.
"""
function BASE_TableHeader_DDEF(label::String; width="auto", textAlign="center", padding="2px", kwargs...)
    base_style = merge(BASE_StyleInlineHeader_DDEC, Dict("textAlign" => textAlign, "padding" => padding, "width" => width))
    # Safety: pull style out of kwargs if it exists to avoid multiple kwarg error
    args_dict = Dict(kwargs)
    final_style = haskey(args_dict, :style) ? merge(base_style, args_dict[:style]) : (haskey(args_dict, "style") ? merge(base_style, args_dict["style"]) : base_style)
    # Remove style from args_dict to pass it explicitly
    delete!(args_dict, :style)
    delete!(args_dict, "style")
    return html_th(label; style=final_style, className="p-0", args_dict...)
end

"""
    BASE_ControlGroup_DDEF(label, input; [help]) -> dbc_row
Standardised sidebar control unit: label + input pair.
"""
function BASE_ControlGroup_DDEF(label::String, input; class="mb-3")
    return dbc_row(dbc_col([
                dbc_label(label, className="small mb-1"),
                input
            ], xs=12), className=class)
end

"""
    BASE_ActionButton_DDEF(id, label, icon; [color], [outline], [size], [class]) -> dbc_button
Standardised sidebar action button.
"""
function BASE_ActionButton_DDEF(id::String, label::String, icon::String; color="secondary", outline=true, size="sm", class="w-100 mb-2 fw-bold", kwargs...)
    return dbc_button([html_i(className="$icon me-2"), label], id=id, n_clicks=0, color=color, outline=outline, size=size, className=class; kwargs...)
end

"""
    BASE_NextButton_DDEF(id, label; [icon]) -> dbc_button
Standardised primary action button for phase transitions or execution.
"""
function BASE_NextButton_DDEF(id::String, label::String; icon::String="fas fa-play", class="w-100 fw-bold mb-2", kwargs...)
    return dbc_row(dbc_col(dbc_button([html_i(className="$icon me-2"), label], id=id, n_clicks=0, color="primary", size="sm", className=class; kwargs...), xs=12))
end

"""
    BASE_Separator_DDEF(; [class]) -> dbc_row
Standardised horizontal rule for dividing sidebar sections.
"""
function BASE_Separator_DDEF(; class="my-2")
    return dbc_row(dbc_col(html_hr(style=BASE_StyleHr_DDEC, className=class), xs=12))
end

"""
    BASE_SidebarHeader_DDEF(label; [icon]) -> dbc_row
Standardised section header for sidebars.
"""
function BASE_SidebarHeader_DDEF(label::String; icon=nothing, class="small mb-1 fw-bold text-center")
    children = Any[]
    if !isnothing(icon)
        push!(children, html_i(className="$icon me-2"))
    end
    push!(children, label)
    return dbc_row(dbc_col(html_div(children, className=class), xs=12))
end

"""
    BASE_Upload_DDEF(id, label, icon; [multiple]) -> dbc_row
Standardised upload component for dataset ingestion.
"""
function BASE_Upload_DDEF(id::String, label::String, icon::String; multiple=false)
    return dbc_row(dbc_col(dcc_upload(id=id, children=BASE_ActionButton_DDEF(id * "-btn", label, icon), multiple=multiple), xs=12))
end

# --------------------------------------------------------------------------------------
# --- RESTRUCTURING: MOVED UI BUILDERS ---
# --------------------------------------------------------------------------------------

"""
    BASE_BuildIdRow_DDEF(i, row, visible, [show_del]) -> html_tr
Table-based ID row including delete button (optional), name input, and property icons.
(Moved from Gui_Deck.jl)
"""
function BASE_BuildIdRow_DDEF(i, row, visible, show_del=false)
    row_style = Dict("display" => visible ? "table-row" : "none")
    name_val = string(get(row, "Name", ""))
    is_filler = get(row, "IsFiller", false)

    name_input_style = Dict{String,Any}()
    is_filler && (name_input_style["borderLeft"] = "3px solid var(--colour-chr5-hueyel)")

    # Ensure delete button ID always exists in layout for callback stability
    del_btn = html_button("×", id="deck-del-$i", n_clicks=0,
        style=Dict("display" => show_del ? "block" : "none",
            "cursor" => "pointer", "color" => "var(--colour-val4-darhig)", "fontSize" => "1.1rem", "fontWeight" => "700",
            "lineHeight" => "1", "background" => "none", "border" => "none", "padding" => "0"))

    # Automatic radioactive flag for UI (syncs with data logic)
    hl_v = Float64(get(row, "HalfLife", 0.0))
    is_radio = (get(row, "IsRadioactive", false) == true) || (hl_v > 0.0)

    mw_v = Float64(get(row, "MW", 0.0))
    dot1_colour = mw_v > 0.0 ? "var(--colour-chr4-tongre)" : "var(--colour-val4-darhig)"
    dot2_colour = hl_v > 0.0 ? "var(--colour-chr4-tongre)" : "var(--colour-val4-darhig)"

    dots = html_span([
            is_radio ? html_i(className="fas fa-radiation text-danger me-1", style=Dict("fontSize" => "0.7rem")) : nothing,
            is_filler ? html_i(className="fas fa-fill-drip text-warning me-1", style=Dict("fontSize" => "0.7rem")) : nothing,
            BASE_StatusIcon_DDEF("●", "deck-dot1-$i", color=mw_v > 0.0 ? "var(--colour-chr4-tongre)" : "var(--colour-val4-darhig)"),
            BASE_StatusIcon_DDEF("●", "deck-dot2-$i", color=hl_v > 0.0 ? "var(--colour-chr4-tongre)" : "var(--colour-val4-darhig)"),
        ], style=Dict("display" => "inline-flex", "alignItems" => "center"))

    prop_btn = BASE_IconButton_DDEF("btn-prop-$i", "fas fa-cog", color=is_filler ? "var(--colour-chr5-hueyel)" : "var(--colour-val3-darlow)")

    row_children = Any[]
    # Always include TD for alignment & callback ID stability
    push!(row_children, html_td(del_btn,
        style=merge(BASE_StyleCell_DDEC, Dict("textAlign" => "center", "width" => "30px", "display" => show_del ? "table-cell" : "none")),
        className="p-0"))

    # Name cell
    push!(row_children, html_td(
        dcc_input(id="deck-name-$i", type="text", value=name_val, debounce=true, style=name_input_style),
        className="deck-name-cell p-0", style=BASE_StyleCell_DDEC)
    )

    push!(row_children, html_td(
        html_span([dots, prop_btn], style=Dict("display" => "inline-flex", "alignItems" => "center", "justifyContent" => "center")),
        style=merge(BASE_StyleCell_DDEC, Dict("textAlign" => "center", "width" => "55px")), className="p-0")
    )

    return html_tr(row_children; style=row_style, id="deck-row-id-$i")
end

"""
    BASE_BuildLevelRow_DDEF(i, row, visible) -> html_tr
Renders the 3-column levels portion of the row (Lower, Centre, Upper).
(Moved from Gui_Deck.jl)
"""
function BASE_BuildLevelRow_DDEF(i, row, visible)
    row_style = Dict("display" => visible ? "table-row" : "none")
    l1_val = get(row, "L1", 0.0)
    l2_val = get(row, "L2", 0.0)
    l3_val = get(row, "L3", 0.0)

    # Determine visibility of L1, L2, L3 based on row index
    show_l1 = (i <= 3) # Visible only for Variables
    show_l2 = (i <= 3 || i >= 5) # Visible for Variables and Constants
    show_l3 = (i <= 3) # Visible only for Variables

    html_tr([
            html_td(dcc_input(id="deck-l1-$i", type="number", value=l1_val, debounce=true, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px", "display" => show_l1 ? "block" : "none")), className="px-0 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("textAlign" => "center", "width" => "33%")), className="p-0"),
            html_td(dcc_input(id="deck-l2-$i", type="number", value=l2_val, debounce=true, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px", "display" => show_l2 ? "block" : "none")), className="px-0 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("textAlign" => "center", "width" => "33%")), className="p-0"),
            html_td(dcc_input(id="deck-l3-$i", type="number", value=l3_val, debounce=true, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px", "display" => show_l3 ? "block" : "none")), className="px-0 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("textAlign" => "center", "width" => "34%")), className="p-0")
        ]; style=row_style, id="deck-row-level-$i")
end

"""
    BASE_BuildLimitsRow_DDEF(i, row, visible) -> html_tr
Renders the 3-column limits portion of the row (Min Limit, Unit, Max Limit).
(Moved from Gui_Deck.jl)
"""
function BASE_BuildLimitsRow_DDEF(i, row, visible)
    row_style = Dict("display" => visible ? "table-row" : "none")
    min_val = get(row, "Min", 0.0)
    max_val = get(row, "Max", 0.0)
    unit_val = string(get(row, "Unit", "-"))

    show_minmax = (i <= 3)

    html_tr([
            html_td(dcc_input(id="deck-min-$i", type="number", value=min_val, debounce=true, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px", "display" => show_minmax ? "block" : "none")), className="px-0 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("textAlign" => "center", "width" => "33%")), className="p-0"),
            html_td(dcc_input(id="deck-unit-$i", type="text", value=unit_val, debounce=true, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("textAlign" => "center", "width" => "34%")), className="p-0"),
            html_td(dcc_input(id="deck-max-$i", type="number", value=max_val, debounce=true, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px", "display" => show_minmax ? "block" : "none")), className="px-0 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("textAlign" => "center", "width" => "33%")), className="p-0")
        ]; style=row_style, id="deck-row-limits-$i")
end

"""
    BASE_BuildGoalRow_DDEF(i)
Constructs a single goal-specification row for the optimisation objectives table.
(Moved from Gui_Lens.jl)
"""
function BASE_BuildGoalRow_DDEF(i)
    return html_tr([
        html_td(dcc_input(id="lens-goal-name-$i", type="text", value="", style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px")), className="px-1 py-0", disabled=true), style=merge(BASE_StyleCell_DDEC, Dict("width" => "20%", "backgroundColor" => "var(--colour-val0-purwhi)", "borderBottom" => "none")), className="p-0"),
        html_td(dcc_input(id="lens-goal-min-$i", type="number", value=nothing, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("width" => "15%", "borderBottom" => "none")), className="p-0"),
        html_td(dcc_input(id="lens-goal-target-$i", type="number", value=nothing, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("width" => "15%", "borderBottom" => "none")), className="p-0"),
        html_td(dcc_input(id="lens-goal-max-$i", type="number", value=nothing, style=merge(BASE_StyleInputCentre_DDEC, Dict("fontSize" => "10px")), className="px-1 py-0"), style=merge(BASE_StyleCell_DDEC, Dict("width" => "15%", "borderBottom" => "none")), className="p-0"),
        html_td(dbc_select(id="lens-goal-type-$i", options=[
                    Dict("label" => "Nominal", "value" => "Nominal"),
                    Dict("label" => "Maximise", "value" => "Maximise"),
                    Dict("label" => "Minimise", "value" => "Minimise"),
                ], value="Nominal", className="form-select form-select-sm border-0 py-0", style=Dict("width" => "100%", "fontSize" => "10px", "backgroundColor" => "transparent", "color" => "var(--colour-val5-purbla)", "boxShadow" => "none")), style=merge(BASE_StyleCell_DDEC, Dict("width" => "20%")), className="p-1"),
        html_td(dbc_select(id="lens-goal-weight-$i", options=[
                    Dict("label" => "★☆☆☆☆", "value" => "0.25"),
                    Dict("label" => "★★☆☆☆", "value" => "0.50"),
                    Dict("label" => "★★★☆☆", "value" => "1.00"),
                    Dict("label" => "★★★★☆", "value" => "2.50"),
                    Dict("label" => "★★★★★", "value" => "5.00"),
                ], value="1.00", className="form-select form-select-sm border-0 py-0 text-center", style=Dict("width" => "100%", "fontSize" => "12px", "backgroundColor" => "transparent", "color" => "var(--colour-val4-darhig)", "boxShadow" => "none")), style=merge(BASE_StyleCell_DDEC, Dict("width" => "15%", "borderBottom" => "none")), className="p-1")
    ])
end

end # module Gui_Base
