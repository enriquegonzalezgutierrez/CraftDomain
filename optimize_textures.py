#!/usr/bin/env python3
# ==============================================================================
# Pathfile: ./optimize_textures.py
# Description: Script to automatically generate and optimize Godot 4.6.3 .import 
#              files for pixel-art and voxel textures. Enforces Lossless compression,
#              enables Mipmaps, and prevents VRAM distortion on alpha scissors (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================

import os

TEXTURES_DIR = "assets/textures"

# Godot 4 standard import configuration template for 3D Pixel Art / Voxel textures
IMPORT_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
compress/high_quality=true
compress/hdr_compression=1
compress/normal_map=0
compress/channel_remap=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""

def main():
    print("======================================================================")
    print("          CRAFTDOMAIN TEXTURE IMPORT CONFIGURATION OPTIMIZER          ")
    print("======================================================================")
    
    if not os.path.exists(TEXTURES_DIR):
        print(f"Error: Textures directory '{TEXTURES_DIR}' not found.")
        return

    optimized_count = 0
    for root, _, files in os.walk(TEXTURES_DIR):
        for file in files:
            if file.lower().endswith(".png"):
                png_path = os.path.join(root, file)
                import_path = png_path + ".import"
                
                # Write/Overwrite the .import configuration
                with open(import_path, "w", encoding="utf-8") as f:
                    f.write(IMPORT_TEMPLATE)
                    
                print(f" -> Optimized: {os.path.basename(png_path)}.import")
                optimized_count += 1

    print("----------------------------------------------------------------------")
    print(f"Success: Optimized {optimized_count} texture import files to Lossless + Mipmaps.")
    print("Please restart or focus your Godot Editor to trigger automatic reimport.")
    print("======================================================================\n")

if __name__ == "__main__":
    main()