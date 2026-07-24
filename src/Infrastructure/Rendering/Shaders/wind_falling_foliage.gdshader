// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/wind_falling_foliage.gdshader
// Description: Wind-driven falling foliage particle process shader.
//              Simulates organic leaf/petal tumbling, gravity drift, and 
//              synchronizes with global wind vectors from WeatherService.
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
// ==============================================================================
shader_type particles;

// --- GLOBAL UNIFORMS (Synchronized with WeatherService) ---
global uniform vec2 wind_vector;
global uniform float wind_strength;
global uniform vec2 wind_offset;

// --- EMITTER & COLOR CONTROLS ---
uniform vec4 particle_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3 box_emit_size = vec3(16.0, 4.0, 16.0);
uniform float initial_rotation_xz = 0.5;
uniform float fade_from : hint_range(0.0, 1.0) = 0.85;

// --- SPEED & DAMPING PARAMETERS ---
uniform float forward_speed_min = 2.0;
uniform float forward_speed_max = 6.0;
uniform vec2 rot_speed_x = vec2(0.2, 0.8);
uniform vec2 rot_speed_y = vec2(1.0, 2.5);
uniform vec2 rot_speed_z = vec2(0.8, 2.0);
uniform float vel_damping = 0.45;

// --- ENVIRONMENT PHYSICS ---
uniform vec3 gravity_vector = vec3(0.0, -3.2, 0.0);

// --- RANDOM SEED GENERATORS ---
uint hash(uint x) {
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = (x >> uint(16)) ^ x;
	return x;
}

float rand_from_seed(inout uint seed) {
	int s = int(seed);
	if (s == 0) {
		s = 305420679;
	}
	int k = s / 127773;
	s = 16807 * (s - k * 127773) - 2836 * k;
	if (s < 0) {
		s += 2147483647;
	}
	seed = uint(s);
	return float(seed % uint(65536)) / 65535.0;
}

mat3 rot_x_matrix(float angle) {
	float cx = cos(angle);
	float sx = sin(angle);
	return mat3(
		vec3(1.0, 0.0, 0.0),
		vec3(0.0, cx, -sx),
		vec3(0.0, sx,  cx)
	);
}

mat3 rot_y_matrix(float angle) {
	float cy = cos(angle);
	float sy = sin(angle);
	return mat3(
		vec3( cy, 0.0, sy),
		vec3(0.0, 1.0, 0.0),
		vec3(-sy, 0.0, cy)
	);	
}

mat3 rot_z_matrix(float angle) {
	float cz = cos(angle);
	float sz = sin(angle);
	return mat3(
		vec3(cz, -sz, 0.0),
		vec3(sz,  cz, 0.0),
		vec3(0.0, 0.0, 1.0)
	);
}

