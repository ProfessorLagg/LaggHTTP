// Settings
const board_canvas_size = 990;
const group_size = board_canvas_size / 3;
const cell_size = board_canvas_size / 9;
const piece_canvas_size = (board_canvas_size / 9) * 5;

// HTML Element Constants
const block_img = document.getElementById('blck-img');
const cell_img = document.getElementById('cell-img');
const highlight_img = document.getElementById('highlight-img');

const game_wrap = document.getElementById('game-wrap');
const game_score = document.getElementById('game-score');
const game_highscore = document.getElementById('game-highscore');

const board_background_canvas = document.getElementById('board-background');
const board_cells_canvas = document.getElementById('board-cells');
const board_highlight_canvas = document.getElementById('board-highlight');
const board_borders_canvas = document.getElementById('board-borders');
const piecedrag_canvas = document.getElementById('piecedrag');
const piece0 = document.getElementById('piece0');
const piece1 = document.getElementById('piece1');
const piece2 = document.getElementById('piece2');

// Static Image Datas
var block_imgdata_cellsize = undefined;
var cell_img_data_cellsize = undefined;
var highlight_img_data_cellsize = undefined;

// Canvas Render Contexts
const board_background_ctx2d = board_background_canvas.getContext("2d");
const board_cells_ctx2d = board_cells_canvas.getContext("2d")
const board_highlight_ctx2d = board_highlight_canvas.getContext("2d");
const board_borders_ctx2d = board_borders_canvas.getContext("2d");
const piecedrag_ctx2d = piecedrag_canvas.getContext("2d");
const piece0_ctx2d = piece0.getContext("2d");
const piece1_ctx2d = piece1.getContext("2d");
const piece2_ctx2d = piece2.getContext("2d");

// Bounds
const board_bounds = new DOMRect();
const cellPixelBounds = new Array(0);
const cellViewPortBounds = new Array(0);
const piece0_bounds = new DOMRect();
const piece1_bounds = new DOMRect();
const piece2_bounds = new DOMRect();
const piecedrag_bounds = new DOMRect();


// draw functions
var selectedPieceImageData = null;
var selectedPieceShape = null;
var piecedrag_prev_draw_bounds = null;
function updateSelectedPieceImageData() {
    console.timeStamp("TOP: draw_piecebuffer")
    const shapeId = game_state.selectedShapeId;
    if (shapeId === -1) {
        selectedPieceImageData = null;
        return;
    }
    selectedPieceShape = getShape(shapeId);

    const cShape = getShape(shapeId, true, true);
    const canvas = new OffscreenCanvas(cell_size * 5, cell_size * 5);
    const ctx = canvas.getContext("2d");
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';
    for (let i = 0; i < cShape.length; i++) {
        ctx.putImageData(
            block_imgdata_cellsize,
            cShape[i].c * cell_size,
            cShape[i].r * cell_size
        )
    }
    selectedPieceImageData = ctx.getImageData(0, 0, cell_size * 5, cell_size * 5);
    piecedrag_prev_draw_bounds = null;
    // selectedPieceImageData = renderShape(
    //     shapeId, // shapeId
    //     cell_size, // cellSize
    //     block_img, // blockimg
    //     true, // centerX
    //     true // centerY
    // );
    console.timeStamp("BOT: draw_piecebuffer")
}

