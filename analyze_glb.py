#!/usr/bin/env python3
# ==============================================================================
# Project: CraftDomain - Asset Pipeline Tools
# Description: Advanced forensic glTF/GLB 2.0 metadata analyzer.
#              Extracts complete asset telemetry.
#              NEW IN V5:
#              - Z-Axis Geometric Asymmetry Scanner (detects forward/backward 
#                mesh flips and recommends 180° rotation offsets).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# Usage: python3 analyze_glb.py <path_to_file.glb>
# ==============================================================================
import sys
import os
import struct
import json
import math

def quat_to_euler_degrees(q):
    """
    Converts a glTF unit quaternion [x, y, z, w] to Euler angles in degrees (Roll, Pitch, Yaw).
    """
    x, y, z, w = q
    
    # Roll (X-axis)
    sinr_cosp = 2.0 * (w * x + y * z)
    cosr_cosp = 1.0 - 2.0 * (x * x + y * y)
    roll = math.atan2(sinr_cosp, cosr_cosp)
    
    # Pitch (Y-axis)
    sinp = 2.0 * (w * y - z * x)
    if abs(sinp) >= 1.0:
        pitch = math.copysign(math.pi / 2.0, sinp)
    else:
        pitch = math.asin(sinp)
        
    # Yaw (Z-axis)
    siny_cosp = 2.0 * (w * z + x * y)
    cosy_cosp = 1.0 - 2.0 * (y * y + z * z)
    yaw = math.atan2(siny_cosp, cosy_cosp)
    
    return math.degrees(roll), math.degrees(pitch), math.degrees(yaw)

