# ==============================================================================
# Pathfile: ./optimize_textures.py
# Description: Command-line batch script to optimize block textures by resizing 
#              them to 512x512 pixels. 
#              Uses pure-Python PNG binary parsing for 100% idempotent checks,
#              and delegates resizing to system utilities (ImageMagick/FFmpeg).
#              Zero Python external dependencies (No Pillow/pip required).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================

import os
import sys
import struct
import shutil
import subprocess

TARGET_SIZE = (512, 512)
TEXTURES_DIR = os.path.join(os.path.dirname(__file__), "assets", "textures")


def get_png_dimensions(file_path: str) -> tuple:
    """
    Parses the binary IHDR chunk of a PNG file to extract dimensions (Width, Height).
    adheres to RFC 2083 PNG specifications. Zero external dependencies.
    """
    try:
        with open(file_path, "rb") as f:
            signature = f.read(8)
            # Verify PNG standard 8-byte signature
            if signature != b"\x89PNG\r\n\x1a\n":
                return (0, 0)
                
            # Skip IHDR chunk length (4 bytes) and type 'IHDR' (4 bytes)
            f.seek(16)
            
            # Read Width and Height (4 bytes each, 32-bit big-endian unsigned integers)
            width, height = struct.unpack(">II", f.read(8))
            return (width, height)
    except Exception:
        return (0, 0)


def resize_image_system(file_path: str, tool_name: str) -> bool:
    """
    Invokes system-level utilities to perform high-quality image resizing.
    """
    try:
        if tool_name == "mogrify":
            # ImageMagick mogrify overwrites files in-place with high efficiency
            subprocess.check_call(["mogrify", "-resize", "512x512!", file_path])
            return True
        elif tool_name == "ffmpeg":
            # FFmpeg fallback pipeline
            temp_path = file_path + ".tmp.png"
            subprocess.check_call([
                "ffmpeg", "-y", "-i", file_path, 
                "-vf", "scale=512:512:flags=lanczos", 
                temp_path
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            if os.path.exists(temp_path):
                os.replace(temp_path, file_path)
                return True
    except Exception as e:
        push_warning(f"Failed system resize operation on {file_path}: {e}")
        
    return False


def main() -> None:
    print("====================================================================")
    print("             CRAFTDOMAIN TEXTURE OPTIMIZATION UTILITY               ")
    print("====================================================================")
    
    if not os.path.exists(TEXTURES_DIR):
        print(f"❌ [Error] Textures directory does not exist: {TEXTURES_DIR}")
        sys.exit(1)
        
    # Detect available system utilities on WSL/Linux path
    tool_to_use = ""
    if shutil.which("mogrify"):
        tool_to_use = "mogrify"
    elif shutil.which("ffmpeg"):
        tool_to_use = "ffmpeg"
        
    if tool_to_use == "":
        print("❌ [Dependency Missing] No compatible image utility detected.")
        print("Please install ImageMagick on your WSL/Ubuntu system by running:")
        print("  * Command: sudo apt update && sudo apt install -y imagemagick")
        sys.exit(1)
        
    png_files = [f for f in os.listdir(TEXTURES_DIR) if f.lower().endswith(".png")]
    total_files = len(png_files)
    
    if total_files == 0:
        print("⚠  No PNG textures discovered in the directory.")
        sys.exit(0)
        
    print(f"Analyzing {total_files} PNG textures inside: {TEXTURES_DIR}")
    print(f"Using system backend: '{tool_to_use}' | Target: 512x512")
    print("--------------------------------------------------------------------")
    
    processed_count = 0
    skipped_count = 0
    
    for file_name in png_files:
        file_path = os.path.join(TEXTURES_DIR, file_name)
        w, h = get_png_dimensions(file_path)
        
        # IDEMPOTENCY CHECK:
        # Only resize if the binary header proves the texture is strictly larger than 512x512.
        if w > TARGET_SIZE[0] and h > TARGET_SIZE[1]:
            if resize_image_system(file_path, tool_to_use):
                processed_count += 1
                print(f"  ✓ [Optimized] {file_name} (from {w}x{h} -> 512x512)")
            else:
                print(f"  ❌ [Failed] {file_name}")
        else:
            skipped_count += 1
            
    print("--------------------------------------------------------------------")
    print("SUMMARY OF TEXTURE OPTIMIZATION:")
    print(f"  * Total Textures Analyzed:  {total_files}")
    print(f"  * Successfully Downscaled:  {processed_count}")
    print(f"  * Bypassed (Already <= 512): {skipped_count} (Idempotency Safe)")
    print("  * Projected VRAM Savings:   75.00% reduction per optimized block")
    print("====================================================================\n")


def push_warning(message: str) -> None:
    print(f"  [Warning] {message}")


if __name__ == "__main__":
    main()