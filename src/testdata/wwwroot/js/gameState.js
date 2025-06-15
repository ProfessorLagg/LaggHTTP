// Game State
class GameStateSaveFile {
    prng_seed = null;
    prng_count = 0;
    prng_state = null;
    score = 0;
    board = null;
    pieces = null;
}

class GameState {
    static isValidPieceId(pieceId) { return TypeChecker.isIntegerInRange(pieceId, 0, 2); }
    static assertIsValidPieceId(pieceId) { if (!GameState.isValidPieceId(pieceId)) { throw Error(pieceId + " is not a valid pieceId") } }

    prng = new sfc32(new Uint32Array(4));
    buffer = new ArrayBuffer(
        + 81 // boardState
        + 6 // pieces
        + 4 // score
    );

    boardState = new Uint8Array(this.buffer.slice(0, 81));
    pieces = new Int16Array(this.buffer.slice(81, 87));
    selectedPieceId = -1;
    get selectedShapeId() {
        const shapeId = this.pieces[this.selectedPieceId];
        assertIsValidShapeId(shapeId);
        return shapeId;
    }
    scoreState = new Uint32Array(this.buffer.slice(87));

    get score() { return this.scoreState[0]; }
    set score(v) {
        TypeChecker.assertIsInteger(v);
        this.scoreState[0] = v;
        this.scoreChangedCallback();
    }

    boardStateChangedCallback = () => { }
    pieceBufferChangedCallback = () => { }
    scoreChangedCallback = () => { }
    selectionChangedCallback = () => { }
    gameoverCallback = () => { }

    canPlaceShape(cellIndex1D, shapeId, shape) {
        if (TypeChecker.isNullOrUndefined(shape)) {
            return this.canPlaceShape(cellIndex1D, shapeId, getShape(shape));
        }

        const cellIndex2D = indexTo2D(cellIndex1D);
        for (let i = 0; i < shape.length; i++) {
            const row = shape[i].r + cellIndex2D.row;
            if (!TypeChecker.isIntegerInRange(row, 0, 8)) {
                return false
            }
            const col = shape[i].c + cellIndex2D.col;
            if (!TypeChecker.isIntegerInRange(col, 0, 8)) {
                return false
            }
            const idx = indexTo1D(row, col, false);
            if (this.boardState[idx] === 1) {
                return false
            }
        }
        return true;
    }
    canPlaceShapeAnywhere(shapeId) {
        const shape = getShape(shapeId)
        for (let i = 0; i < 81; i++) {
            if (this.canPlaceShape(i, shapeId, shape)) { return true }
        }
        return false;
    }
    canPlacePieceAnywhere(pieceId) {
        GameState.assertIsValidPieceId(pieceId);
        const shapeId = this.pieces[pieceId];
        if (shapeId === -1) { return false }
        assertIsValidShapeId(shapeId)
        return this.canPlaceShapeAnywhere(shapeId);
    }
    isGameover() {
        if (this.canPlacePieceAnywhere(0)) { return false }
        if (this.canPlacePieceAnywhere(1)) { return false }
        if (this.canPlacePieceAnywhere(2)) { return false }
        return true;
    }

    /**
     * Gets the filled state of a board cell by it's index
     * @param {Number} cellIndex1D 
     * @returns true if the cell is filled or false if it is empty
     */
    getCellState(cellIndex1D) { return this.boardState[cellIndex1D] > 0; }
    getClearableSections() {
        const result = [];
        for (let I = 0; I < 9; I++) {
            const grp_indexes = getGroupCellIndexes(I);
            const row_indexes = getRowCellIndexes(I);
            const col_indexes = getColumnCellIndexes(I);

            let grp_clearable = true;
            let row_clearable = true;
            let col_clearable = true;
            for (let i = 0; i < 9; i++) {
                const grp_info = grp_indexes[i];
                const row_info = row_indexes[i];
                const col_info = col_indexes[i];
                grp_clearable = grp_clearable && (this.boardState[grp_info.idx] > 0);
                row_clearable = row_clearable && (this.boardState[row_info.idx] > 0);
                col_clearable = col_clearable && (this.boardState[col_info.idx] > 0);
            }
            if (grp_clearable) { result.push(grp_indexes) }
            if (row_clearable) { result.push(row_indexes) }
            if (col_clearable) { result.push(col_indexes) }
        }
        return result;
    }
    clearSections() {
        const clearable_sections = this.getClearableSections();
        for (let I = 0; I < clearable_sections.length; I++) {
            const section = clearable_sections[I];
            for (let i = 0; i < section.length; i++) {
                this.boardState[section[i].idx] = 0;
                this.score += 1;
            }
            this.boardStateChangedCallback()
        }
    }

