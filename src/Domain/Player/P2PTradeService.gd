# ==============================================================================
# Pathfile: res://src/Domain/Player/P2PTradeService.gd
# Description: Pure Domain Service managing transactional player-to-player (P2P)
#              trading sessions between abstract inventories.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates session states,
#   offer validations, and atomic transaction commits.
# - Dependency Inversion Principle (DIP): Operates entirely on the abstract 
#   IInventory interface, keeping trade rules insulated from physics or UI.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name P2PTradeService
extends RefCounted

## Inner class representing the data state of an active trading session
class P2PTradeSession:
	var session_id: String
	var inv_a: IInventory
	var inv_b: IInventory
	var offer_a: Dictionary = {} # item_id (int) -> quantity (int)
	var offer_b: Dictionary = {} # item_id (int) -> quantity (int)
	var confirmed_a: bool = false
	var confirmed_b: bool = false
	var is_committed: bool = false
	var is_cancelled: bool = false
	
	func _init(p_id: String, p_inv_a: IInventory, p_inv_b: IInventory) -> void:
		session_id = p_id
		inv_a = p_inv_a
		inv_b = p_inv_b


## Instantiates and registers a new trading session between two inventories
static func create_session(session_id: String, inv_a: IInventory, inv_b: IInventory) -> P2PTradeSession:
	return P2PTradeSession.new(session_id, inv_a, inv_b)


## Updates the offered items for a specific party, resetting confirmations
static func update_offer(session: P2PTradeSession, is_player_a: bool, offer: Dictionary) -> void:
	if is_player_a:
		session.offer_a = offer
		session.confirmed_a = false
	else:
		session.offer_b = offer
		session.confirmed_b = false
	session.confirmed_a = false
	session.confirmed_b = false


## Toggles the confirmation state for a specific party
static func set_confirmed(session: P2PTradeSession, is_player_a: bool, confirmed: bool) -> void:
	if is_player_a:
		session.confirmed_a = confirmed
	else:
		session.confirmed_b = confirmed


## Evaluates if both parties have confirmed and have sufficient stocks and space
static func can_commit(session: P2PTradeSession) -> bool:
	if not session.confirmed_a or not session.confirmed_b:
		return false
	if session.is_committed or session.is_cancelled:
		return false
		
	return _validate_inventories_capacity(session)


## Executes the atomic transaction, consuming outputs and granting inputs
static func commit_trade(session: P2PTradeSession) -> bool:
	if not can_commit(session):
		return false
		
	_consume_offers(session)
	_add_offers(session)
	
	session.is_committed = true
	return true


## Cancels the session, locking it from further mutations
static func cancel_trade(session: P2PTradeSession) -> void:
	session.is_cancelled = true
	session.confirmed_a = false
	session.confirmed_b = false


static func _validate_inventories_capacity(session: P2PTradeSession) -> bool:
	if not _has_sufficient_stock(session.inv_a, session.offer_a):
		return false
	if not _has_sufficient_stock(session.inv_b, session.offer_b):
		return false
		
	if not _has_sufficient_capacity(session.inv_a, session.offer_b):
		return false
	if not _has_sufficient_capacity(session.inv_b, session.offer_a):
		return false
		
	return true


static func _has_sufficient_stock(inv: IInventory, offer: Dictionary) -> bool:
	for item_id: int in offer.keys():
		var required_qty := int(offer[item_id])
		if inv.get_item_total_quantity(item_id) < required_qty:
			return false
	return true


static func _has_sufficient_capacity(inv: IInventory, incoming_offer: Dictionary) -> bool:
	for item_id: int in incoming_offer.keys():
		var quantity := int(incoming_offer[item_id])
		if not inv.can_receive_item(item_id, quantity):
			return false
	return true


static func _consume_offers(session: P2PTradeSession) -> void:
	for item_id: int in session.offer_a.keys():
		session.inv_a.consume_item(item_id, int(session.offer_a[item_id]))
	for item_id: int in session.offer_b.keys():
		session.inv_b.consume_item(item_id, int(session.offer_b[item_id]))


static func _add_offers(session: P2PTradeSession) -> void:
	for item_id: int in session.offer_b.keys():
		session.inv_a.add_item(item_id, int(session.offer_b[item_id]))
	for item_id: int in session.offer_a.keys():
		session.inv_b.add_item(item_id, int(session.offer_a[item_id]))
