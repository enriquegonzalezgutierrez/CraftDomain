# ==============================================================================
# Pathfile: res://src/Infrastructure/Persistence/ModSandboxChecker.gd
# Description: Static infrastructure utility responsible for scanning external 
#              GDScripts for malicious system API calls before compilation.
#              Ensures a secure Sandbox environment for the Modding API (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ModSandboxChecker
extends RefCounted

## List of string patterns representing restricted Godot APIs that external mods 
## are not allowed to invoke for security and anti-cheat reasons.
const RESTRICTED_APIS: Array[String] = [
	"OS.execute",            # Running terminal commands
	"OS.create_process",     # Spawning executable files
	"OS.kill",               # Killing system processes
	"DirAccess.remove_absolute", # Deleting files outside user://
	"FileAccess.open",       # Reading/Writing arbitrary hard-drive files
	"HTTPRequest",           # Making silent web requests/data scraping
	"TCPServer",             # Opening raw ports
	"UDPServer",             # Opening raw ports
	"StreamPeerTCP",         # Unsafe network streams
	"StreamPeerTLS",         # Unsafe network streams
	"multiplayer.multiplayer_peer" # Forcing server disconnections
]


## Scans the plain text of a GDScript file before loading it. 
## Returns true if the script is secure and free of restricted API calls.
static func is_script_safe_for_compilation(absolute_file_path: String) -> bool:
	if not FileAccess.file_exists(absolute_file_path):
		return false
		
	var file := FileAccess.open(absolute_file_path, FileAccess.READ)
	if file == null:
		return false
		
	var source_code := file.get_as_text()
	file.close()
	
	# Evaluate against all restricted API signatures
	for restricted_call: String in RESTRICTED_APIS:
		if _contains_malicious_signature(source_code, restricted_call):
			_log_security_violation(absolute_file_path, restricted_call)
			return false
			
	return true


## Evaluates a specific signature using strict string matching to prevent false positives.
static func _contains_malicious_signature(source_code: String, signature: String) -> bool:
	# Removes whitespace to catch sneaky formatting (e.g. `OS . execute`)
	var sanitized_code := source_code.replace(" ", "")
	var sanitized_signature := signature.replace(" ", "")
	
	# If the exact restricted chain of calls is found anywhere in the text
	return sanitized_code.contains(sanitized_signature)


## Formats a high-visibility warning to the console, alerting the user to uninstall the mod.
static func _log_security_violation(file_path: String, triggered_signature: String) -> void:
	var mod_folder := file_path.get_base_dir()
	push_warning("======================================================================")
	push_warning("🚨 SECURITY ALERT: MALICIOUS MOD SCRIPT BLOCKED 🚨")
	push_warning("File: " + file_path)
	push_warning("Reason: Attempted to call restricted system API -> '" + triggered_signature + "'")
	push_warning("Action Taken: Script compilation aborted. The mod will not be loaded.")
	push_warning("Recommendation: Delete the folder '" + mod_folder + "' from your user://mods/ directory immediately.")
	push_warning("======================================================================")