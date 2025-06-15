class PointerData {
    /**time (in milliseconds) at which the event was created. */
    timeStamp = -1;
    /**Event type */
    type = "";
    /**The X coordinate of the pointer in viewport coordinates. */
    clientX = -1;
    /**The Y coordinate of the pointer in viewport coordinates. */
    clientY = -1;
    /**The X coordinate of the pointer relative to the position of the padding edge of the target node. */
    offsetX = -1;
    /**The Y coordinate of the pointer relative to the position of the padding edge of the target node. */
    offsetY = -1;
    /**The X coordinate of the pointer relative to the whole document. */
    pageX = -1;
    /**The X coordinate of the pointer relative to the whole document. */
    pageY = -1;
    /**The X coordinate of the pointer in screen coordinates. */
    screenX = -1;
    /**The X coordinate of the pointer in screen coordinates. */
    screenY = -1;
    /**The X coordinate of the pointer relative to the position of the last move event. */
    movementX = -1;
    /**The Y coordinate of the pointer relative to the position of the last move event. */
    movementY = -1;
    /**The width (magnitude on the X axis); in CSS pixels; of the contact geometry of the pointer. */
    width = -1;
    /**The height (magnitude on the Y axis); in CSS pixels; of the contact geometry of the pointer. */
    height = -1;
    /**Represents the angle between a transducer (a pointer or stylus) axis and the X-Y plane of a device screen. */
    altitudeAngle = -1;
    /**Represents the angle between the Y-Z plane and the plane containing both the transducer (a pointer or stylus) axis and the Y axis. */
    azimuthAngle = -1;
    /**The button number that was pressed or released (if applicable) when the mouse event was fired. */
    button = -1;
    /**The buttons being pressed (if any) when the event was fired. */
    buttons = -1;
    /**Normalized pressure of the pointer input in the range of 0 to 1; where 0 and 1 represent the minimum and maximum pressure the hardware is capable of detecting; respectively. */
    pressure = -1;
    /**Normalized tangential pressure of the pointer input (also known as barrel pressure or cylinder stress) in the range -1 to 1; where 0 is the neutral position of the control. */
    tangentialPressure = -1;
    /**Plane angle (in degrees; in the range of -90 to 90) between the Y–Z plane and the plane containing both the pointer (e.g.; pen stylus) axis and the Y axis. */
    tiltX = -1;
    /**Plane angle (in degrees; in the range of -90 to 90) between the X–Z plane and the plane containing both the pointer (e.g.; pen stylus) axis and the X axis. */
    tiltY = -1;
    /**A unique identifier for the pointing device generating the PointerEvent. */
    persistentDeviceId = -1;
    /**A unique identifier for the pointer causing the event. */
    pointerId = -1;
    /**Indicates the device type that caused the event (mouse; pen; touch; etc.). */
    pointerType = "";
    /**Indicates if the pointer represents the primary pointer of this pointer type. */
    isPrimary = false;

    bounds = new DOMRect();

    uv_bounds = new DOMRect();
    /**
     * Updates this PointerData with never data.
     * @param {*} event 
     * @returns true if event was newer than this, otherwise false
     */
    update(event) {
        // if (!(event instanceof PointerEvent)) { throw Error("Can only update from PointerEvents"); }
        if (event.timeStamp <= this.timeStamp) { return false; }
        this.isPrimary = event.isPrimary;
        this.altitudeAngle = event.altitudeAngle;
        this.azimuthAngle = event.azimuthAngle;
        this.button = event.button;
        this.buttons = event.buttons;
        this.clientX = event.clientX;
        this.clientY = event.clientY;
        this.height = event.height;
        this.movementX = event.movementX;
        this.movementY = event.movementY;
        this.offsetX = event.offsetX;
        this.offsetY = event.offsetY;
        this.pageX = event.pageX;
        this.pageY = event.pageY;
        this.persistentDeviceId = event.persistentDeviceId;
        this.pointerId = event.pointerId;
        this.pressure = event.pressure;
        this.screenX = event.screenX;
        this.screenY = event.screenY;
        this.tangentialPressure = event.tangentialPressure;
        this.tiltX = event.tiltX;
        this.tiltY = event.tiltY;
        this.timeStamp = event.timeStamp;
        this.width = event.width;
        this.pointerType = event.pointerType;
        this.type = event.type;

        this.bounds.y = event.clientY;
        this.bounds.x = event.clientX;
        this.bounds.width = event.width;
        this.bounds.height = event.height;

        return true;
    }
    constructor() { }
}

