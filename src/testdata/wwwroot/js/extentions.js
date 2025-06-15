/**
 * Tests if part of this DOMRect intersects any part of another DOMRect
 * @param {DOMRect} other 
 * @returns true if any part of this DOMRect intersects any part of the other DOMRect
 */
DOMRect.prototype.intersects = function (other) {
    return this.top >= other.top && this.top <= other.bottom && this.left >= other.left && this.left <= other.right;
}

/**
 * Converts this DOMRect from viewport coordinates to UV coordinates
 * @returns A new DOMRect in UV coordinates
 */
DOMRect.prototype.uv = function () {
    return new DOMRect(
        this.x / window.visualViewport.width,
        this.y / window.visualViewport.height,
        this.width / window.visualViewport.width,
        this.height / window.visualViewport.height
    );
}

/**
 * finds the center of this DOMRect
 * @returns A 0 width, 0 height DOMRect with x/y set to the center of this DOMRect
 */
DOMRect.prototype.center = function () {
    return new DOMRect(
        this.x + (this.width / 2),
        this.y + (this.height / 2),
        0,
        0
    );
}

/**
 * Sums the array
 * @returns sum as a Number
 */
Uint8Array.prototype.sum = function () {
    let result = 0;
    for (let i = 0; i < this.length; i++) { result += this[i]; }
    return result;
}

/**
 * Sums the array
 * @returns sum as a Number
 */
Uint8ClampedArray.prototype.sum = function () {
    let result = 0;
    for (let i = 0; i < this.length; i++) { result += this[i]; }
    return result;
}

/**
 * Sums the array
 * @returns sum as a Number
 */
Uint8ClampedArray.prototype.mean = function () {
    return this.sum() / Number(this.length);
}

/**
 * Sums the array
 * @returns sum as a Number
 */
Int16Array.prototype.sum = function () {
    let result = 0;
    for (let i = 0; i < this.length; i++) { result += this[i]; }
    return result;
}