void start() {
	uint base_number = NUMBER;
	uint alt_seed = hash(base_number + uint(1) + RANDOM_SEED);

	if (RESTART_ROT_SCALE) {
		TRANSFORM[0].xyz = vec3(1.0, 0.0, 0.0);
		TRANSFORM[1].xyz = vec3(0.0, 1.0, 0.0);
		TRANSFORM[2].xyz = vec3(0.0, 0.0, 1.0);
		
		float angle_y = rand_from_seed(alt_seed) * TAU;
		float angle_x = (rand_from_seed(alt_seed) - 0.5) * 2.0 * initial_rotation_xz;
		float angle_z = (rand_from_seed(alt_seed) - 0.5) * 2.0 * initial_rotation_xz;		

		mat3 rot_x = rot_x_matrix(angle_x);
		mat3 rot_y = rot_y_matrix(angle_y);
		mat3 rot_z = rot_z_matrix(angle_z);
		mat3 rot = rot_y * rot_x * rot_z;

		TRANSFORM[0].xyz = rot * TRANSFORM[0].xyz;
		TRANSFORM[1].xyz = rot * TRANSFORM[1].xyz;
		TRANSFORM[2].xyz = rot * TRANSFORM[2].xyz;
				
		USERDATA1 = vec4(0.0);
		USERDATA1.x = 0.0; 		
		USERDATA1.y = rand_from_seed(alt_seed); 
		USERDATA1.z = rot_speed_x.x + (rot_speed_x.y - rot_speed_x.x) * rand_from_seed(alt_seed); 
		USERDATA1.w = step(0.5, rand_from_seed(alt_seed)) * 2.0 - 1.0; 		
		
		USERDATA2 = vec4(0.0);
		USERDATA2.x = rot_speed_y.x + (rot_speed_y.y - rot_speed_y.x) * rand_from_seed(alt_seed); 
		USERDATA2.y = step(0.5, rand_from_seed(alt_seed)) * 2.0 - 1.0; 
		USERDATA2.z = rot_speed_z.x + (rot_speed_z.y - rot_speed_z.x) * rand_from_seed(alt_seed); 
		USERDATA2.w = step(0.5, rand_from_seed(alt_seed)) * 2.0 - 1.0; 		
	}
	
	if (RESTART_POSITION) {
		float x = (rand_from_seed(alt_seed) - 0.5) * box_emit_size.x;
		float y = (rand_from_seed(alt_seed) - 0.5) * box_emit_size.y;
		float z = (rand_from_seed(alt_seed) - 0.5) * box_emit_size.z;		
		TRANSFORM[3].xyz = vec3(x, y, z);
		TRANSFORM = EMISSION_TRANSFORM * TRANSFORM; 
	}	

	if (RESTART_COLOR) {
		COLOR = particle_color;	
	}	
			
	if (RESTART_VELOCITY) {
		VELOCITY = vec3(0.0);	
	}			
}

void process() {
	USERDATA1.x += DELTA;
	float particle_normalized_time = clamp(USERDATA1.x / LIFETIME, 0.0, 1.0);
			
	// Calculate active wind velocity vector directly from global weather uniforms
	vec2 w_dir = length(wind_vector) > 0.01 ? normalize(wind_vector) : vec2(0.8, 0.2);
	float active_wind_speed = max(0.2, wind_strength) * 8.0;
	vec3 active_wind_3d = vec3(w_dir.x, -0.1, w_dir.y) * active_wind_speed;
	
	float current_forward_speed_var = (sin(TIME + (USERDATA1.y * 10.0)) + 1.0) * 0.5;
	float current_forward_speed = mix(forward_speed_min, forward_speed_max, current_forward_speed_var);
			
	// Apply combined forces: Gravity + Leaf Flutter + Global Wind
	VELOCITY = gravity_vector * DELTA;
	VELOCITY += normalize(-TRANSFORM[2].xyz) * DELTA * current_forward_speed;	
	VELOCITY += active_wind_3d * DELTA;
	VELOCITY *= (1.0 - vel_damping * DELTA);

	// 3D Tumbling Rotations
	float current_rotation_x_var = 1.0 - clamp(current_forward_speed_var, 0.0, 1.0);
	mat3 rot_x = rot_x_matrix(USERDATA1.z * USERDATA1.w * DELTA * current_rotation_x_var);
	mat3 rot_y = rot_y_matrix(USERDATA2.x * USERDATA2.y * DELTA * current_rotation_x_var);
	
	float current_rotation_z_var = clamp(current_forward_speed_var, 0.0, 1.0);
	mat3 rot_z = rot_z_matrix(USERDATA2.z * USERDATA2.w * DELTA * current_rotation_z_var);
		
	mat3 rot = rot_y * rot_x * rot_z;
	TRANSFORM[0].xyz = rot * TRANSFORM[0].xyz;
	TRANSFORM[1].xyz = rot * TRANSFORM[1].xyz;
	TRANSFORM[2].xyz = rot * TRANSFORM[2].xyz;	
	
	// Smooth alpha fade out towards end of lifespan
	COLOR.a = 1.0 - smoothstep(fade_from, 1.0, particle_normalized_time);	
}