function draw_board_background() {
    console.timeStamp("TOP: draw_board_background")
    board_background_ctx2d.fillStyle = "rgba(100,45,0,100%)";
    board_background_ctx2d.fillRect(0, 0, board_canvas_size, board_canvas_size);

    // Dark Groups
    // board_background_ctx2d.fillStyle = "rgba(255,255,255,20%)";
    board_background_ctx2d.fillStyle = color_board_dark;
    board_background_ctx2d.fillRect(0, 0, group_size, group_size);
    board_background_ctx2d.fillRect(group_size * 2, 0, group_size, group_size);
    board_background_ctx2d.fillRect(group_size, group_size, group_size, group_size);
    board_background_ctx2d.fillRect(0, group_size * 2, group_size, group_size);
    board_background_ctx2d.fillRect(group_size * 2, group_size * 2, group_size, group_size);

    // Light Groups
    // board_background_ctx2d.fillStyle = "rgba(255,255,255,50%)";
    board_background_ctx2d.fillStyle = color_board_light;
    board_background_ctx2d.fillRect(group_size, 0, group_size, group_size);
    board_background_ctx2d.fillRect(0, group_size, group_size, group_size);
    board_background_ctx2d.fillRect(group_size * 2, group_size, group_size, group_size);
    board_background_ctx2d.fillRect(group_size, group_size * 2, group_size, group_size);
    console.timeStamp("BOT: draw_board_background")
}
function draw_board_cells() {
    console.timeStamp("TOP: draw_board_cells")
    board_cells_ctx2d.clearRect(0, 0, board_canvas_size, board_canvas_size);
    for (let i = 0; i < cellPixelBounds.length; i++) {
        board_cells_ctx2d.putImageData(
            cell_img_data_cellsize,
            cellPixelBounds[i].x,
            cellPixelBounds[i].y
        );
    }
    console.timeStamp("BOT: draw_board_cells")
}
function draw_board_highlight() {
    console.timeStamp("TOP: draw_board_highlight")
    board_highlight_ctx2d.clearRect(0, 0, board_canvas_size, board_canvas_size);
    if (!pointerdata.bounds.intersects(board_bounds)) { return }
    if (game_state.selectedPieceId < 0 || game_state.selectedPieceId > 2) { return }
    for (let i = 0; i < hovering_cells.length; i++) {
        if (hovering_cells[i] > 0) {
            board_highlight_ctx2d.putImageData(
                highlight_img_data_cellsize,
                cellPixelBounds[i].x,
                cellPixelBounds[i].y
            )
        }
    }
    console.timeStamp("BOT: draw_board_highlight")
}
function draw_board_state() {
    console.timeStamp("TOP: draw_board_state")
    const ctx = board_borders_canvas.getContext("2d");
    ctx.clearRect(0, 0, board_canvas_size, board_canvas_size);
    for (let i = 0; i < cellPixelBounds.length; i++) {
        if (!game_state.getCellState(i)) { continue }

        const cell = cellPixelBounds[i];
        ctx.putImageData(
            block_imgdata_cellsize,
            cell.x,
            cell.y

        );
    }
    console.timeStamp("BOT: draw_board_state")
}
function draw_piecebuffer() {
    console.timeStamp("TOP: draw_piecebuffer")
    piece0_ctx2d.clearRect(0, 0, piece_canvas_size, piece_canvas_size);

    const unspent0 = game_state.pieces[0] >= 0;
    const placeable0 = unspent0 && game_state.canPlacePieceAnywhere(0);
    piece0.setAttribute("placeable", Number(placeable0));
    piece0_ctx2d.clearRect(0, 0, piece_canvas_size, piece_canvas_size);
    if (unspent0 && game_state.selectedPieceId != 0) {
        const shape = getShape(game_state.pieces[0], true)
        for (let i = 0; i < shape.length; i++) {
            piece0_ctx2d.putImageData(
                block_imgdata_cellsize,
                cell_size * shape[i].c,
                cell_size * shape[i].r,
            )
        }
    }

    const unspent1 = game_state.pieces[1] >= 0;
    const placeable1 = game_state.canPlacePieceAnywhere(1);
    piece1.setAttribute("placeable", Number(placeable1));
    piece1_ctx2d.clearRect(0, 0, piece_canvas_size, piece_canvas_size);
    if (unspent1 && game_state.selectedPieceId != 1) {
        const shape = getShape(game_state.pieces[1], true)
        for (let i = 0; i < shape.length; i++) {
            piece1_ctx2d.putImageData(
                block_imgdata_cellsize,
                cell_size * shape[i].c,
                cell_size * shape[i].r,
            )
        }
    }

    const unspent2 = isValidShapeId(game_state.pieces[2]);
    const placeable2 = unspent2 && game_state.canPlacePieceAnywhere(2);
    piece2.setAttribute("placeable", Number(placeable2));
    piece2_ctx2d.clearRect(0, 0, piece_canvas_size, piece_canvas_size);
    if (unspent2 && game_state.selectedPieceId != 2) {
        const shape = getShape(game_state.pieces[2], true)
        for (let i = 0; i < shape.length; i++) {
            piece2_ctx2d.putImageData(
                block_imgdata_cellsize,
                cell_size * shape[i].c,
                cell_size * shape[i].r,
            )
        }
    }
    console.timeStamp("BOT: draw_piecebuffer")
}
function draw_piecedrag() {
    console.timeStamp("TOP: draw_piecedrag")
    if (piecedrag_prev_draw_bounds === null) {
        piecedrag_ctx2d.clearRect(0, 0, piecedrag_canvas.width, piecedrag_canvas.height);
    } else {
        piecedrag_ctx2d.clearRect(
            piecedrag_prev_draw_bounds.x,
            piecedrag_prev_draw_bounds.y,
            piecedrag_prev_draw_bounds.width,
            piecedrag_prev_draw_bounds.height
        );
    }

    if (!game_state.hasSelectedPiece()) { return }

    // convert pointer position from viewport coordinates to drag canvas coordinates
    const pCenter = pointerdata.bounds;
    const pointer_uv_bounds = new DOMRect(
        (pCenter.x - piecedrag_bounds.left) / piecedrag_bounds.width,
        (pCenter.y - piecedrag_bounds.top) / piecedrag_bounds.height,
        pCenter.width / piecedrag_bounds.width,
        pCenter.height / piecedrag_bounds.height
    );

    const pixel_bounds = new DOMRect();
    pixel_bounds.width = cell_size * 5;
    pixel_bounds.height = cell_size * 5;
    pixel_bounds.x = (piecedrag_canvas.width * pointer_uv_bounds.x) - pixel_bounds.width / 2;
    pixel_bounds.y = (piecedrag_canvas.height * pointer_uv_bounds.y) - pixel_bounds.height / 2;
    piecedrag_ctx2d.putImageData(
        selectedPieceImageData,
        pixel_bounds.x,
        pixel_bounds.y,
        0,
        0,
        pixel_bounds.width,
        pixel_bounds.height
    );
    piecedrag_prev_draw_bounds = pixel_bounds;
    console.timeStamp("BOT: draw_piecedrag")
}
function draw_score() {
    console.timeStamp("TOP: draw_score")
    game_score.innerText = game_state.score;
    game_highscore.innerText = getHighscore();
    console.timeStamp("BOT: draw_score")
}

