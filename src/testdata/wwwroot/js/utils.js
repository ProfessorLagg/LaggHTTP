/**
 * Maps x from the range [srcMin - srcMax] to the range [dstMin - dstMax]
 * @param {Number} x 
 * @param {Number} srcMin 
 * @param {Number} srcMax 
 * @param {Number} dstMin 
 * @param {Number} dstMax 
 * @returns Number
 */
function rangeMapNumber(x, srcMin, srcMax, dstMin, dstMax) {
    return (x - srcMin) / (srcMax - srcMin) * (dstMax - dstMin) + dstMin;
}
/**
 * Converts 2D board index to 1D board index
 * @param {Number} row 
 * @param {Number} col
 * @param {Boolean} [skip_range_check] Flag to allow out out range input
 * @returns The result 1D index in the range [0-80]
 */
function indexTo1D(row, col, skip_range_check = false) {
    TypeChecker.assertIsInteger(row);
    TypeChecker.assertIsInteger(col);
    if (!skip_range_check && (row < 0 || row > 8)) { throw Error("row must be in the range [0 - 8], but was: " + row) }
    if (!skip_range_check && (col < 0 || col > 8)) { throw Error("col must be in the range [0 - 8], but was: " + col) }

    const r = Math.max(0, Math.min(9, row));
    const c = Math.max(0, Math.min(9, col));
    return r * 9 + c;
}
/**
 * Converts 1D board index to 2D board index
 * @param {Number} index 
 * @param {Boolean} [skip_range_check] Flag to allow out out range input
 * @returns The resulting 2D index row and col
 */
function indexTo2D(index, skip_range_check = false) {
    TypeChecker.assertIsInteger(index);
    if (!skip_range_check && (index < 0 || index > 80)) { throw Error("index must be in the range [0 - 80], but was: " + index) }
    const idx = Math.max(0, Math.min(80, index));
    const col = idx % 9;
    const row = (idx - col) / 9
    return {
        row: row,
        col: col,
    }
}
/**
 * Calculates board group from 2D board index
 * @param {Number} row 
 * @param {Number} col 
 * @returns The resulting board group index
 */
function indexToGroup(row, col) {
    TypeChecker.assertIsInteger(row);
    TypeChecker.assertIsInteger(col);
    if (row < 0 || row > 8) { throw Error("row must be in the range [0 - 8], but was: " + row) }
    if (col < 0 || col > 8) { throw Error("col must be in the range [0 - 8], but was: " + col) }
    const r = Math.max(0, Math.min(9, row));
    const c = Math.max(0, Math.min(9, col));
    const gr = Math.floor(r / 3) * 3;
    const gc = Math.floor(c / 3);
    return gr + gc;
}
function roundDecimals(value, decimals) {
    const mul = Math.pow(10, Math.max(0, decimals));
    return Math.round(value * mul) / mul;
}
function distanceSquared2D(x0, y0, x1, y1) {
    const a = Math.max(x0, x1) - Math.min(x0, x1);
    const b = Math.max(y0, y1) - Math.min(y0, y1);
    const a2 = a * a;
    const b2 = b * b;
    return a2 + b2;
}
function distance2D(x0, y0, x1, y1) {
    return Math.sqrt(distanceSquared2D(x0, y0, x1, y1));
}

const cell_index_info = [];
{
    cell_index_info.length = 0;
    for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
            const i = indexTo1D(r, c, false);
            const g = indexToGroup(r, c);
            cell_index_info.push({
                idx: i,
                grp: g,
                row: r,
                col: c,
            })
        }
    }
}

function getGroupCellIndexes(group) {
    TypeChecker.assertIsIntegerInRange(group, 0, 8);
    const result = [];
    for (let i = 0; i < cell_index_info.length; i++) {
        if (cell_index_info[i].grp === group) {
            result.push(cell_index_info[i]);
        }
    }
    return result;
}
function getRowCellIndexes(row) {
    TypeChecker.assertIsIntegerInRange(row, 0, 8);
    const result = [];
    for (let i = 0; i < cell_index_info.length; i++) {
        if (cell_index_info[i].row === row) {
            result.push(cell_index_info[i]);
        }
    }
    return result;
}
function getColumnCellIndexes(column) {
    TypeChecker.assertIsIntegerInRange(column, 0, 8);
    const result = [];
    for (let i = 0; i < cell_index_info.length; i++) {
        if (cell_index_info[i].col === column) {
            result.push(cell_index_info[i]);
        }
    }
    return result;
}


function rgb_to_hsv(R, G, B) {
    const r = Number(R) / 255.0;
    const g = Number(G) / 255.0;
    const b = Number(B) / 255.0;
    const cmax = Math.max(r, Math.max(g, b));
    const cmin = Math.min(r, Math.min(g, b));
    const diff = cmax - cmin;
    let h = 0;
    switch (cmax) {
        case r: h = (60 * ((g - b) / diff) + 360) % 360; break;
        case g: h = (60 * ((b - r) / diff) + 120) % 360; break;
        case b: h = (60 * ((r - g) / diff) + 240) % 360; break;
        default: break;
    }
    return {
        h: h,
        s: cmax === 0 ? 0 : (diff / cmax),
        v: cmax
    };
}

// Blending Functions
function lerp(v0, v1, t) {
    return (1 - t) * v0 + t * v1;
}
function screen(a, b) {
    return 1.0 - (1.0 - a) * (1.0 - b);
}
function overlay(a, b) {
    if (a < 0.5) {
        return 2.0 * a * b;
    } else {
        return 1.0 - 2.0 * (1.0 - a) * (1.0 - b);
    }
}
function hardlight(a, b) {
    if (b < 0.5) {
        return 2.0 * a * b;
    } else {
        return 1.0 - 2.0 * (1.0 - a) * (1.0 - b);
    }
}
function softlight(a, b) {
    const _2b = 2 * b;
    const a2 = a * a;
    const _2ba = 2 * (b * a);
    return (1 - _2b) * a2 + _2ba;
}
function darken_only(a, b){
    return Math.min(a,b);
}
function lighten_only(a, b){
    return Math.max(a,b);
}