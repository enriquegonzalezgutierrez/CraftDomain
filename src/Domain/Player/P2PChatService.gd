# ==============================================================================
# Pathfile: res://src/Domain/Player/P2PChatService.gd
# Description: Pure Domain Service responsible for text chat message sanitization,
#              command parsing, and BBCode formatting rules.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name P2PChatService
extends RefCounted

enum Channel {
	GLOBAL,  
	PRIVATE, 
	SYSTEM   
}

## Inner value class representing the data state of a single message.
class ChatMessage:
	var sender_id: int
	var sender_name: String
	var text: String
	var channel: Channel
	var target_name: String = ""
	var timestamp: String
	
	func _init(p_id: int, p_name: String, p_text: String, p_chan: Channel, p_target: String = "") -> void:
		sender_id = p_id
		sender_name = p_name
		text = p_text
		channel = p_chan
		target_name = p_target
		timestamp = Time.get_time_string_from_system()


## Escapes/Strips BBCode characters to prevent rich-text UI injection exploits.
static func sanitize_text(input: String) -> String:
	return input.replace("[", "").replace("]", "").strip_edges()


## Parses raw user inputs, sorting them into either global chats or whispers.
static func parse_incoming_text(sender_id: int, sender_name: String, raw_text: String) -> ChatMessage:
	var text := raw_text.strip_edges()
	
	if text.begins_with("/w ") or text.begins_with("/whisper "):
		return _parse_whisper_command(sender_id, sender_name, text)
		
	var sanitized := sanitize_text(text)
	return ChatMessage.new(sender_id, sender_name, sanitized, Channel.GLOBAL)


## Bakes a ChatMessage into an elegant BBCode formatted string.
static func format_message(msg: ChatMessage) -> String:
	match msg.channel:
		Channel.PRIVATE:
			return "[color=#ff008c][%s] [WHISPER] %s -> %s: %s[/color]" % [msg.timestamp, msg.sender_name, msg.target_name, msg.text]
		Channel.SYSTEM:
			return "[color=#ffaa00][%s] [SYSTEM] %s[/color]" % [msg.timestamp, msg.text]
		_:
			return "[color=#00f3f3][%s][/color] [b]%s[/b]: %s" % [msg.timestamp, msg.sender_name, msg.text]


static func _parse_whisper_command(sender_id: int, sender_name: String, text: String) -> ChatMessage:
	var parts := text.split(" ", false, 2)
	
	if parts.size() < 3:
		var error_msg := TranslationServer.translate("CHAT_ERROR_INVALID_WHISPER")
		return ChatMessage.new(1, "SYSTEM", error_msg, Channel.SYSTEM)
		
	var target_name := parts[1].strip_edges()
	var msg_body := sanitize_text(parts[2])
	
	return ChatMessage.new(sender_id, sender_name, msg_body, Channel.PRIVATE, target_name)
