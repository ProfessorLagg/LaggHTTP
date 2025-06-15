const shapes = {};
const shapeIds = [];
const shapeOffsetBounds = {}
function isValidShapeId(shapeId) {
    if (typeof shapeId !== "number") { return false }
    if (!Number.isInteger(shapeId)) { return false }
    if (shapeIds.indexOf(shapeId) < 0) { return false }
    return true;
}
function assertIsValidShapeId(shapeId) {
    if (typeof shapeId !== "number") { throw Error("shapeId must be a number"); }
    if (!Number.isInteger(shapeId)) { throw Error("shapeId must be an integer"); }
    if (shapeIds.indexOf(shapeId) < 0) { throw Error("no shape has the shapeId " + shapeId); }
}
const centerOffsetLookup = [
    2, // 1
    1, // 2
    1, // 3
    0, // 4
    0, // 5
]
/**
 * Finds the min/max col/row of a shape
 * @param {Number} shapeId 
 * @returns An Object with the keys: min_col, min_row, max_col, max_row, col_center_offset, row_center_offset
 */
function getShapeOffsetBounds(shapeId) {
    assertIsValidShapeId(shapeId);
    if (shapeOffsetBounds[shapeId] === undefined) {
        const shape = shapes[shapeId];
        shapeOffsetBounds[shapeId] = {
            min_col: Number.MAX_SAFE_INTEGER,
            min_row: Number.MAX_SAFE_INTEGER,
            max_col: Number.MIN_SAFE_INTEGER,
            max_row: Number.MIN_SAFE_INTEGER,
            width: 0,
            height: 0,
            col_center_offset: 0,
            row_center_offset: 0,
        }
        for (let i = 0; i < shape.length; i++) {
            shapeOffsetBounds[shapeId].min_col = Math.min(shapeOffsetBounds[shapeId].min_col, shape[i].c);
            shapeOffsetBounds[shapeId].min_row = Math.min(shapeOffsetBounds[shapeId].min_row, shape[i].r);
            shapeOffsetBounds[shapeId].max_col = Math.max(shapeOffsetBounds[shapeId].max_col, shape[i].c);
            shapeOffsetBounds[shapeId].max_row = Math.max(shapeOffsetBounds[shapeId].max_row, shape[i].r);
        }
        // shapeOffsetBounds[shapeId].col_center_offset = Math.floor((5 - shapeOffsetBounds[shapeId].max_col) / 2)
        // shapeOffsetBounds[shapeId].row_center_offset = Math.floor((5 - shapeOffsetBounds[shapeId].max_row) / 2)
        shapeOffsetBounds[shapeId].width = shapeOffsetBounds[shapeId].max_col - shapeOffsetBounds[shapeId].min_col;
        shapeOffsetBounds[shapeId].height = shapeOffsetBounds[shapeId].max_row - shapeOffsetBounds[shapeId].min_row;

        shapeOffsetBounds[shapeId].col_center_offset = centerOffsetLookup[shapeOffsetBounds[shapeId].width] ?? 0;
        shapeOffsetBounds[shapeId].row_center_offset = centerOffsetLookup[shapeOffsetBounds[shapeId].height] ?? 0;

    }
    return shapeOffsetBounds[shapeId];
}

function getShape(shapeId, centerX = false, centerY = false) {
    assertIsValidShapeId(shapeId);
    TypeChecker.assertIsBoolean(centerX);
    TypeChecker.assertIsBoolean(centerY);

    const add_col = shapeOffsetBounds[shapeId].col_center_offset * Number(centerX);
    const add_row = shapeOffsetBounds[shapeId].row_center_offset * Number(centerY);
    const shape = [];
    shape.length = shapes[shapeId].length;
    for (let i = 0; i < shape.length; i++) {
        shape[i] = {
            c: shapes[shapeId][i].c + add_col,
            r: shapes[shapeId][i].r + add_row,
        };
    }
    return shape;
}

/**Used to save on GC while rendering shapes */
const shape_canvas = new OffscreenCanvas(0, 0);
const shape_ctx2d = shape_canvas.getContext("2d", { aplha: true, willReadFrequently: true });
/**
 * Renders a shape to ImageData
 * @param {Number} shapeId 
 * @param {Number} cellSize 
 * @param {Object} blockimg 
 * @param {Boolean} [centerX]
 * @param {Boolean} [centerY]
 */
function renderShape(shapeId, cellSize, blockimg, centerX = false, centerY = false) {
    TypeChecker.assertIsInteger(cellSize);
    if (!isValidShapeId(shapeId)) { throw Error(shapeId + " is not a valid shapeId"); }

    const shape = getShape(shapeId, centerX, centerY);
    shape_canvas.width = cellSize * 5;
    shape_canvas.height = cellSize * 5;

    shape_ctx2d.imageSmoothingEnabled = false;
    for (let i = 0; i < shape.length; i++) {
        shape_ctx2d.drawImage(
            blockimg,
            shape[i].c * cellSize,
            shape[i].r * cellSize,
            cellSize,
            cellSize
        );
    }
    return shape_ctx2d.getImageData(0, 0, shape_canvas.width, shape_canvas.height);
}

async function loadShapes() {
    console.time(arguments.callee.name);
    // Update shapes
    const req = fetch("data/shapes.json");
    for (key in shapes) { delete shapes[key]; }
    const rsp = await req;
    const new_shapes = await rsp.json();
    for (key in new_shapes) { shapes[key] = new_shapes[key]; }

    // Update shapeIds
    const new_shapeIds = Object
        .keys(shapes)
        .flatMap(x => Number(x))
        .filter(x => Number.isInteger(x))
        .filter(x => x >= 0);
    new_shapeIds.sort(function (a, b) { return a - b });
    shapeIds.length = new_shapeIds.length;
    for (let i = 0; i < new_shapeIds.length; i++) { shapeIds[i] = new_shapeIds[i]; }

    // Update shapeCenters
    for (key in shapeOffsetBounds) { delete shapeOffsetBounds[key]; }
    for (let i = 0; i < shapeIds.length; i++) {
        _ = getShapeOffsetBounds(shapeIds[i]);
    }
    console.timeEnd(arguments.callee.name);
    console.log("shapes:", shapes);
}