# ==============================================================================
# Pathfile: res://src/Domain/Life/MerchantModelBuilder.gd
# Description: Concrete strategy implementing the procedural voxel model 
#              sculptor for the Shopkeeper Merchant entity.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MerchantModelBuilder
extends IVoxelModelBuilder


func build_model(
	visual_component: Object, 
	skin_color: Color, 
	_clothing_color: Color, 
	_hair_color: Color, 
	biome_id: int
) -> void:
	if not is_instance_valid(visual_component):
		return
		
	var body_bob_node: Node3D = visual_component.get("body_bob_node") as Node3D
	if not is_instance_valid(body_bob_node):
		return
		
	var colors := _resolve_merchant_palette(biome_id)
	_sculpt_merchant_robe(visual_component, body_bob_node, colors["robe"], colors["apron"])
	_sculpt_merchant_head(visual_component, body_bob_node, skin_color, colors["turban"])


func _resolve_merchant_palette(biome_id: int) -> Dictionary:
	var robe_color := Color(0.45, 0.15, 0.6)         # Royal violet
	var apron_color := Color(0.85, 0.6, 0.15)        # Gold apron
	var turban_color := Color(0.9, 0.82, 0.45)       # Soft gold
	
	if biome_id == 7: # Cyber Ruins (Black & Cyan)
		robe_color = Color(0.12, 0.12, 0.15)
		apron_color = Color(0.0, 0.95, 0.95)
		turban_color = Color(0.12, 0.12, 0.15)
		
	return {"robe": robe_color, "apron": apron_color, "turban": turban_color}


func _sculpt_merchant_robe(visual_component: Object, parent: Node3D, robe_color: Color, apron_color: Color) -> void:
	visual_component.call("create_box", parent, Vector3(0.42, 0.15, 0.42), Vector3(0, 0.075, 0), Color(0.15, 0.1, 0.08)) # Boots
	visual_component.call("create_box", parent, Vector3(0.45, 0.75, 0.45), Vector3(0, 0.525, 0), robe_color)
	visual_component.call("create_box", parent, Vector3(0.3, 0.5, 0.05), Vector3(0, 0.38, -0.23), apron_color) # Apron
	visual_component.call("create_box", parent, Vector3(0.12, 0.18, 0.12), Vector3(-0.24, 0.38, -0.15), Color(0.35, 0.22, 0.15)) # Floating leather pouch


func _sculpt_merchant_head(visual_component: Object, parent: Node3D, skin_color: Color, turban_color: Color) -> void:
	var head_node := Node3D.new()
	head_node.name = "HumanHead"
	head_node.position = Vector3(0, 1.05, 0)
	parent.add_child(head_node)
	visual_component.set("head_node", head_node)
	
	visual_component.call("create_box", head_node, Vector3(0.35, 0.37, 0.35), Vector3(0, 0.185, 0), skin_color)
	visual_component.call("create_box", head_node, Vector3(0.09, 0.21, 0.12), Vector3(0, 0.12, -0.21), skin_color * 0.9)
	visual_component.call("create_box", head_node, Vector3(0.38, 0.12, 0.38), Vector3(0, 0.36, 0), turban_color)
	visual_component.call("create_box", head_node, Vector3(0.06, 0.08, 0.04), Vector3(0, 0.36, -0.20), Color(0.92, 0.12, 0.15)) # Ruby