// Game
let game_state = new GameState();
/**
Details which cell indexes the player is currently hovedering.
Updated by update_hovering_cells() 
 */
const hovering_cells = new Uint8Array(81);
/**Updates the currently hovered cells info in hovering_cells */
function update_hovering_cells() {
    hovering_cells.fill(0);
    if (!pointerdata.bounds.intersects(board_bounds)) { return }
    if (game_state.selectedPieceId < 0 || game_state.selectedPieceId > 2) { return }

    const cell_index1D = pointer_cell_index;
    if (cell_index1D === null) { return }

    const cell_index2D = indexTo2D(cell_index1D, true);

    const shapeId = game_state.selectedShapeId;
    for (let i = 0; i < selectedPieceShape.length; i++) {
        const row = selectedPieceShape[i].r + cell_index2D.row - Math.round(shapeOffsetBounds[shapeId].height / 2);
        if (row < 0 || row > 8) {
            hovering_cells.fill(0);
            return;
        }
        const col = selectedPieceShape[i].c + cell_index2D.col - Math.round(shapeOffsetBounds[shapeId].width / 2);
        if (col < 0 || col > 8) {
            hovering_cells.fill(0);
            return;
        }
        const idx = indexTo1D(row, col, true);
        if (game_state.boardState[idx] > 0) {
            hovering_cells.fill(0);
            return;
        }
        hovering_cells[idx] = 1;
    }
}
var redraw_background = true;
var redraw_boardstate = true;
var redraw_highlights = true;
var redraw_drag = true;
var redraw_piecebuffer = true;
var redraw_score = true;
var lastGameUpdate = 0;
function gameLoop(timestamp = -1) {
    const fps = Math.round(1000 / (timestamp - lastGameUpdate));
    const fps_str = fps.toString().padStart(3, ' ') + " FPS | "
    console.timeStamp(fps_str + "gameLoop BEGIN");
    if (redraw_background) {
        redraw_background = false;
        draw_board_background();
        draw_board_cells();
    }
    if (redraw_boardstate) {
        redraw_boardstate = false;
        draw_board_state();
    }

    if (redraw_highlights) {
        redraw_highlights = false;
        draw_board_highlight();
    }

    if (redraw_drag) {
        redraw_drag = false;
        draw_piecedrag();
    }

    if (redraw_piecebuffer) {
        redraw_piecebuffer = false;
        draw_piecebuffer();
    }

    if (redraw_score) {
        redraw_score = false;
        draw_score();
    }



    lastGameUpdate = timestamp;
    console.timeStamp(fps_str + "gameLoop END");
    requestAnimationFrame(gameLoop);
}


