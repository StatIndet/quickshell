.pragma library

function clone(value) { return JSON.parse(JSON.stringify(value)); }
function identity(output) { return [output.make || "Unknown",output.model || "Unknown",output.serial || "Unknown"].join(" "); }
function stableKey(output, all, collisions) {
    const full=identity(output);
    const serial=output.serial && output.serial !== "Unknown";
    const unique=all.filter(o=>identity(o)===full).length===1;
    return serial && unique && (collisions || []).indexOf(full)<0 ? "identity:"+full : "connector:"+output.name+":"+full;
}
function matches(identifier, output) {
    const key=identifier.toLowerCase();
    return key===output.name.toLowerCase() || key===identity(output).toLowerCase();
}
function transform(value) {
    return ({Normal:"normal",Flipped:"flipped",Flipped90:"flipped-90",Flipped180:"flipped-180",Flipped270:"flipped-270"})[value] || value || "normal";
}
function modeString(mode) { return mode.width+"x"+mode.height+"@"+(mode.refreshMilliHz/1000).toFixed(3); }
function canonical(value) {
    if (value === undefined) return "null";
    if (value === null || typeof value !== "object") return JSON.stringify(value);
    if (Array.isArray(value)) return "["+value.map(canonical).join(",")+"]";
    return "{"+Object.keys(value).sort().map(k=>JSON.stringify(k)+":"+canonical(value[k])).join(",")+"}";
}
function rows(live, committed, collisions) {
    const result=live.map(output=>{
        const config=committed.find(row=>matches(row.identifier,output));
        const settings=clone(config ? config.settings : {});
        const key=stableKey(output,live,collisions);
        const identifier=config ? config.identifier : key.indexOf("identity:")===0 ? identity(output) : output.name;
        if (settings.enabled===undefined) settings.enabled=output.enabled;
        if (settings.mode===undefined) settings.mode=output.currentMode || (output.modes.length ? modeString(output.modes.find(m=>m.preferred) || output.modes[0]) : null);
        if (settings.scale===undefined) settings.scale=output.scale || 1;
        if (settings.transform===undefined) settings.transform=transform(output.transform);
        if (settings.position===undefined) settings.position={x:output.enabled?output.logicalX:0,y:output.enabled?output.logicalY:0};
        if (settings.vrr===undefined) settings.vrr="off";
        return {key:key,identifier:identifier,name:output.name,label:output.model && output.model!=="Unknown" ? output.model+" · "+output.name : output.name,
            connected:true,live:output,identity:{name:output.name,make:output.make,model:output.model,serial:output.serial},
            editable:(!config || (config.managed && config.editable)) && committed.filter(r=>matches(r.identifier,output)).length<=1 && live.filter(o=>matches(identifier,o)).length===1,source:config?config.source:"",settings:settings};
    });
    committed.filter(row=>row.managed && !live.some(o=>matches(row.identifier,o))).forEach(row=>result.push({
        key:"saved:"+row.identifier,identifier:row.identifier,name:"",label:row.identifier,connected:false,editable:row.editable,
        source:row.source,settings:clone(row.settings),live:null,identity:null
    }));
    return result;
}
function size(row) {
    const s=row.settings, live=row.live;
    if (live && s.mode===live.currentMode && s.scale===live.scale && s.transform===transform(live.transform) && live.logicalWidth>0)
        return {width:live.logicalWidth,height:live.logicalHeight};
    const dimensions=String(s.mode || "0x0").split("@")[0].split("x").map(Number);
    const rotated=["90","270","flipped-90","flipped-270"].indexOf(s.transform)>=0;
    const scale=Math.round((s.scale||1)*120)/120;
    return {width:Math.ceil(dimensions[rotated?1:0]/scale),height:Math.ceil(dimensions[rotated?0:1]/scale)};
}
function validation(rows) {
    const active=rows.filter(r=>r.connected && r.settings.enabled!==false && !r.deleted);
    if (!active.length) return "last-output";
    for (let i=0;i<active.length;++i) {
        const a=active[i], as=size(a), ap=a.settings.position || {x:0,y:0};
        if (!as.width || !as.height) return "mode";
        for (let j=0;j<i;++j) {
            const b=active[j], bs=size(b), bp=b.settings.position || {x:0,y:0};
            if (ap.x<bp.x+bs.width && ap.x+as.width>bp.x && ap.y<bp.y+bs.height && ap.y+as.height>bp.y) return "overlap";
        }
    }
    return "";
}
function patches(rows) { return rows.filter(r=>r.editable).map(r=>({identifier:r.identifier,identity:r.identity,settings:r.settings,delete:!!r.deleted})); }
function combination(live, collisions) { return live.map(o=>stableKey(o,live,collisions)).sort().join("\n"); }

function changes(rows, baseline) {
    return patches(rows).filter(patch=>{
        const original=patches(baseline).find(p=>p.identifier===patch.identifier);
        return !original || canonical(original)!==canonical(patch);
    });
}
