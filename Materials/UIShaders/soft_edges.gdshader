shader_type canvas_item;

uniform float edge_softness : hint_range(0.0, 0.5) = 0.1; // how far in the fade reaches from each edge

void fragment() {
    vec4 color = texture(TEXTURE, UV);

    // Fade per axis using distance from edges (UV ranges from 0 to 1)
    float left   = smoothstep(0.0, edge_softness, UV.x);
    float right  = smoothstep(1.0, 1.0 - edge_softness, UV.x);
    float top    = smoothstep(0.0, edge_softness, UV.y);
    float bottom = smoothstep(1.0, 1.0 - edge_softness, UV.y);

    // Combine fades — fade stronger near corners
    float fade = min(min(left, right), min(top, bottom));

    // Apply fade to alpha
    color.a *= fade;

    COLOR = color;
}