// Storage
const shapevers_key = 'shapes-version';
const highscore_key = 'high-score';
const lastscore_key = 'last-score';
const savestate_key = 'save-state';
function getShapevers() {
    const result = parseInt(localStorage[shapevers_key]);
    return result * Number(TypeChecker.isInteger(result));
}
function getHighscore() {
    if (TypeChecker.isNullOrUndefined(localStorage[highscore_key])) { localStorage[highscore_key] = '0'; }
    const result = parseInt(localStorage[highscore_key]);
    if (!TypeChecker.isIntegerInRange(result, Number.MIN_SAFE_INTEGER, Number.MAX_SAFE_INTEGER)) { return 0 }
    return result;
}
function getLastscore() {
    if (TypeChecker.isNullOrUndefined(localStorage[lastscore_key])) { localStorage[lastscore_key] = '0'; }
    const result = parseInt(localStorage[lastscore_key]);
    if (!TypeChecker.isIntegerInRange(result, Number.MIN_SAFE_INTEGER, Number.MAX_SAFE_INTEGER)) { return 0 }
    return result;
}
function setLastscore(v) {
    TypeChecker.assertIsInteger(v);
    localStorage[lastscore_key] = v;
}
function updateStoredScores() {
    if (getShapevers() !== shapes.version) {
        console.log("Differing shapes version, overwriting localstorage data")
        localStorage[shapevers_key] = shapes.version;
    }
    // TODO Fanfare when highscore was beaten
    localStorage[highscore_key] = Math.max(getHighscore(), game_state.score);
    setLastscore(game_state.score);
}

function clearSave() {
    localStorage.removeItem(savestate_key);
}
/**
 * Saves the input gamestate to localstorage.
 * Overrides previous save
 * @param {GameState} state 
 */
function saveGave(state) {
    localStorage[savestate_key] = JSON.stringify(state.getSaveFile());
}
/**Checks if there exists a saved GameStateSaveFile */
function loadGamePossible() { return !TypeChecker.isNullOrUndefined(localStorage[savestate_key]) }
/**
 * Loads a game from localstorage.
 * @returns A GameStateSaveFile if a save was found, otherwise null
 */
function loadGame() {
    if (!loadGamePossible()) { return null }
    const result = JSON.parse(localStorage[savestate_key]);
    return Object.assign(new GameStateSaveFile, result)
}

// init
async function init() {
    console.time(arguments.callee.name);
    await loadShapes();
    await initImageDatas();
    await initCellBounds();
    await initBoardCanvas();
    await initPieceCanvas();
    await initPieceDragCanvas();
    await initGameState(); // MUST BE RUN AFTER initPieceCanvas()
    await initPointerEvents();
    await initResizeEvent();
    setLastscore(0);
    showMenu();
    requestAnimationFrame(gameLoop);
    console.timeEnd(arguments.callee.name)
}
async function initCellBounds() {
    console.time(arguments.callee.name);
    const s = board_canvas_size / 9;
    let i = 0;
    for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
            cellPixelBounds[i] = {
                x: c * s,
                y: r * s,
                w: s,
                h: s
            };
            i++;
        }
    }
    console.timeEnd(arguments.callee.name);
}

