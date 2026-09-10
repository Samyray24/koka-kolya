class_name NPCCharacter
extends Node3D

# NPCCharacter — контроллер мирных жителей, рабочих и связной Саши V
# Обеспечивает живые анимации, скрытие лишнего оружия у прохожих, динамические бейджи и плавный взгляд на Колю.

@export var npc_name: String = "Прохожий"
@export var show_name: bool = true
@export var is_sasha: bool = false
@export var equip_weapons: bool = false

@onready var model: Node3D = get_node_or_null("Model")
@onready var nameplate: Label3D = get_node_or_null("Nameplate")

var anim_player: AnimationPlayer = null
var player_ref: Node3D = null
var check_player_timer: float = 0.0

func _ready() -> void:
	_setup_nameplate()
	_setup_model_and_weapons()
	_setup_animations()

func _setup_nameplate() -> void:
	if not nameplate:
		nameplate = get_node_or_null("Nameplate")
	if nameplate:
		nameplate.visible = show_name
		nameplate.text = npc_name
		nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nameplate.font_size = 22
		nameplate.outline_size = 4
		nameplate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if is_sasha:
			nameplate.modulate = Color(0.2, 0.9, 1.0)
			nameplate.text = "Саша V (Сопротивление)"
		else:
			nameplate.modulate = Color(0.9, 0.92, 0.95)

func _setup_model_and_weapons() -> void:
	if not model:
		return
	
	# Скрываем лишнее средневековое оружие у мирных жителей
	var knife_l: Node = model.find_child("Knife_Offhand", true, false)
	var cross_1h: Node = model.find_child("1H_Crossbow", true, false)
	var cross_2h: Node = model.find_child("2H_Crossbow", true, false)
	var knife_r: Node = model.find_child("Knife", true, false)
	var throwable: Node = model.find_child("Throwable", true, false)

	if not equip_weapons:
		if knife_l: knife_l.visible = false
		if cross_1h: cross_1h.visible = false
		if cross_2h: cross_2h.visible = false
		if knife_r: knife_r.visible = false
		if throwable: throwable.visible = false
	else:
		# Если оружие включено (например, скрытый клинок Саши)
		if cross_1h: cross_1h.visible = false
		if cross_2h: cross_2h.visible = false
		if throwable: throwable.visible = false

func _setup_animations() -> void:
	if not model:
		return
	anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		var anim_to_play: String = ""
		if anim_player.has_animation("Unarmed_Idle"):
			anim_to_play = "Unarmed_Idle"
		elif anim_player.has_animation("Idle"):
			anim_to_play = "Idle"
		elif anim_player.has_animation("idle"):
			anim_to_play = "idle"
		
		if not anim_to_play.is_empty():
			anim_player.play(anim_to_play)
			# Смещаем фазу анимации, чтобы толпа не дышала синхронно
			var anim_len: float = anim_player.current_animation_length
			if anim_len > 0.0:
				anim_player.seek(randf_range(0.0, anim_len), true)

func _process(delta: float) -> void:
	check_player_timer += delta
	if check_player_timer >= 0.2:
		check_player_timer = 0.0
		if not is_instance_valid(player_ref):
			player_ref = get_tree().get_first_node_in_group("player") as Node3D
			if not player_ref:
				var pl_node := get_node_or_null("../Player")
				if pl_node:
					player_ref = pl_node as Node3D

	# Плавный поворот взгляда к игроку при приближении
	if is_instance_valid(player_ref):
		var dist_sq: float = global_position.distance_squared_to(player_ref.global_position)
		if dist_sq < 25.0 and dist_sq > 0.6: # В пределах 5 метров
			var target_pos := Vector3(player_ref.global_position.x, global_position.y, player_ref.global_position.z)
			var cur_rot_y := rotation.y
			var target_transform := transform.looking_at(target_pos, Vector3.UP)
			rotation.y = lerp_angle(rotation.y, target_transform.basis.get_euler().y, delta * 3.0)
