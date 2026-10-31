extends Node
## Global run state, autoloaded as `GameState`: unlocked abilities, hearts and
## energy. Gameplay nodes read and change the run through this node and listen
## to its signals (the HUD, ability gates, pickups).

signal hearts_changed(current: int, maximum: int)
signal energy_changed(current: float, maximum: float)
signal ability_unlocked(ability: StringName)
signal abilities_reset
signal energy_denied  ## A special was attempted without enough energy.

# Traversal abilities, in the order the zones hand them out.
const DASH := &"dash"
const DOUBLE_JUMP := &"double_jump"
const WALL_JUMP := &"wall_jump"
const WALL_CLIMB := &"wall_climb"
const DIG := &"dig"
const ALL_ABILITIES: Array[StringName] = [DASH, DOUBLE_JUMP, WALL_JUMP, WALL_CLIMB, DIG]
const ABILITY_NAMES: Dictionary[StringName, String] = {
	DASH: "Dash",
	DOUBLE_JUMP: "Double Jump",
	WALL_JUMP: "Wall Jump",
	WALL_CLIMB: "Wall Climb",
	DIG: "Dig",
}

const STARTING_HEARTS := 4
const STARTING_ENERGY := 50.0
const SPECIAL_COST := 25.0

## Energy regained per second.
@export var energy_regen_per_second := 10.0

var max_hearts := STARTING_HEARTS
var hearts := STARTING_HEARTS
var max_energy := STARTING_ENERGY
var energy := STARTING_ENERGY
var _abilities: Dictionary[StringName, bool] = {}


func _process(delta: float) -> void:
	if energy < max_energy:
		energy = minf(energy + energy_regen_per_second * delta, max_energy)
		energy_changed.emit(energy, max_energy)


func new_game() -> void:
	max_hearts = STARTING_HEARTS
	max_energy = STARTING_ENERGY
	_abilities.clear()
	abilities_reset.emit()
	refill()


# --- Abilities ---------------------------------------------------------------

func has_ability(ability: StringName) -> bool:
	return _abilities.get(ability, false)


func unlock_ability(ability: StringName) -> void:
	if has_ability(ability):
		return
	_abilities[ability] = true
	ability_unlocked.emit(ability)


func ability_display_name(ability: StringName) -> String:
	return ABILITY_NAMES.get(ability, String(ability))


# --- Hearts --------------------------------------------------------------------

## Removes hearts. Returns true if this hit was fatal.
func damage(amount: int = 1) -> bool:
	hearts = maxi(hearts - amount, 0)
	hearts_changed.emit(hearts, max_hearts)
	return hearts == 0


func heal(amount: int = 1) -> void:
	hearts = mini(hearts + amount, max_hearts)
	hearts_changed.emit(hearts, max_hearts)


func add_max_heart() -> void:
	max_hearts += 1
	hearts = max_hearts
	hearts_changed.emit(hearts, max_hearts)


# --- Energy ----------------------------------------------------------------------

## Spends energy for a special attack. Returns false (and emits energy_denied)
## if there isn't enough.
func try_spend_energy(amount: float = SPECIAL_COST) -> bool:
	if energy < amount:
		energy_denied.emit()
		return false
	energy -= amount
	energy_changed.emit(energy, max_energy)
	return true


func add_max_energy(amount: float = SPECIAL_COST) -> void:
	max_energy += amount
	energy = max_energy
	energy_changed.emit(energy, max_energy)


func refill() -> void:
	hearts = max_hearts
	energy = max_energy
	hearts_changed.emit(hearts, max_hearts)
	energy_changed.emit(energy, max_energy)


# --- Debug shortcuts (debug builds only) -------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_F1:
			for ability in ALL_ABILITIES:
				unlock_ability(ability)
		KEY_F2:
			_abilities.clear()
			abilities_reset.emit()
		KEY_F3:
			refill()
