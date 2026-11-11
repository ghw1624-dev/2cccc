extends Node2D
# 애니메이션으로 움직이는 공격판정 겸 이펙트 씬의 루트에 붙이는 스크립트 (Godot 4.x)
#
# 이펙트 씬 구조 (이름을 맞춰주세요, 둘 다 선택 사항):
# SkillEffect (Node2D)        <- 이 스크립트
# ├─ AnimatedSprite2D         <- 이펙트 애니메이션
# └─ Hitbox (Area2D)          <- 공격판정. 안에 CollisionShape2D 추가
#    └─ CollisionShape2D
#
# 재생할 애니메이션: effect_animation 이름 → 없으면 AnimatedSprite2D에 설정된 현재 애니메이션 → 없으면 첫 번째 애니메이션
# 공격판정은 애니메이션의 hit_start_frame ~ hit_end_frame 프레임 동안에만 켜집니다.
# 회복 스킬처럼 판정이 필요 없으면 Hitbox 없이 AnimatedSprite2D만 두면 됩니다.
# 캐릭터가 오른쪽을 볼 때를 기준으로 위치를 잡으세요. 왼쪽을 볼 땐 캐릭터 스크립트가 자동으로 뒤집어요.

@export var damage: float = 10.0              # 캐릭터 스크립트가 생성할 때 덮어씀
@export var lifetime: float = 0.0             # 0보다 크면 이 시간이 지나면 무조건 제거(상한선). 0이하면 시간 제한 없음
@export var free_on_animation_end: bool = true  # true면 (반복 안 하는) 이펙트 애니메이션이 끝나는 즉시 제거
@export var effect_animation: StringName = &"default"
@export var target_group: StringName = &"enemy"  # 이 그룹의 대상에게 피해를 줌
@export var hit_once_per_target: bool = true  # true면 한 대상에게 한 번만, false면 닿을 때마다 피해
@export var hit_start_frame: int = 0          # 이 프레임부터 판정 ON
@export var fit_duration: float = 0.0         # 0보다 크면 애니메이션 전체가 이 시간(초)에 끝나도록 재생 속도를 조절
@export var hit_end_frame: int = -1           # 이 프레임까지 판정 ON (-1이면 애니메이션 끝까지)

@onready var hitbox: Area2D = get_node_or_null("Hitbox") as Area2D
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

var _hit_targets: Array[Node] = []
var _anim_name: StringName = &""


func _ready() -> void:
	_anim_name = _resolve_animation()
	var has_anim: bool = _anim_name != &""

	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		if has_anim:
			hitbox.monitoring = _is_hit_frame(0)  # 시작 프레임이 판정 구간이 아니면 꺼둠
			sprite.frame_changed.connect(_on_frame_changed)

	if has_anim:
		if fit_duration > 0.0:
			sprite.speed_scale = max(_natural_length(_anim_name) / fit_duration, 0.01)
		sprite.play(_anim_name)
		var loops: bool = sprite.sprite_frames.get_animation_loop(_anim_name)
		if loops and lifetime <= 0.0:
			# 반복 애니메이션은 끝나지 않으므로 안전하게 1초 뒤 제거 (Loop를 끄거나 lifetime을 지정하세요)
			push_warning("이펙트 애니메이션 '%s'가 반복(Loop) 상태예요. Loop를 끄거나 lifetime을 지정하세요." % _anim_name)
			get_tree().create_timer(1.0).timeout.connect(queue_free)
		elif free_on_animation_end or lifetime <= 0.0:
			# 반복을 끈 애니메이션은 끝나면 animation_finished가 발생 → 바로 제거
			sprite.animation_finished.connect(queue_free)

	# lifetime은 상한선: 애니메이션이 먼저 끝나면 그때 이미 제거됨
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(queue_free)
	elif not has_anim:
		get_tree().create_timer(0.3).timeout.connect(queue_free)


# 재생할 애니메이션 이름을 찾음. 이름이 안 맞아도 첫 프레임에서 멈추지 않도록 대체 애니메이션을 사용
func _resolve_animation() -> StringName:
	if sprite == null or sprite.sprite_frames == null:
		return &""
	var frames := sprite.sprite_frames
	if frames.has_animation(effect_animation):
		return effect_animation
	push_warning("이펙트 애니메이션 '%s'를 찾지 못했어요. 대신 다른 애니메이션을 재생합니다. (SpriteFrames의 애니메이션 이름을 확인하세요)" % effect_animation)
	if frames.has_animation(sprite.animation):
		return sprite.animation
	var names := frames.get_animation_names()
	if names.size() > 0:
		return StringName(names[0])
	return &""


# 애니메이션의 원래 재생 시간(초)
func _natural_length(anim: StringName) -> float:
	var frames := sprite.sprite_frames
	var total: float = 0.0
	for i in frames.get_frame_count(anim):
		total += frames.get_frame_duration(anim, i)
	var fps: float = frames.get_animation_speed(anim)
	return total / fps if fps > 0.0 else 1.0


func _is_hit_frame(frame: int) -> bool:
	return frame >= hit_start_frame and (hit_end_frame < 0 or frame <= hit_end_frame)


# 애니메이션 프레임이 바뀔 때마다 판정 ON/OFF
func _on_frame_changed() -> void:
	hitbox.set_deferred("monitoring", _is_hit_frame(sprite.frame))


func _on_hitbox_body_entered(body: Node2D) -> void:
	if not body.is_in_group(target_group):
		return
	if hit_once_per_target and _hit_targets.has(body):
		return
	_hit_targets.append(body)
	# 대상이 take_damage(amount) 함수를 가지고 있을 때 피해를 줌
	if body.has_method("take_damage"):
		body.take_damage(damage)
