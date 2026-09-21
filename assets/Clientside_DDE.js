/**
 * DoECISORY - Clientside Acceleration Bridge
 * Extends Dash functionality with high-speed JS callbacks for instant graph navigation.
 * Architecture: Graphs live server-side in a Ref. Only metadata (count + timestamp)
 * travels through dcc_store. render_graph is server-side (single figure per request).
 */

window.dash_clientside = Object.assign({}, window.dash_clientside, {
    clientside: {

        update_index: function(meta, n_nxt, n_prv, val_inp, current_i) {
            const context = window.dash_clientside.callback_context;
            const trigger = context.triggered.length > 0 ? context.triggered[0].prop_id : "";
            const tot = (meta && meta.count) ? meta.count : 0;
            console.log("[DOECISORY] Graph Meta Count:", tot, "| Trigger:", trigger);

            if (trigger.includes('lens-store-graph-meta.data')) {
                if (tot === 0) return [0, 1, 1];
                let idx = (current_i === null || current_i === undefined) ? 0 : current_i;
                idx = Math.min(idx, tot - 1);
                return [idx, idx + 1, Math.max(1, tot)];
            }
            if (tot === 0) return [0, 1, 1];

            let idx = (current_i === null || current_i === undefined) ? 0 : current_i;

            if (trigger.includes('lens-btn-next.n_clicks')) {
                idx = (idx + 1) % tot;
            } else if (trigger.includes('lens-btn-prev.n_clicks')) {
                idx = (idx - 1 + tot) % tot;
            } else if (trigger.includes('lens-graph-input.value')) {
                if (val_inp === null || val_inp === undefined || isNaN(val_inp)) {
                     return window.dash_clientside.no_update;
                }
                if (val_inp >= 1 && val_inp <= tot) {
                    idx = val_inp - 1;
                } else {
                    idx = val_inp < 1 ? 0 : tot - 1;
                }
            }

            idx = Math.max(0, Math.min(idx, tot - 1));

            return [idx, idx + 1, Math.max(1, tot)];
        },

        render_graph: function(blob, idx) {
             if (!blob || blob === "") {
                 return [window.dash_clientside.no_update, "No Visualisation Data", "/ 0"];
             }
             
             try {
                 const graphs = JSON.parse(blob);
                 const count = graphs.length;
                 if (count === 0) return [window.dash_clientside.no_update, "No Visualisation Data", "/ 0"];
                 const safe_i = (idx === null || idx === undefined || isNaN(idx)) ? 0 : Math.max(0, Math.min(Number(idx), count - 1));
                 const item = graphs[safe_i] || graphs[0] || {};
                 const fig = item.figure || {};
                 
                 console.log("[DOECISORY] Rendering Plot:", item.title, "| Index:", safe_i);
                 
                 return [
                     {
                         data: fig.data || [],
                         layout: fig.layout || {}
                     },
                     item.title || "Untitled Plot",
                     "/ " + count
                 ];
             } catch (e) {
                 console.error("[DOECISORY] Blob Parsing Failed:", e);
                 return [{}, "Data Corruption Error", "/ 0"];
             }
        },

        update_info: function(blob) {
            if (!blob || blob === "") return "";
            
            try {
                const graphs = JSON.parse(blob);
                const counts = {};
                const order = [];
                
                graphs.forEach(item => {
                    const title = item.title || "Unknown";
                    const category = title.split(":")[0];
                    if (!counts[category]) {
                        order.push(category);
                        counts[category] = 0;
                    }
                    counts[category]++;
                });
                
                const info_parts = [];
                let curr_start = 1;
                order.forEach(cat => {
                    const c = counts[cat];
                    info_parts.push(cat + " (" + curr_start + "-" + (curr_start + c - 1) + ")");
                    curr_start += c;
                });
                
                const rows = [];
                for (let i = 0; i < info_parts.length; i += 3) {
                    const chunk = info_parts.slice(i, i + 3);
                    rows.push({
                        props: {
                            children: chunk.map(text => {
                                return {
                                    props: {
                                        children: text,
                                        className: "colourtx-v5pb",
                                        style: {
                                            width: "33.3%",
                                            textAlign: "center",
                                            padding: "6px 0",
                                            fontSize: "12.5px",
                                            fontWeight: "600",
                                            letterSpacing: "0.1px"
                                        }
                                    },
                                    type: "Span",
                                    namespace: "dash_html_components"
                                };
                            }),
                            style: {
                                display: "flex",
                                width: "100%",
                                justifyContent: "center",
                                alignItems: "center",
                                marginBottom: "2px"
                            }
                        },
                        type: "Div",
                        namespace: "dash_html_components"
                    });
                }
                
                return {
                    props: {
                        children: rows,
                        style: {
                            display: "flex",
                            flexDirection: "column",
                            width: "100%",
                            padding: "10px 0"
                        }
                    },
                    type: "Div",
                    namespace: "dash_html_components"
                };
            } catch (e) {
                console.error("[DOECISORY] Info Build Failed:", e);
                return "Error building index.";
            }
        }
    }
});
