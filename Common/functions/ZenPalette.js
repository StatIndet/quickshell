/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Adapted from Zen Browser, commit 412731f37e567223097101d9fae9f9d364708b6b.
 * See licenses/README.md for source mapping and modification details.
 * Alternatively, the contents of this file may be used under the terms
 * of the GNU General Public License Version 3 or (at your option) later.
 * This file is free software: you may copy, redistribute and/or modify it
 * under those terms as published by the Free Software Foundation.
 * This file is distributed WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see https://www.gnu.org/licenses/.
 */

var presets = [
    {
        "x": 0.631578947368421,
        "y": 0.631578947368421,
        "count": 1,
        "algorithm": "floating",
        "lightness": 90.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.6131578947368421,
        "y": 0.4131578947368421,
        "count": 1,
        "algorithm": "floating",
        "lightness": 80.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.6210526315789474,
        "y": 0.29210526315789476,
        "count": 1,
        "algorithm": "floating",
        "lightness": 80.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.6157894736842106,
        "y": 0.45526315789473687,
        "count": 1,
        "algorithm": "floating",
        "lightness": 70.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.5789473684210527,
        "y": 0.4921052631578948,
        "count": 1,
        "algorithm": "floating",
        "lightness": 70.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.5921052631578947,
        "y": 0.6236842105263158,
        "count": 1,
        "algorithm": "floating",
        "lightness": 60.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.3868421052631579,
        "y": 0.5131578947368421,
        "count": 1,
        "algorithm": "floating",
        "lightness": 60.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.2131578947368421,
        "y": 0.22105263157894736,
        "count": 1,
        "algorithm": "floating",
        "lightness": 50.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.631578947368421,
        "y": 0.631578947368421,
        "count": 3,
        "algorithm": "analogous",
        "lightness": 90.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.6131578947368421,
        "y": 0.4131578947368421,
        "count": 3,
        "algorithm": "analogous",
        "lightness": 85.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.6210526315789474,
        "y": 0.29210526315789476,
        "count": 3,
        "algorithm": "analogous",
        "lightness": 80.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.6157894736842106,
        "y": 0.45526315789473687,
        "count": 3,
        "algorithm": "analogous",
        "lightness": 70.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.5789473684210527,
        "y": 0.4921052631578948,
        "count": 3,
        "algorithm": "analogous",
        "lightness": 70.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.5921052631578947,
        "y": 0.6236842105263158,
        "count": 3,
        "algorithm": "analogous",
        "lightness": 60.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.3868421052631579,
        "y": 0.5131578947368421,
        "count": 3,
        "algorithm": "analogous",
        "lightness": 60.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.2131578947368421,
        "y": 0.22105263157894736,
        "count": 3,
        "algorithm": "analogous",
        "lightness": 55.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.45,
        "y": 0.18947368421052632,
        "count": 1,
        "algorithm": "floating",
        "lightness": 10.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.6973684210526315,
        "y": 0.20789473684210527,
        "count": 1,
        "algorithm": "floating",
        "lightness": 40.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.7921052631578948,
        "y": 0.4631578947368421,
        "count": 1,
        "algorithm": "floating",
        "lightness": 35.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.6236842105263158,
        "y": 0.5526315789473685,
        "count": 1,
        "algorithm": "floating",
        "lightness": 30.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.2394736842105263,
        "y": 0.6,
        "count": 1,
        "algorithm": "floating",
        "lightness": 30.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.1763157894736842,
        "y": 0.41842105263157897,
        "count": 1,
        "algorithm": "floating",
        "lightness": 25.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.8263157894736842,
        "y": 0.618421052631579,
        "count": 1,
        "algorithm": "floating",
        "lightness": 20.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.3105263157894737,
        "y": 0.5657894736842105,
        "count": 1,
        "algorithm": "floating",
        "lightness": 20.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.45,
        "y": 0.18947368421052632,
        "count": 3,
        "algorithm": "analogous",
        "lightness": 10.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.6973684210526315,
        "y": 0.20789473684210527,
        "count": 3,
        "algorithm": "analogous",
        "lightness": 40.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.7921052631578948,
        "y": 0.4631578947368421,
        "count": 3,
        "algorithm": "analogous",
        "lightness": 35.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.6236842105263158,
        "y": 0.5526315789473685,
        "count": 3,
        "algorithm": "analogous",
        "lightness": 30.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.2394736842105263,
        "y": 0.6,
        "count": 3,
        "algorithm": "analogous",
        "lightness": 30.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.1763157894736842,
        "y": 0.41842105263157897,
        "count": 3,
        "algorithm": "analogous",
        "lightness": 25.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.8263157894736842,
        "y": 0.618421052631579,
        "count": 3,
        "algorithm": "analogous",
        "lightness": 20.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.3105263157894737,
        "y": 0.5657894736842105,
        "count": 3,
        "algorithm": "analogous",
        "lightness": 20.0,
        "type": "explicit-lightness"
    },
    {
        "x": 0.8947368421052632,
        "y": 0.47368421052631576,
        "count": 1,
        "algorithm": "floating",
        "lightness": 50.0,
        "type": "explicit-black-white"
    },
    {
        "x": 0.8881578947368421,
        "y": 0.47368421052631576,
        "count": 1,
        "algorithm": "floating",
        "lightness": 50.0,
        "type": "explicit-black-white"
    },
    {
        "x": 0.8289473684210527,
        "y": 0.47368421052631576,
        "count": 1,
        "algorithm": "floating",
        "lightness": 50.0,
        "type": "explicit-black-white"
    },
    {
        "x": 0.7697368421052632,
        "y": 0.47368421052631576,
        "count": 1,
        "algorithm": "floating",
        "lightness": 50.0,
        "type": "explicit-black-white"
    },
    {
        "x": 0.7105263157894737,
        "y": 0.47368421052631576,
        "count": 1,
        "algorithm": "floating",
        "lightness": 50.0,
        "type": "explicit-black-white"
    },
    {
        "x": 0.6513157894736842,
        "y": 0.47368421052631576,
        "count": 1,
        "algorithm": "floating",
        "lightness": 50.0,
        "type": "explicit-black-white"
    },
    {
        "x": 0.5921052631578947,
        "y": 0.47368421052631576,
        "count": 1,
        "algorithm": "floating",
        "lightness": 50.0,
        "type": "explicit-black-white"
    },
    {
        "x": 0.5328947368421053,
        "y": 0.47368421052631576,
        "count": 1,
        "algorithm": "floating",
        "lightness": 50.0,
        "type": "explicit-black-white"
    },
    {
        "x": 0.47368421052631576,
        "y": 0.47368421052631576,
        "count": 1,
        "algorithm": "floating",
        "lightness": 50.0,
        "type": "explicit-black-white"
    }
];

