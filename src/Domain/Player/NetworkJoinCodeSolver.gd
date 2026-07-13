# ==============================================================================
# Pathfile: res://src/Domain/Player/NetworkJoinCodeSolver.gd
# Description: Pure Domain solver calculating and translating absolute network
#              coordinates (IP/Port) into obfuscated alphanumeric Join Codes (DIP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NetworkJoinCodeSolver
extends RefCounted

# Masking configurations to prevent raw IP scraping and ensure privacy (Section 5.3)
const OBFUSCATION_SALT: int = 0x5A8C3D9F
const PREFIX_CODE: String = "CD-"


## Encodes a public IPv4 address and port into a friendly alphanumeric Join Code.
## Decoupled from disk or UI, operating purely on mathematical translations.
static func encode_ip_and_port(ip_address: String, port_val: int) -> String:
	var ip_parts := ip_address.split(".")
	if ip_parts.size() != 4:
		return "" # Invalid IPv4 format
		
	# 1. Pack the 4 bytes of the IP into a single 32-bit integer
	var ip_packed := 0
	for i in range(4):
		var byte_val := ip_parts[i].to_int()
		ip_packed = (ip_packed << 8) | (byte_val & 0xFF)
		
	# 2. Obfuscate the packed IP and port using logical XOR and bit shifts
	var packed_coordinates: int = (ip_packed ^ OBFUSCATION_SALT)
	var packed_port: int = (port_val ^ (OBFUSCATION_SALT & 0xFFFF))
	
	# 3. Format as a hexadecimal alphanumeric string representation
	var hex_ip := "%08X" % packed_coordinates
	var hex_port := "%04X" % packed_port
	
	return PREFIX_CODE + hex_ip + "-" + hex_port


## Decodes an alphanumeric Join Code back into its absolute IPv4 address and port.
## Returns a Dictionary containing "ip" (String) and "port" (int), or empty if corrupt.
static func decode_to_ip_and_port(join_code: String) -> Dictionary:
	var sanitized := join_code.strip_edges().to_upper()
	if not sanitized.begins_with(PREFIX_CODE):
		return {} # Corrupt or unaligned prefix
		
	var payload := sanitized.replace(PREFIX_CODE, "")
	var parts := payload.split("-")
	if parts.size() != 2:
		return {} # Invalid segment structure
		
	var hex_ip := parts[0] as String
	var hex_port := parts[1] as String
	if hex_ip.length() != 8 or hex_port.length() != 4:
		return {}
		
	# 1. Reverse XOR obfuscation and unpack 32-bit integer
	var ip_unpacked := (hex_ip.to_int() ^ OBFUSCATION_SALT)
	var port_unpacked := (hex_port.to_int() ^ (OBFUSCATION_SALT & 0xFFFF))
	
	# 2. Re-assemble IPv4 string segments
	var ip_parts: Array[String] = []
	for i in range(4):
		var shift_bits := (3 - i) * 8
		var byte_val := (ip_unpacked >> shift_bits) & 0xFF
		ip_parts.append(str(byte_val))
		
	var resolved_ip := ".".join(ip_parts)
	return {
		"ip": resolved_ip,
		"port": port_unpacked
	}