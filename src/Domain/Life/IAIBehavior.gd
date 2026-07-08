# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic)
# Class: IAIBehavior
# Description: Pure Domain Strategy Interface defining the execution contract 
#              for custom, entity-specific AI behavior routines.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively defines the behavioral
#   execution boundary, decoupling decision-making processes from physical 
#   movement structures.
# - Open-Closed Principle (OCP): Enables the addition of infinite unique 
#   AI patterns (such as farming, aggressive chasing, and mining) without 
#   modifying existing entity base controllers or monolithic AI classes.
# - Liskov Substitution Principle (LSP): Serves as a polymorphic contract. 
#   Any concrete strategy subclass can be injected into the coordinating AI 
#   component and processed seamlessly without runtime exceptions.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name IAIBehavior
extends Resource

## Contract: Evaluates environmental states and executes specialized logical 
## routines for the host character.
## [param host]: The physical character controller node of the entity.
## [param ai_component]: The composite AI coordinator node managing task timers.
## [param delta]: The physics execution frame-time step in seconds.
func evaluate_and_execute(host: CharacterBody3D, ai_component: Node, delta: float) -> void:
	# Avoid unused parameter warnings in the abstract interface contract
	var _host_ref := host
	var _ai_ref := ai_component
	var _d_val := delta
	
	assert(false, "[IAIBehavior ERROR] evaluate_and_execute must be implemented by a concrete subclass.")
