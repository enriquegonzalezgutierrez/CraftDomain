# ==============================================================================
# Pathfile: res://src/Infrastructure/Network/NetworkUPnPService.gd
# Description: Infrastructure Service responsible for asynchronous UPnP port 
#              mapping over LAN and silent public IP HTTP auto-detection (DIP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NetworkUPnPService
extends Node

signal join_code_generated(join_code: String)
signal upnp_mapping_finished(success: bool)

const IP_LOOKUP_ENDPOINT: String = "https://api.ipify.org"
const DEFAULT_PORT: int = 25565

var _http_request: HTTPRequest


func _ready() -> void:
	name = "NetworkUPnPService"
	_setup_http_request()


## Initiates background UPnP port mapping and triggers public IP detection.
## Runs completely locally without requiring external central master servers.
func start_upnp_and_ip_lookup(port: int = DEFAULT_PORT) -> void:
	# 1. Start asynchronous UPnP discovery in a background thread task (Section 1.2)
	WorkerThreadPool.add_task(_async_upnp_port_mapping.bind(port))
	
	# 2. Start silent public IP lookup via secure HTTP query
	_trigger_async_ip_lookup()


func _setup_http_request() -> void:
	_http_request = HTTPRequest.new()
	_http_request.name = "IPLookupRequest"
	add_child(_http_request)
	_http_request.request_completed.connect(_on_ip_lookup_completed)


func _trigger_async_ip_lookup() -> void:
	if is_instance_valid(_http_request):
		var err := _http_request.request(IP_LOOKUP_ENDPOINT)
		if err != OK:
			push_error("[NetworkUPnP] Failed to initiate public IP lookup request: " + error_string(err))


func _on_ip_lookup_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_error("[NetworkUPnP ERROR] Public IP lookup failed. Offline or API blocked.")
		return
		
	var public_ip := body.get_string_from_utf8().strip_edges()
	if public_ip.is_empty() or not public_ip.is_valid_ip_address():
		push_error("[NetworkUPnP ERROR] Retrieved invalid IP address format: " + public_ip)
		return
		
	# Call our pure domain solver mathematics to encode the absolute public IP
	var join_code := NetworkJoinCodeSolver.encode_ip_and_port(public_ip, DEFAULT_PORT)
	print("[NetworkUPnP] Public IP detected: ", public_ip, " | Dynamic Join Code generated: ", join_code)
	join_code_generated.emit(join_code)


func _async_upnp_port_mapping(port: int) -> void:
	print("[NetworkUPnP] Searching for local UPnP-capable router gateway over LAN...")
	var upnp := UPNP.new()
	
	var disc_result := upnp.discover()
	if disc_result != UPNP.UPNP_RESULT_SUCCESS:
		_on_upnp_mapping_finished(false, "[NetworkUPnP Warning] Router discovery failed. UPnP might be disabled.")
		return
		
	var gateway := upnp.get_gateway()
	if not is_instance_valid(gateway) or not gateway.is_valid_gateway():
		_on_upnp_mapping_finished(false, "[NetworkUPnP Warning] No valid active gateway discovered.")
		return
		
	var map_result_udp := upnp.add_port_mapping(port, port, "CraftDomain Host (UDP)", "UDP")
	
	var success := (map_result_udp == UPNP.UPNP_RESULT_SUCCESS)
	if success:
		_on_upnp_mapping_finished(true, "[NetworkUPnP] Dynamic Port Mapping completed successfully! UDP " + str(port) + " is open.")
	else:
		_on_upnp_mapping_finished(false, "[NetworkUPnP Warning] Port mapping failed. Result code: " + str(map_result_udp))


func _on_upnp_mapping_finished(success: bool, debug_message: String) -> void:
	print(debug_message)
	# Emit signal deferred to the main thread safely (Section 7.3)
	upnp_mapping_finished.emit.call_deferred(success)