// Colors
// const color_board_dark = ;
const color_board_dark = 'hsl(25, 50%, 20%)';
const color_board_light = 'hsl(25, 50%, 80%)';
const color_cell_border = 'hsl(15, 50%, 10%)';//'#977254'; // 'rgb(100,45,0)'
const color_cell_highlight = 'hsl(205, 100%, 50%)'; // 'hsl(50, 100%, 50%)'
const color_block = 'hsl(35, 50%, 50%)';//'#653200'; // 'magenta'
// const color_block = 'magenta';
async function initImageDatas() {
    console.time(arguments.callee.name);

    let tmp_img_data = undefined;
    const canvas = new OffscreenCanvas(cell_size, cell_size);
    const ctx = canvas.getContext("2d", { aplha: true, willReadFrequently: false });
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';

    // block
    ctx.clearRect(0, 0, cell_size, cell_size);
    ctx.drawImage(block_img, 0, 0, cell_size, cell_size);
    block_imgdata_cellsize = ctx.getImageData(0, 0, cell_size, cell_size);

    ctx.fillStyle = color_block;
    ctx.fillRect(0, 0, cell_size, cell_size);
    tmp_img_data = ctx.getImageData(0, 0, cell_size, cell_size, { colorSpace: "srgb" });
    const color_block_srgb = tmp_img_data.data.slice(0, 4);
    let r0 = Number(color_block_srgb[0]) / 255
    let g0 = Number(color_block_srgb[1]) / 255
    let b0 = Number(color_block_srgb[2]) / 255
    for (let i = 0; i < block_imgdata_cellsize.data.length; i += 4) {
        const r1 = Number(block_imgdata_cellsize.data[i + 0]) / 255;
        const g1 = Number(block_imgdata_cellsize.data[i + 1]) / 255;
        const b1 = Number(block_imgdata_cellsize.data[i + 2]) / 255;
        const r = overlay(r0, r1);
        const g = overlay(g0, g1);
        const b = overlay(b0, b1);
        block_imgdata_cellsize.data[i + 0] = Math.round(255 * r);
        block_imgdata_cellsize.data[i + 1] = Math.round(255 * g);
        block_imgdata_cellsize.data[i + 2] = Math.round(255 * b);
        block_imgdata_cellsize.data[i + 3] = 255 * Number(block_imgdata_cellsize.data[i + 3] > 0);
    }

    // cell
    ctx.clearRect(0, 0, cell_size, cell_size);
    ctx.drawImage(cell_img, 0, 0, cell_size, cell_size);
    cell_img_data_cellsize = ctx.getImageData(0, 0, cell_size, cell_size, { colorSpace: "srgb" });

    ctx.fillStyle = color_cell_border;
    ctx.fillRect(0, 0, cell_size, cell_size);
    tmp_img_data = ctx.getImageData(0, 0, cell_size, cell_size, { colorSpace: "srgb" });
    const color_cell_border_srgb = tmp_img_data.data.slice(0, 4);
    r0 = Number(color_cell_border_srgb[0]) / 255
    g0 = Number(color_cell_border_srgb[1]) / 255
    b0 = Number(color_cell_border_srgb[2]) / 255
    for (let i = 0; i < cell_img_data_cellsize.data.length; i += 4) {
        cell_img_data_cellsize.data[i + 0] = color_cell_border_srgb[0];
        cell_img_data_cellsize.data[i + 1] = color_cell_border_srgb[1];
        cell_img_data_cellsize.data[i + 2] = color_cell_border_srgb[2];
    }

    // highlight
    ctx.clearRect(0, 0, cell_size, cell_size);
    ctx.drawImage(highlight_img, 0, 0, cell_size, cell_size);
    highlight_img_data_cellsize = ctx.getImageData(0, 0, cell_size, cell_size);

    ctx.fillStyle = color_cell_highlight;
    ctx.fillRect(0, 0, cell_size, cell_size);
    tmp_img_data = ctx.getImageData(0, 0, cell_size, cell_size, { colorSpace: "srgb" });
    const color_cell_highlight_srgb = tmp_img_data.data.slice(0, 4);
    for (let i = 0; i < highlight_img_data_cellsize.data.length; i += 4) {
        highlight_img_data_cellsize.data[i + 0] = color_cell_highlight_srgb[0]
        highlight_img_data_cellsize.data[i + 1] = color_cell_highlight_srgb[1]
        highlight_img_data_cellsize.data[i + 2] = color_cell_highlight_srgb[2]
    }


    console.timeEnd(arguments.callee.name);
}
async function initBoardCanvas() {
    console.time(arguments.callee.name);
    Array.from(document.querySelectorAll(".board-canvas")).forEach(board_canvas => {
        board_canvas.width = board_canvas_size;
        board_canvas.height = board_canvas_size;
    });
    board_background_ctx2d.imageSmoothingEnabled = false;
    board_cells_ctx2d.imageSmoothingEnabled = false;
    board_highlight_ctx2d.imageSmoothingEnabled = false;
    draw_board_background();
    draw_board_cells();
    console.timeEnd(arguments.callee.name);
}
async function initPieceCanvas() {
    console.time(arguments.callee.name);
    piece0.width = piece_canvas_size;
    piece0.height = piece_canvas_size;
    piece1.width = piece_canvas_size;
    piece1.height = piece_canvas_size;
    piece2.width = piece_canvas_size;
    piece2.height = piece_canvas_size;
    console.timeEnd(arguments.callee.name);
}
async function initPieceDragCanvas() {
    console.time(arguments.callee.name);
    updatePiecedragSize();
    piecedrag_ctx2d.imageSmoothingEnabled = false;
    console.timeEnd(arguments.callee.name);
}
async function initPointerEvents() {
    console.time(arguments.callee.name);
    window.addEventListener("pointermove", pointermoveHandler);
    window.addEventListener("pointerdown", pointerdownHandler);
    window.addEventListener("pointerup", pointerupHandler);
    console.timeEnd(arguments.callee.name);
}
async function initResizeEvent() {
    console.time(arguments.callee.name);
    resizeHandler();
    window.addEventListener("resize", resizeHandler);
    console.timeEnd(arguments.callee.name);
}
async function initGameState() {
    console.time(arguments.callee.name);
    game_state.boardStateChangedCallback = () => {
        redraw_boardstate = true;
        saveGave(game_state);
    };
    game_state.pieceBufferChangedCallback = () => {
        redraw_piecebuffer = true;
        saveGave(game_state);
    };
    game_state.scoreChangedCallback = () => {
        updateStoredScores();
        redraw_score = true;
        saveGave(game_state);
    }
    game_state.selectionChangedCallback = () => {
        if (game_state.hasSelectedPiece()) {
            updateSelectedPieceImageData();
            redraw_highlights = true;
            redraw_drag = true;
        }
        redraw_piecebuffer = true;
    };
    game_state.gameoverCallback = () => {
        clearSave();
        menu_title.innerText = "Gameover!"
        showMenu();
    }
    console.timeEnd(arguments.callee.name);
}

