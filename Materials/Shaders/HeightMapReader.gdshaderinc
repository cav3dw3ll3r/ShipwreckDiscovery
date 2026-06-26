// Function to modify a vertex's Y position based on the heightmap
vec3 Read_Heightmap(vec3 vertex_position, vec2 uv, sampler2D heightmap, float max_height) {
    // Sample the heightmap at the given UV coordinates
    float height = texture(heightmap, uv).r;

    // Scale the heightmap value and adjust the vertex's Y position
    vertex_position.y += height * max_height;

    // Return the modified vertex position
    return vertex_position;
}