    /**Runs this.generatePieces() if this.pieces is empty */
    tryGeneratePieces() {
        if (this.pieces.sum() === -3) {
            this.generatePieces();
        }
    }
    generatePieces() {
        let can_place = false;
        this.pieces[0] = this.prng.nextInt() % shapeIds.length;
        can_place ||= this.canPlacePieceAnywhere(0);
        this.pieces[1] = this.prng.nextInt() % shapeIds.length;
        can_place ||= this.canPlacePieceAnywhere(1);
        this.pieces[2] = this.prng.nextInt() % shapeIds.length;
        can_place ||= this.canPlacePieceAnywhere(2);

        const max_retries = 80;
        let retries = 0;
        while (!can_place) {
            retries += 1;
            if (retries > max_retries) { throw Error("Could not generate placeable piece in " + max_retries + " attempts") }
            this.pieces[2] = this.prng.nextInt() % shapeIds.length;
            can_place ||= this.canPlacePieceAnywhere(2);
        }
        this.pieceBufferChangedCallback();
    }
    selectPiece(pieceId) {
        GameState.assertIsValidPieceId(pieceId);
        assertIsValidShapeId(this.pieces[pieceId]);
        this.selectedPieceId = pieceId;
        console.debug("Selected piece " + this.selectedPieceId);
        this.selectionChangedCallback();
    }
    clearSelectedPiece() {
        this.selectedPieceId = -1;
        console.debug("Selected piece " + this.selectedPieceId);
        this.selectionChangedCallback();
    }
    tryPlaceSelectedPiece(cellIndex1D) {
        console.debug("GameState.tryPlaceSelectedPiece", "cellIndex:", cellIndex1D);
        const cell_index2D = indexTo2D(cellIndex1D, true);
        const shapeId = this.selectedShapeId;
        const shape = getShape(shapeId);
        const cell_states = new Uint8Array(81);

        for (let i = 0; i < shape.length; i++) {
            const row = shape[i].r + cell_index2D.row - Math.round(shapeOffsetBounds[shapeId].height / 2);
            if (row < 0 || row > 8) { return false }
            const col = shape[i].c + cell_index2D.col - Math.round(shapeOffsetBounds[shapeId].width / 2);
            if (col < 0 || col > 8) { return false }
            const idx = indexTo1D(row, col, true);
            if (game_state.boardState[idx] > 0) { return false }
            cell_states[idx] = 1;
        }

        forcePlaceSelectedPiece(cell_states);

        return true;
    }
    /**
     * Places the currently selected piece.
     * Accepting the input length 81 Uint8Array as the placed blocks.
     * Warning! Does not check that the input is correct in ANY WAY
     * @param {Uint8Array} cell_states 
     */
    forcePlaceSelectedPiece(cell_states) {
        for (let i = 0; i < cell_states.length; i++) {
            if (cell_states[i] === 1) {
                this.boardState[i] = 1;
                this.score += 1;
            }
        }
        this.clearSections();
        this.boardStateChangedCallback();

        this.pieces[this.selectedPieceId] = -1;
        this.pieceBufferChangedCallback();
        this.clearSelectedPiece();
        this.tryGeneratePieces();

        if (this.isGameover()) {
            this.gameoverCallback();
        }
    }
    hasSelectedPiece() { return this.selectedPieceId >= 0 && this.selectedPieceId <= 2; }

    restart(trigger_callbacks = true) {
        this.prng.reset(sfc32.generateSeed());
        this.scoreState[0] = 0;
        this.boardState.fill(0);
        this.pieces.fill(-1);
        this.generatePieces();

        this.boardStateChangedCallback();
    }
    constructor() {
    }

    getSaveFile() {
        const result = new GameStateSaveFile();
        result.prng_seed = Array.from(this.prng.seed);
        result.prng_count = this.prng.count;
        result.prng_state = Array.from(this.prng.state);

        result.score = this.score;
        result.board = Array.from(this.boardState);
        result.pieces = Array.from(this.pieces);
        return result;
    }
    loadSaveFile(saveFile) {
        if (!saveFile instanceof GameStateSaveFile) {
            throw Error("expected GameStateSaveFile, but found: " + saveFile);
        }

        this.prng.seed[0] = saveFile.prng_seed[0];
        this.prng.seed[1] = saveFile.prng_seed[1];
        this.prng.seed[2] = saveFile.prng_seed[2];
        this.prng.seed[3] = saveFile.prng_seed[3];
        this.prng.count = saveFile.prng_count;
        this.prng.state[0] = saveFile.prng_state[0];
        this.prng.state[1] = saveFile.prng_state[1];
        this.prng.state[2] = saveFile.prng_state[2];
        this.prng.state[3] = saveFile.prng_state[3];

        this.score = saveFile.score;
        this.scoreChangedCallback();

        for (let i = 0; i < 81; i++) { this.boardState[i] = saveFile.board[i]; }
        this.boardStateChangedCallback();

        this.pieces[0] = saveFile.pieces[0];
        this.pieces[1] = saveFile.pieces[1];
        this.pieces[2] = saveFile.pieces[2];
        this.pieceBufferChangedCallback();
    }
}