// Menu
const menu_screen = document.getElementById('menu-screen');
const menu_title = document.getElementById('menu-title');
const menu_highscore = document.getElementById('menu-highscore');
const menu_lastscore = document.getElementById('menu-lastscore');
const btn_resume_game = document.getElementById('btn-resume-game');

async function hideMenu() { menu_screen.classList.add('hidden'); }
async function showMenu() {
    if (!loadGamePossible()) { btn_resume_game.classList.add('hidden'); }
    else { btn_resume_game.classList.remove('hidden'); }

    const highscore = getHighscore();
    if (highscore <= 0) { menu_highscore.classList.add('hidden') }
    else {
        menu_highscore.classList.remove('hidden');
        menu_highscore.querySelector('.value').textContent = highscore;
    }

    const lastscore = getLastscore();
    if (lastscore <= 0) { menu_lastscore.classList.add('hidden') }
    else {
        menu_lastscore.classList.remove('hidden');
        menu_lastscore.querySelector('.value').textContent = lastscore;
    }

    menu_screen.classList.remove('hidden');
}
async function btn_new_game_click(event) {
    game_state.restart();
    hideMenu();
}
async function btn_resume_game_click(event) {
    const saveFile = loadGame();
    game_state.restart();
    if (TypeChecker.isNullOrUndefined(saveFile)) {
        console.error("Save File was null or undefined!")
        return
    }
    game_state.loadSaveFile(saveFile);
    hideMenu();
}