def analyze_glb(file_path):
    if not os.path.exists(file_path):
        print(f"Error: File not found at '{file_path}'")
        return

    print(f"\n[GLB Analyzer] Opening asset: {os.path.basename(file_path)}")
    print("=" * 80)

    try:
        with open(file_path, "rb") as f:
            header = f.read(12)
            if len(header) < 12:
                print("Error: Invalid GLB header length.")
                return
                
            magic, version, length = struct.unpack("<III", header)
            if magic != 0x46546c67:
                print("Error: File is not a valid glTF/GLB binary file.")
                return
                
            print(f"Format: glTF Binary (GLB) | Version: {version} | Total Size: {length / (1024*1024):.2f} MB ({length} bytes)")

            chunk_header = f.read(8)
            if len(chunk_header) < 8:
                print("Error: Invalid JSON chunk header.")
                return
                
            chunk_length, chunk_type = struct.unpack("<II", chunk_header)
            if chunk_type != 0x4E4F534A:
                print("Error: First chunk is not JSON metadata.")
                return

            json_bytes = f.read(chunk_length)
            json_str = json_bytes.decode("utf-8")
            data = json.loads(json_str)

        # ----------------------------------------------------------------------
        # 1. EXTENSIONS & COMPATIBILITY
        # ----------------------------------------------------------------------
        print("\n⚙️ EXTENSIONS & COMPATIBILITY:")
        print("-" * 40)
        ext_used = data.get("extensionsUsed", [])
        ext_req = data.get("extensionsRequired", [])
        if ext_used:
            print("  Extensions Used:")
            for ext in ext_used:
                req_flag = " (REQUIRED)" if ext in ext_req else ""
                print(f"    -> {ext}{req_flag}")
        else:
            print("  (No specialized glTF extensions requested)")

        # ----------------------------------------------------------------------
        # 2. SCENE SUMMARY
        # ----------------------------------------------------------------------
        print("\n🌐 SCENE HIERARCHY SUMMARY:")
        print("-" * 40)
        scenes = data.get("scenes", [])
        active_scene = data.get("scene", 0)
        print(f"  Active Scene Index: {active_scene}")
        print(f"  Total Scenes:       {len(scenes)}")
        print(f"  Total Nodes:        {len(data.get('nodes', []))}")
        print(f"  Total Skins (Skeletons): {len(data.get('skins', []))}")

        # ----------------------------------------------------------------------
        # 3. SKELETAL SKINS (BONES)
        # ----------------------------------------------------------------------
        skins = data.get("skins", [])
        if skins:
            print("\n💀 SKELETAL SKIN REGISTRIES:")
            print("-" * 40)
            for i, skin in enumerate(skins):
                name = skin.get("name", "unnamed_skin")
                joints = skin.get("joints", [])
                print(f"  Skin [{i}] '{name}':")
                print(f"    -> Total Skeleton Joints: {len(joints)} bones")

        # ----------------------------------------------------------------------
        # 4. MODIFIED NODE HIERARCHY (Position, Scale, Rotation)
        # ----------------------------------------------------------------------
        print("\n🌳 NODE HIERARCHY (Offsets, Scales & Rotations):")
        print("-" * 40)
        nodes = data.get("nodes", [])
        modified_nodes_found = False
        for i, node in enumerate(nodes):
            name = node.get("name", f"Node_{i}")
            scale = node.get("scale")
            translation = node.get("translation")
            rotation = node.get("rotation") # glTF unit quaternion: [x, y, z, w]
            mesh_idx = node.get("mesh")
            skin_idx = node.get("skin")
            
            if scale or translation or rotation or mesh_idx is not None or skin_idx is not None:
                print(f"  Node [{i}] '{name}':")
                if translation:
                    print(f"    -> Position Offset: {translation}")
                if scale:
                    print(f"    -> Local Scale:     {scale}")
                if rotation:
                    rx, ry, rz = quat_to_euler_degrees(rotation)
                    print(f"    -> Rotation Euler:  [X: {rx:0.2f}°, Y: {ry:0.2f}°, Z: {rz:0.2f}°]")
                if mesh_idx is not None:
                    print(f"    -> Attached Mesh:   Index {mesh_idx}")
                if skin_idx is not None:
                    print(f"    -> Attached Skin:   Index {skin_idx}")
                modified_nodes_found = True
                
        if not modified_nodes_found:
            print("  (All nodes are at default 1x1x1 scale, origin 0,0,0, and 0° rotation)")

        # ----------------------------------------------------------------------
        # 5. DETAILED MESH & GEOMETRY METRICS (Asymmetry Scanner)
        # ----------------------------------------------------------------------
        print("\n📐 MESH & GEOMETRY METRICS (POLYGON BUDGETS):")
        print("-" * 40)
        accessors = data.get("accessors", [])
        meshes = data.get("meshes", [])
        
        # Track global combined boundaries
        glob_min_x, glob_min_y, glob_min_z = 999999.0, 999999.0, 999999.0
        glob_max_x, glob_max_y, glob_max_z = -999999.0, -999999.0, -999999.0
        
        if meshes:
            for mesh_idx, mesh in enumerate(meshes):
                mesh_name = mesh.get("name", "unnamed_mesh")
                print(f"  Mesh [{mesh_idx}] '{mesh_name}':")
                
                for prim_idx, primitive in enumerate(mesh.get("primitives", [])):
                    attrs = primitive.get("attributes", {})
                    pos_accessor_idx = attrs.get("POSITION")
                    indices_accessor_idx = primitive.get("indices")
                    
                    vertices_count = 0
                    triangles_count = 0
                    
                    if pos_accessor_idx is not None and pos_accessor_idx < len(accessors):
                        acc = accessors[pos_accessor_idx]
                        vertices_count = acc.get("count", 0)
                        min_vals = acc.get("min", [0.0, 0.0, 0.0])
                        max_vals = acc.get("max", [0.0, 0.0, 0.0])
                        
                        # Update global boundaries
                        glob_min_x = min(glob_min_x, min_vals[0])
                        glob_min_y = min(glob_min_y, min_vals[1])
                        glob_min_z = min(glob_min_z, min_vals[2])
                        glob_max_x = max(glob_max_x, max_vals[0])
                        glob_max_y = max(glob_max_y, max_vals[1])
                        glob_max_z = max(glob_max_z, max_vals[2])
                        
                        width = max_vals[0] - min_vals[0]
                        height = max_vals[1] - min_vals[1]
                        depth = max_vals[2] - min_vals[2]
                        print(f"    * Primitive Boundaries:")
                        print(f"      -> Min Vertex: {min_vals}")
                        print(f"      -> Max Vertex: {max_vals}")
                        print(f"      -> Dimensions: Width={width:.3f} | Height={height:.3f} | Depth={depth:.3f}")
                        
                        # Predictive Orientation Heuristic
                        if width > 0 and depth > 0:
                            ratio = width / depth
                            if ratio < 0.85:
                                print("    ⚠️  [ORIENTATION WARNING] Depth (Z) is significantly larger than Width (X).")
                                print("                              For standard humanoid models facing forward, Width (shoulders) should be larger.")
                                print("                              -> This model is likely baked facing SIDEWAYS (Left or Right).")
                                print("                              -> Recommended Fix: Set model_node.rotation_degrees.y = -90 (or 90) in Godot.")
                                print("                              -> If this is a QUADRUPED (Cat, Dog, Raccoon): This is normal, do NOT rotate sideways!")

                    mode = primitive.get("mode", 4)
                    
                    if indices_accessor_idx is not None and indices_accessor_idx < len(accessors):
                        indices_count = accessors[indices_accessor_idx].get("count", 0)
                        if mode == 4:
                            triangles_count = indices_count // 3
                        elif mode == 5:
                            triangles_count = max(0, indices_count - 2)
                    else:
                        if mode == 4:
                            triangles_count = vertices_count // 3
                            
                    print(f"    Primitive [{prim_idx}]:")
                    print(f"      -> Render Mode:    {mode} (Triangles: {triangles_count} | Vertices: {vertices_count})")
                    print(f"      -> Attributes:     {list(attrs.keys())}")
        else:
            print("  (No static mesh data defined)")

        # ----------------------------------------------------------------------
        # 6. GLOBAL BOUNDS & ENG COMPENSATIONS (Asymmetry Scanner)
        # ----------------------------------------------------------------------
        print("\n📦 GLOBAL BOUNDING BOX & DYNAMIC ENGINE CALIBRATION:")
        print("-" * 40)
        if glob_min_y < 999999.0:
            glob_width = glob_max_x - glob_min_x
            glob_height = glob_max_y - glob_min_y
            glob_depth = glob_max_z - glob_min_z
            
            print(f"  Absolute Combined Min Vertex: [{glob_min_x:0.3f}, {glob_min_y:0.3f}, {glob_min_z:0.3f}]")
            print(f"  Absolute Combined Max Vertex: [{glob_max_x:0.3f}, {glob_max_y:0.3f}, {glob_max_z:0.3f}]")
            print(f"  Absolute Combined Size:       Width={glob_width:0.3f} | Height={glob_height:0.3f} | Depth={glob_depth:0.3f}")
            
            # 1. Predictive Orientation Heuristic
            if glob_width > 0 and glob_depth > 0:
                ratio = glob_width / glob_depth
                print(f"  Aspect Ratio (Width/Depth):   {ratio:0.3f}")
                if ratio < 0.85:
                    print("  ⚠️  [ORIENTATION WARNING] Depth (Z) is significantly larger than Width (X).")
                    print("                            -> If this is a HUMANOID/ZOMBIE: Mesh is likely baked facing SIDEWAYS.")
                    print("                            -> Fix: Set model_node.rotation_degrees.y = -90 (or 90) in Godot.")
                    print("                            -> If this is a QUADRUPED (Cat, Dog, Raccoon): This is normal, do NOT rotate sideways!")
            
            # ==================================================================
            # 2. Z-AXIS GEOMETRIC ASYMMETRY SCANNER (NEW V5)
            # ==================================================================
            abs_min_z = abs(glob_min_z)
            abs_max_z = abs(glob_max_z)
            if abs_min_z > 0.01 and abs_max_z > 0.01:
                asymmetry_z = abs_min_z / abs_max_z
                if asymmetry_z > 2.0 or asymmetry_z < 0.5:
                    print(f"  ⚠️  [Z-AXIS ASYMMETRY ALERT] Shift ratio: {asymmetry_z:0.3f} (Min-Z: {glob_min_z:0.3f} | Max-Z: {glob_max_z:0.3f})")
                    print("                               -> The pivot is heavily offset toward one end on the Z-axis.")
                    print("                               -> If this model moves BACKWARDS while chasing in-game:")
                    print("                                  Fix: Set model_node.rotation_degrees.y = 180 in Godot.")
            # ==================================================================
            
            # AUTOMATED SUGESTED OFFSET TABLE
            print("\n  📐 SUGGESTED GODOT OFFSETS FOR TARGET HEIGHTS:")
            targets = {
                "Humanoid / Zombie (1.8m)": 1.8,
                "Medium Mob (0.75m)": 0.75,
                "Small Pet / Bird (0.35m)": 0.35,
                "Colossal Giant / Boss (3.5m)": 3.5
            }
            
            for label, target_h in targets.items():
                scale_factor = target_h / glob_height
                scaled_min_y = glob_min_y * scale_factor
                pos_y_offset = -scaled_min_y
                
                print(f"    * {label}:")
                print(f"      -> Scale multiplier: Vector3({scale_factor:0.4f}, {scale_factor:0.4f}, {scale_factor:0.4f})")
                print(f"      -> Position Y Offset: position.y = {pos_y_offset:0.4f}")
        else:
            print("  (No geometry bounds calculated)")

        # ----------------------------------------------------------------------
        # 7. PBR MATERIAL SPECIFICATIONS
        # ----------------------------------------------------------------------
        print("\n🎨 PBR MATERIAL SPECIFICATIONS:")
        print("-" * 40)
        materials = data.get("materials", [])
        if materials:
            for i, mat in enumerate(materials):
                print(f"  Material [{i}] '{mat.get('name', 'unnamed')}':")
                pbr = mat.get("pbrMetallicRoughness", {})
                base_color = pbr.get("baseColorFactor", [1.0, 1.0, 1.0, 1.0])
                metallic = pbr.get("metallicFactor", 1.0)
                roughness = pbr.get("roughnessFactor", 1.0)
                
                print(f"    -> Base Color (RGBA):  {base_color}")
                print(f"    -> Roughness Factor:   {roughness}")
                print(f"    -> Metallic Factor:    {metallic}")
                
                maps = []
                if "baseColorTexture" in pbr: maps.append("Base Color Map")
                if "metallicRoughnessTexture" in pbr: maps.append("Metallic/Roughness Map")
                if "normalTexture" in mat: maps.append("Normal Map")
                if "occlusionTexture" in mat: maps.append("Occlusion Map")
                if "emissiveTexture" in mat: maps.append("Emissive Map")
                
                if maps:
                    print(f"    -> Configured Maps:    {maps}")
                
                emissive = mat.get("emissiveFactor", [0.0, 0.0, 0.0])
                if sum(emissive) > 0.0:
                    print(f"    -> Emissive Multiplier: {emissive}")
                    
                alpha_mode = mat.get("alphaMode", "OPAQUE")
                if alpha_mode != "OPAQUE":
                    print(f"    -> Transparency Mode:   {alpha_mode} (Cutoff: {mat.get('alphaCutoff', 0.5)})")
                    
                if mat.get("doubleSided", False):
                    print(f"    -> Double Sided Mesh:  True")
        else:
            print("  (No materials defined)")

        # ----------------------------------------------------------------------
        # 8. EMBEDDED IMAGES & TEXTURES
        # ----------------------------------------------------------------------
        print("\n🖼️ EMBEDDED IMAGES & TEXTURES:")
        print("-" * 40)
        images = data.get("images", [])
        buffer_views = data.get("bufferViews", [])
        if images:
            for i, img in enumerate(images):
                name = img.get("name", "unnamed_image")
                mime = img.get("mimeType", "unknown")
                bv_idx = img.get("bufferView")
                
                size_str = "Size: External URI reference"
                if bv_idx is not None and bv_idx < len(buffer_views):
                    bv = buffer_views[bv_idx]
                    byte_len = bv.get("byteLength", 0)
                    size_str = f"Size: {byte_len / 1024.0:.2f} KB ({byte_len} bytes)"
                    
                print(f"  Image [{i}] '{name}':")
                print(f"    -> Format/Mime: {mime} | {size_str}")
        else:
            print("  (No embedded images or textures discovered)")
            
    except Exception as e:
        print(f"Error parsing metadata: {str(e)}")
    print("=" * 80 + "\n")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_glb.py <path_to_file.glb>")
    else:
        analyze_glb(sys.argv[1])