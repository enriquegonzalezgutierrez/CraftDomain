#!/usr/bin/env python3
# ==============================================================================
# Project: CraftDomain - Asset Pipeline Tools
# Description: Advanced clean GLB/glTF 2.0 metadata analyzer.
#              Removes duplicate vertex metrics and extracts node-level scale 
#              hierarchies to resolve Godot/Blender scaling issues.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# Usage: python3 analyze_glb.py <path_to_file.glb>
# ==============================================================================
import sys
import os
import struct
import json

def analyze_glb(file_path):
    if not os.path.exists(file_path):
        print(f"Error: File not found at '{file_path}'")
        return

    print(f"\n[GLB Analyzer] Opening asset: {os.path.basename(file_path)}")
    print("=" * 60)

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
                
            print(f"Format: glTF Binary (GLB) | Version: {version} | Total Size: {length} bytes")

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

        # 1. Animations Extraction
        print("\n🎬 ANIMATIONS DISCOVERED:")
        print("-" * 30)
        animations = data.get("animations", [])
        if animations:
            for i, anim in enumerate(animations):
                print(f"  [{i}] Name: \"{anim.get('name', 'unnamed')}\"")
        else:
            print("  (No skeletal animations found inside this model)")

        # 2. Node Hierarchy Scale Analysis (Crucial for Blender export bugs)
        print("\n🌳 NODE HIERARCHY SCALES (Blender/Godot Multipliers):")
        print("-" * 30)
        nodes = data.get("nodes", [])
        scaled_nodes_found = False
        for i, node in enumerate(nodes):
            name = node.get("name", f"Node_{i}")
            scale = node.get("scale")
            translation = node.get("translation")
            
            # Print if node has custom scale or transformation
            if scale is not None or translation is not None:
                scale_str = f"Scale: {scale}" if scale else "Scale: [1, 1, 1] (Default)"
                trans_str = f"Translation: {translation}" if translation else ""
                print(f"  Node [{i}] '{name}' -> {scale_str} | {trans_str}")
                scaled_nodes_found = True
                
        if not scaled_nodes_found:
            print("  (All nodes are at default 1x1x1 scale)")

        # 3. MESHES & BOUNDING BOXES (Clutter-Free, No Duplicates)
        print("\n📐 UNIQUE MESH BOUNDARIES:")
        print("-" * 30)
        accessors = data.get("accessors", [])
        meshes = data.get("meshes", [])
        
        printed_boundaries = set() # Avoid duplications
        
        if meshes:
            for mesh in meshes:
                mesh_name = mesh.get("name", "unnamed_mesh")
                for primitive in mesh.get("primitives", []):
                    pos_accessor_idx = primitive.get("attributes", {}).get("POSITION")
                    if pos_accessor_idx is not None and pos_accessor_idx < len(accessors):
                        acc = accessors[pos_accessor_idx]
                        min_vals = acc.get("min", [0.0, 0.0, 0.0])
                        max_vals = acc.get("max", [0.0, 0.0, 0.0])
                        
                        # Generate unique key for this boundary
                        boundary_key = f"{min_vals}_{max_vals}"
                        if boundary_key in printed_boundaries:
                            continue
                        printed_boundaries.add(boundary_key)
                        
                        width = max_vals[0] - min_vals[0]
                        height = max_vals[1] - min_vals[1]
                        depth = max_vals[2] - min_vals[2]
                        
                        print(f"  Mesh: '{mesh_name}'")
                        print(f"    -> Min Vertex: {min_vals}")
                        print(f"    -> Max Vertex: {max_vals}")
                        print(f"    -> Real Size: Width={width:.3f} | Height={height:.3f} | Depth={depth:.3f}")
        else:
            print("  (No static mesh data defined)")

        # 4. Materials Extraction
        print("\n🎨 UNIQUE MATERIALS:")
        print("-" * 30)
        materials = data.get("materials", [])
        if materials:
            for i, mat in enumerate(materials):
                print(f"  [{i}] Material Name: '{mat.get('name', 'unnamed')}'")
        else:
            print("  (No materials defined)")
            
    except Exception as e:
        print(f"Error parsing metadata: {str(e)}")
    print("=" * 60 + "\n")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_glb.py <path_to_file.glb>")
    else:
        analyze_glb(sys.argv[1])