// resize event
function updateViewPortBoundsData() {
    const c_board_bounds = board_background_canvas.getBoundingClientRect();
    board_bounds.x = c_board_bounds.x;
    board_bounds.y = c_board_bounds.y;
    board_bounds.width = c_board_bounds.width;
    board_bounds.height = c_board_bounds.height;

    const c_piece0_bounds = piece0.getBoundingClientRect();
    piece0_bounds.x = c_piece0_bounds.x;
    piece0_bounds.y = c_piece0_bounds.y;
    piece0_bounds.width = c_piece0_bounds.width;
    piece0_bounds.height = c_piece0_bounds.height;

    const c_piece1_bounds = piece1.getBoundingClientRect();
    piece1_bounds.x = c_piece1_bounds.x;
    piece1_bounds.y = c_piece1_bounds.y;
    piece1_bounds.width = c_piece1_bounds.width;
    piece1_bounds.height = c_piece1_bounds.height;

    const c_piece2_bounds = piece2.getBoundingClientRect();
    piece2_bounds.x = c_piece2_bounds.x;
    piece2_bounds.y = c_piece2_bounds.y;
    piece2_bounds.width = c_piece2_bounds.width;
    piece2_bounds.height = c_piece2_bounds.height;

    const c_piecedrag_bounds = piecedrag_canvas.getBoundingClientRect();
    piecedrag_bounds.x = c_piecedrag_bounds.x;
    piecedrag_bounds.y = c_piecedrag_bounds.y;
    piecedrag_bounds.width = c_piecedrag_bounds.width;
    piecedrag_bounds.height = c_piecedrag_bounds.height;

    cellViewPortBounds.length = 81;
    for (let r = 0; r < 9; r++) {
        for (let c = 0; c < 9; c++) {
            const idx = indexTo1D(r, c, true);
            cellViewPortBounds[idx] = new DOMRect(
                rangeMapNumber(c, 0, 8, board_bounds.left, board_bounds.right),
                rangeMapNumber(r, 0, 8, board_bounds.top, board_bounds.bottom),
                board_bounds.width / 9,
                board_bounds.height / 9
            )
        }
    }
}
function updatePiecedragSize() {
    const scaleW = piecedrag_bounds.width / board_bounds.width;
    const scaleH = piecedrag_bounds.height / board_bounds.height;
    piecedrag_canvas.width = board_canvas_size * scaleW;
    piecedrag_canvas.height = board_canvas_size * scaleH;
}
async function resizeHandler() {
    updateViewPortBoundsData();
    updatePiecedragSize();
}

// pointer
const pointerdata = new PointerData();
var pointer_cell_index = -1;
var pointermoveFrameRequested = false;
async function pointermoveHandler(event) {
    if (!pointerdata.update(event)) { return }
    if (!game_state.hasSelectedPiece()) { return }

    pointer_cell_index = getPointerCellIndex();
    update_hovering_cells();
    redraw_highlights = true;
    redraw_drag = true;
}
async function pointerdownHandler(event) {
    if (!pointerdata.update(event)) { return }
    console.debug("pointerdown");

    const clicked0 = game_state.pieces[0] >= 0 && pointerdata.bounds.intersects(piece0_bounds);
    const clicked1 = game_state.pieces[1] >= 0 && pointerdata.bounds.intersects(piece1_bounds);
    const clicked2 = game_state.pieces[2] >= 0 && pointerdata.bounds.intersects(piece2_bounds);
    const clicked_pieceId = -1
        + (1 * Number(clicked0))
        + (2 * Number(clicked1))
        + (3 * Number(clicked2));

    if (clicked_pieceId === -1) { return }
    game_state.selectPiece(clicked_pieceId);
}
async function pointerupHandler(event) {
    // if (!pointerdata.update(event)) { return }
    console.debug("pointerup");

    const pointerInsersectsBoard = pointerdata.bounds.intersects(board_bounds);
    const canTryPlace = game_state.hasSelectedPiece() && hovering_cells.sum() > 0 && pointerInsersectsBoard;

    if (canTryPlace) {
        game_state.forcePlaceSelectedPiece(hovering_cells);
    } else {
        game_state.clearSelectedPiece();
    }

    selectedPieceImageData = null;
    redraw_highlights = true;
    redraw_drag = true;
}
function getPointerCellIndex() {
    if (!pointerdata.bounds.intersects(board_bounds)) { return null }
    const pCenter = pointerdata.bounds;

    const uvX = rangeMapNumber(pCenter.x, board_bounds.left, board_bounds.right, 0, 1);
    let col = Math.floor(uvX * 9)
    if (col < 0 || col > 8) { return null }

    const uvY = rangeMapNumber(pCenter.y, board_bounds.top, board_bounds.bottom, 0, 1);
    let row = Math.floor(uvY * 9);
    if (row < 0 || row > 8) { return null }

    return indexTo1D(row, col, true);
}