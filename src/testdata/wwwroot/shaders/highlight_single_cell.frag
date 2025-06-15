vec3 base_color = vec3(255,255,0);

void mainImage(out vec4 fragColor, in vec2 fragCoord ){
    vec2 uv = fragCoord/iResolution.xy;// Normalized pixel coordinates (from 0 to 1)
    vec2 muv = iMouse.xy/iResolution.xy;// Mouse coordinates in uv space
    vec2 cuv = floor(uv * vec2(9)); // Normalized pixel coordinates in cell space
    vec2 cmuv = floor(muv * vec2(9));// Mouse coordinates in cell space
    bvec2 cell_contains_pixel_2d = equal(cuv, cmuv);
    bool cell_contains_pixel = cell_contains_pixel_2d.x && cell_contains_pixel_2d.y;
    fragColor = vec4(base_color * vec3(cell_contains_pixel),1);
}