class sfc32 {
    static generateSeed() {
        const seed = new Uint32Array(4);
        seed[0] = (Math.random() * 2 ** 32) >>> 0;
        seed[1] = (Math.random() * 2 ** 32) >>> 0;
        seed[2] = (Math.random() * 2 ** 32) >>> 0;
        seed[3] = (Math.random() * 2 ** 32) >>> 0;
        return seed;
    }

    reset(seed) {
        if (!(seed instanceof Uint32Array)) { throw new TypeError("seed was not an instance of Uint32Array") }
        if (seed.length !== 4) { throw new TypeError(`Expected seed.length = 4, but found: ${seed.length}`) }
        this.count = 0;
        this.seed = new Uint32Array(4);
        this.state = new Uint32Array(4);
        for (let i = 0; i < 4; i++) {
            this.seed[i] = seed[i];
            this.state[i] = seed[i];
        }
    }

    /**
     * Creates a new sfc32 prng using the specified seed
     * @param {Uint32Array} seed 
     */
    constructor(seed) {
        this.reset(seed);
    }

    /**
     * 
     * @returns Random integer between 0 and 2^32
     */
    nextInt() {
        let tmp_buf = new ArrayBuffer(4);
        let temp_u32 = new Uint32Array(tmp_buf);
        temp_u32[0] = this.state[0] + this.state[1] + this.state[3]
        this.state[3] = this.state[3] + 1;
        this.state[0] = this.state[1] ^ (this.state[1] >>> 9);
        this.state[1] = this.state[2] + (this.state[2] << 3);
        this.state[2] = (this.state[2] << 21 | this.state[2] >>> 11);
        this.state[2] = this.state[2] + temp_u32[0];
        temp_u32[0] = temp_u32[0] >>> 0;

        this.count += 1;
        return temp_u32[0];
    }

    /**
     * 
     * @returns Random float between 0.0 and 1.0
     */
    nextFloat() {
        return this.nextInt() / 4294967296;
    }
}