var harmonies = {floating: [], complementary: [180], singleAnalogous: [310],
    splitComplementary: [150, 210], analogous: [50, 310], triadic: [120, 240]};
function algorithms(count) {
    return Object.keys(harmonies).filter(function(key) { return harmonies[key].length + 1 === count; });
}
function clamp(value, low, high) { return Math.max(low, Math.min(high, value)); }
function copy(state) { return JSON.parse(JSON.stringify(state)); }
function initial() {
    return {version: 1, count: 1, algorithm: "floating", x: 0.65, y: 0.44,
        lightness: 80, type: "explicit-lightness", opacity: 0.5, grain: 0};
}
function positions(state) {
    var dx = state.x - 0.5, dy = state.y - 0.5;
    var distance = Math.min(0.5, Math.sqrt(dx * dx + dy * dy));
    var angle = Math.atan2(dy, dx);
    var result = [{x: state.x, y: state.y}];
    harmonies[state.algorithm].forEach(function(offset) {
        var a = angle + offset * Math.PI / 180;
        result.push({x: 0.5 + distance * Math.cos(a), y: 0.5 + distance * Math.sin(a)});
    });
    return result;
}
function move(state, x, y, index) {
    var next = copy(state), dx = x - 0.5, dy = y - 0.5;
    var distance = Math.min(0.5, Math.sqrt(dx * dx + dy * dy));
    var angle = Math.atan2(dy, dx);
    if (index > 0) angle -= harmonies[state.algorithm][index - 1] * Math.PI / 180;
    next.x = 0.5 + distance * Math.cos(angle);
    next.y = 0.5 + distance * Math.sin(angle);
    return next;
}
function resize(state, count) {
    var next = copy(state);
    next.count = clamp(count, 1, 3);
    var choices = algorithms(next.count);
    next.algorithm = choices.indexOf(next.algorithm) >= 0 ? next.algorithm
        : next.count === 2 && state.algorithm === "analogous" ? "singleAnalogous" : choices[0];
    return next;
}
function remove(state, index) {
    if (state.count <= 1) return copy(state);
    var next = copy(state);
    if (index === 0) {
        var point = positions(state)[1];
        next.x = point.x; next.y = point.y;
    }
    return resize(next, state.count-1);
}
function preset(index, state) {
    var next = copy(state || initial()), data = presets[index];
    Object.keys(data).forEach(function(key) { next[key] = data[key]; });
    return next;
}
function hueToRgb(p, q, t) {
    t = (t + 1) % 1;
    if (t < 1/6) return p + (q-p)*6*t;
    if (t < 1/2) return q;
    if (t < 2/3) return p + (q-p)*(2/3-t)*6;
    return p;
}
function hslToRgb(h, s, l) {
    var q = l < 0.5 ? l*(1+s) : l+s-l*s, p = 2*l-q;
    return (s === 0 ? [l,l,l] : [hueToRgb(p,q,h+1/3),hueToRgb(p,q,h),hueToRgb(p,q,h-1/3)])
        .map(function(v) { return Math.round(clamp(v,0,1)*255); });
}
function colorAt(point, state) {
    // Canonical 380px Zen pad: +29px dot offset, 30px padding per side,
    // 205px color radius and the upstream 0.2px distance correction.
    // Persist normalized positions; live editor geometry never affects color.
    var dx = point.x*380-191, dy = point.y*380-191;
    var d = clamp((Math.sqrt(dx*dx+dy*dy)-0.2)/205, 0, 1);
    var hue = (Math.atan2(dy,dx)/(2*Math.PI)+1)%1;
    var saturation = 1-d, lightness = state.lightness/100;
    if (state.type !== "explicit-lightness") {
        saturation = 0.9+d*0.1;
        lightness = Math.round(d*100)/100;
    }
    if (state.type === "explicit-black-white") saturation = 0;
    return hslToRgb(hue,saturation,lightness);
}
function colors(state) { return positions(state).map(function(p) { return colorAt(p,state); }); }
function hex(rgb) { return "#"+rgb.map(function(v) { return v.toString(16).padStart(2,"0"); }).join(""); }
function primary(state) { return hex(colors(state)[0]); }
function fromHex(value, state) {
    if (!/^#[0-9a-fA-F]{6}$/.test(value)) return null;
    var rgb = [1,3,5].map(function(i) { return parseInt(value.slice(i,i+2),16)/255; });
    var max = Math.max.apply(null,rgb), min = Math.min.apply(null,rgb), d = max-min;
    var l = (max+min)/2, s = d === 0 ? 0 : d/(1-Math.abs(2*l-1)), h = 0;
    if (d !== 0) h = max === rgb[0] ? ((rgb[1]-rgb[2])/d+6)%6 : max === rgb[1] ? (rgb[2]-rgb[0])/d+2 : (rgb[0]-rgb[1])/d+4;
    var next = copy(state || initial()), angle = h*Math.PI/3, distance = (1-s)*205+0.2;
    next.x = (191+distance*Math.cos(angle))/380;
    next.y = (191+distance*Math.sin(angle))/380;
    next.lightness = l*100;
    next.type = "explicit-lightness";
    return next;
}
