extends CharacterBody2D
# 보스 몬스터 (Godot 4.x, AnimatedSprite2D 기준)
# "player" 그룹을 감지하면 플레이어 쪽을 보고 run 애니메이션으로 다가가다가, 공격 범위 안에 들어오면 공격 패턴을 시작합니다.
#
# 공격 패턴:
#   [근접] 기본 공격 : 0.5초 대기모션 → 플레이어 쪽으로 빠르게 대쉬하며 베기      (2번 반복)
#   [근접] 콤보 공격 : 2초 대기모션 → 플레이어 쪽으로 대쉬하며 3번 베기(0.5초 간격)
#   [원거리] S!      : 콤보 공격 직후 1번 사용. 무기를 휘두르면 크고 빠른 땅 솟아오름 투사체가 플레이어 쪽으로 달려감
#   [원거리] 일반    : 플레이어가 ranged_min_distance 이상 멀리 있으면 다가가지 않고 사용 (S!보다 작고 느린 투사체)
#   S!가 끝나면 카운터가 초기화되어 다시 기본 공격부터
# 참격과 투사체는 플레이어의 take_damage()로 피해를 줍니다.
#
# 씬 구조 (이름을 맞춰주세요):
# Boss (CharacterBody2D)  <- 이 스크립트
# ├─ CollisionShape2D
# ├─ AnimatedSprite2D     <- idle / run / attack_ready / attack / ranged_attack / s_attack 애니메이션이 있는 노드
# └─ DetectionArea (Area2D)
#    └─ CollisionShape2D  <- 감지 범위(원형 추천). 원거리 공격을 쓰려면 ranged_min_distance보다 넓어야 함
#
# 주의: DetectionArea의 body_entered / body_exited 시그널은 에디터(노드 탭)에서 연결한 상태입니다.
#       그래서 _ready()에서 다시 connect 하지 않습니다.

enum State { IDLE, ATTACK, DEAD }
enum AttackKind { BASIC, COMBO, RANGED, S_RANGED }
enum AttackPhase { WINDUP, DASH, GAP, CAST, RECOVER }

@export var idle_animation: StringName = &"idle"
@export var run_animation: StringName = &"run"                  # 이동할 때 재생
@export var windup_animation: StringName = &"attack_ready"      # 공격 전 대기모션 (없으면 idle)
@export var attack_animation: StringName = &"attack"            # 대쉬하며 벨 때 재생
@export var player_group: StringName = &"player"                # 감지할 그룹 이름

# ---------- 이동 ----------
@export var move_speed: float = 120.0     # 이동 속도(px/s)
@export var gravity: float = 980.0
@export var sprite_faces_right: bool = true  # 스프라이트 원본 그림이 오른쪽을 보고 있으면 true, 왼쪽이면 false

# ---------- 체력 ----------
@export var boss_name: String = "보스"          # 체력바에 표시되는 이름 (인스펙터에서 자유롭게 변경)
@export var max_health: float = 500.0
@export var die_animation: StringName = &"die"  # 죽을 때 재생 (없으면 바로 사라짐)
signal health_changed(current: float, maximum: float)
@export var poison_effect: PackedScene         # 독 피해가 들어갈 때마다 나오는 이펙트 (직접 그린 애니메이션, skill_effect.gd 를 붙인 씬)
signal died
signal engaged  # 플레이어를 처음 감지했을 때 한 번 발생 (보스 체력바가 이때 나타남)
signal poison_ticked(damage: float, stacks: int)  # 독 피해가 들어갈 때마다 발생

# ---------- 공격 공통 ----------
@export var slash_effect: PackedScene           # 참격 이펙트 씬 (skill_effect.gd 를 붙인 씬). 대쉬를 시작할 때마다 생성됨
@export var attack_range: float = 300.0         # 가로 거리가 이 안이면 멈추고 근접 공격 시작 (대쉬 공격이라 넉넉하게)
@export var attack_vertical_tolerance: float = 80.0  # 세로 거리가 이 안일 때만 공격
@export var attack_cooldown: float = 1.0        # 공격 하나가 끝난 뒤 다음 공격을 시작하기까지 대기시간(초)
@export var dash_slide_power: float = 1.5       # 미끄러지는 정도: 1 = 일정하게 느려짐, 클수록 빠르게 출발해서 길게 미끄러지며 멈춤
@export var dash_speed: float = 1400.0          # 대쉬 출발 순간의 최고 속도(px/s)
@export var dash_distance: float = 350.0        # 한 번 대쉬할 때 이동하는 거리(px). 플레이어 위치와 상관없이 항상 이만큼 쭉 감
@export var recover_time: float = 0.4           # 마지막 동작 뒤 굳어 있는 시간(초)

# ---------- 기본 공격 / 콤보 공격 ----------
@export var attack_damage: float = 10.0         # 기본 공격 피해
@export var basic_windup_time: float = 0.5      # 기본 공격 대기모션 시간(초)
@export var basics_before_combo: int = 2        # 기본 공격을 이만큼 반복하면 다음은 콤보 공격
@export var combo_damage: float = 10.0          # 콤보 공격 베기 1회당 피해
@export var combo_windup_time: float = 2.0      # 콤보 공격 대기모션 시간(초)
@export var combo_slash_count: int = 3          # 콤보 공격에서 베는 횟수
@export var combo_gap: float = 0.5              # 콤보에서 베기와 베기 사이 간격(초)

# ---------- 원거리 공격 / S! ----------
@export var ranged_projectile: PackedScene      # 일반 원거리 투사체 씬 (ground_wave.gd 를 붙인 씬)
@export var s_projectile: PackedScene           # S! 투사체 씬 (ground_wave.gd, 일반보다 크고 빠르게 설정한 별도 씬)
@export var ranged_animation: StringName = &"ranged_attack"  # 무기를 휘두르는 모션 (없으면 attack)
@export var s_animation: StringName = &"s_attack"            # S! 때 무기를 휘두르는 모션 (없으면 ranged_attack)
@export var ranged_min_distance: float = 600.0  # 플레이어가 이 거리 이상 멀면 다가가지 않고 일반 원거리 공격
@export var s_attack_enabled: bool = true       # true면 콤보 공격 직후에 S! 사용
@export var projectile_spawn_offset: Vector2 = Vector2(60, 0)  # 보스 위치 기준 투사체 시작 위치 (오른쪽을 볼 때 기준)
@export var ranged_damage: float = 8.0          # 일반 원거리 피해 (솟아오름 1번당)
@export var ranged_windup_time: float = 0.5     # 일반 원거리 대기모션 시간(초)
@export var ranged_cast_duration: float = 0.6   # 일반 원거리 휘두르는 모션 전체 시간(초)
@export var ranged_spawn_delay: float = 0.3     # 휘두르기 시작 후 투사체가 나오기까지(초)
@export var s_damage: float = 15.0              # S! 피해 (솟아오름 1번당)
@export var s_windup_time: float = 1.0          # S! 대기모션 시간(초)
@export var s_cast_duration: float = 0.8        # S! 휘두르는 모션 전체 시간(초)
@export var s_spawn_delay: float = 0.4          # S! 휘두르기 시작 후 투사체가 나오기까지(초)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea

var targets: Array[Node2D] = []
var state: State = State.IDLE
var attack_cooldown_left: float = 0.0
var attack_kind: AttackKind = AttackKind.BASIC
var attack_phase: AttackPhase = AttackPhase.WINDUP
var phase_time_left: float = 0.0
var dashes_left: int = 0
var dash_dir: float = 1.0
var dash_total: float = 0.1       # 이번 대쉬가 지속되는 전체 시간(초)
var cast_elapsed: float = 0.0     # 원거리 공격에서 휘두르기를 시작한 뒤 지난 시간
var cast_spawned: bool = false    # 이번 원거리 공격에서 투사체를 이미 만들었는지
var basic_count: int = 0          # 지금까지 연속으로 한 기본 공격 횟수 (콤보 후 0으로 초기화)
var s_attack_pending: bool = false  # 다음 공격이 S!인지
var health: float = 0.0
var is_engaged: bool = false      # 플레이어를 한 번이라도 감지했는지 (체력바 표시용)
var poison_stacks: int = 0
var poison_time_left: float = 0.0
var poison_tick_left: float = 0.0
var poison_tick_interval: float = 0.5
var poison_damage_per_stack: float = 2.0


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")  # 보스 체력바(boss_health_bar.gd)가 이 그룹으로 보스를 찾음
	health = max_health
	health_changed.emit(health, max_health)
	_play(idle_animation)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	attack_cooldown_left = max(attack_cooldown_left - delta, 0.0)
	_process_poison(delta)

	# 죽은 뒤에는 움직이지 않음
	if state == State.DEAD:
		velocity.x = 0.0
		move_and_slide()
		return

	# 공격 중에는 공격 패턴이 움직임을 전부 결정함
	if state == State.ATTACK:
		_attack_state(delta)
		move_and_slide()
		return

	var target := _get_closest_target()
	if target == null:
		# 감지된 플레이어가 없으면 멈추고 대기
		velocity.x = 0.0
		_play(idle_animation)
		move_and_slide()
		return

	var dx: float = target.global_position.x - global_position.x
	var dy: float = target.global_position.y - global_position.y
	var dist: float = absf(dx)
	var can_attack: bool = attack_cooldown_left <= 0.0 and absf(dy) <= attack_vertical_tolerance

	# 1) 플레이어 쪽으로 모습(스프라이트) 돌리기
	_set_facing(dx)

	# 2) 공격 선택: S! 예약 > 멀면 원거리 > 가까우면 다가가서 근접 공격
	if can_attack and s_attack_pending:
		velocity.x = 0.0
		_start_attack(AttackKind.S_RANGED)
	elif dist >= ranged_min_distance:
		# 멀리 있으면 다가가지 않고 원거리 공격 (쿨타임 중에는 그 자리에서 대기)
		velocity.x = 0.0
		if can_attack:
			_start_attack(AttackKind.RANGED)
		else:
			_play(idle_animation)
	elif dist > attack_range:
		velocity.x = signf(dx) * move_speed
		_play_or(run_animation, idle_animation)
	else:
		velocity.x = 0.0
		if can_attack:
			_start_attack(AttackKind.COMBO if basic_count >= basics_before_combo else AttackKind.BASIC)
		else:
			_play(idle_animation)

	move_and_slide()


# ---------- 공격 패턴 ----------
func _start_attack(kind: AttackKind) -> void:
	state = State.ATTACK
	attack_kind = kind
	attack_phase = AttackPhase.WINDUP
	match kind:
		AttackKind.BASIC:
			dashes_left = 1
			phase_time_left = basic_windup_time
		AttackKind.COMBO:
			dashes_left = combo_slash_count
			phase_time_left = combo_windup_time
		AttackKind.RANGED:
			phase_time_left = ranged_windup_time
		AttackKind.S_RANGED:
			phase_time_left = s_windup_time
	velocity.x = 0.0
	_play_or(windup_animation, idle_animation)


func _is_ranged_attack() -> bool:
	return attack_kind == AttackKind.RANGED or attack_kind == AttackKind.S_RANGED


func _attack_state(delta: float) -> void:
	phase_time_left -= delta
	match attack_phase:
		AttackPhase.WINDUP:
			# 대기모션: 제자리에서 플레이어 쪽을 계속 바라봄. 끝나면 대쉬(근접) 또는 휘두르기(원거리) 시작
			velocity.x = 0.0
			_face_target()
			if phase_time_left <= 0.0:
				if _is_ranged_attack():
					_start_cast()
				else:
					_start_dash()
		AttackPhase.DASH:
			var slide: float = pow(clampf(phase_time_left / dash_total, 0.0, 1.0), dash_slide_power)
			velocity.x = dash_dir * dash_speed * slide  # 빠르게 출발해서 점점 느려지며 미끄러지듯 멈춤
			if phase_time_left <= 0.0:
				velocity.x = 0.0
				dashes_left -= 1
				if dashes_left > 0:
					# 콤보: 잠깐 쉬었다가 다시 플레이어를 조준해서 다음 베기
					attack_phase = AttackPhase.GAP
					phase_time_left = combo_gap
					_play_or(windup_animation, idle_animation)  # 다음 베기를 준비하는 동안에도 준비 동작 유지
				else:
					attack_phase = AttackPhase.RECOVER
					phase_time_left = recover_time
					_play(idle_animation)
		AttackPhase.GAP:
			velocity.x = 0.0
			_face_target()
			if phase_time_left <= 0.0:
				_start_dash()
		AttackPhase.CAST:
			# 무기를 휘두르는 모션: spawn_delay가 지나면 투사체 생성
			velocity.x = 0.0
			cast_elapsed += delta
			var spawn_delay: float = s_spawn_delay if attack_kind == AttackKind.S_RANGED else ranged_spawn_delay
			if not cast_spawned and cast_elapsed >= spawn_delay:
				cast_spawned = true
				_spawn_ground_wave()
			if phase_time_left <= 0.0:
				if not cast_spawned:
					cast_spawned = true
					_spawn_ground_wave()
				attack_phase = AttackPhase.RECOVER
				phase_time_left = recover_time
				_play(idle_animation)
		AttackPhase.RECOVER:
			velocity.x = 0.0
			if phase_time_left <= 0.0:
				_finish_attack()


# 플레이어 쪽으로 방향을 정하고 대쉬하며 벰
func _start_dash() -> void:
	var target := _get_closest_target()
	if target != null:
		var dx: float = target.global_position.x - global_position.x
		dash_dir = signf(dx) if dx != 0.0 else _facing_dir()
	else:
		dash_dir = _facing_dir()  # 플레이어를 놓쳤으면 바라보던 방향으로 대쉬
	_set_facing(dash_dir)
	attack_phase = AttackPhase.DASH
	# 출발 속도(dash_speed)에서 점점 느려져 0이 되는 동안 항상 dash_distance만큼 이동하도록 시간을 계산
	# (플레이어 위치와 상관없이 매번 같은 거리/시간이라 패턴을 읽기 쉬움)
	dash_total = maxf(dash_distance * (dash_slide_power + 1.0) / maxf(dash_speed, 1.0), 0.05)
	phase_time_left = dash_total
	_play_restart(attack_animation)
	_spawn_slash(combo_damage if attack_kind == AttackKind.COMBO else attack_damage)


# 원거리 공격: 무기를 휘두르는 모션 시작 (S!는 s_animation, 없으면 ranged_animation, 그것도 없으면 attack)
func _start_cast() -> void:
	var is_s: bool = attack_kind == AttackKind.S_RANGED
	attack_phase = AttackPhase.CAST
	cast_elapsed = 0.0
	cast_spawned = false
	phase_time_left = s_cast_duration if is_s else ranged_cast_duration
	_face_target()
	var swing: StringName = s_animation if (is_s and anim.sprite_frames.has_animation(s_animation)) else ranged_animation
	if not anim.sprite_frames.has_animation(swing):
		swing = attack_animation
	_play_restart(swing)


func _finish_attack() -> void:
	match attack_kind:
		AttackKind.BASIC:
			basic_count += 1
		AttackKind.COMBO:
			basic_count = 0  # 콤보가 끝나면 초기화
			if s_attack_enabled:
				s_attack_pending = true  # 콤보 직후에는 S! 사용
		AttackKind.S_RANGED:
			s_attack_pending = false  # S!가 끝나면 다시 기본 공격부터
		AttackKind.RANGED:
			pass  # 일반 원거리는 공격 순서(카운터)에 영향을 주지 않음
	attack_cooldown_left = attack_cooldown
	state = State.IDLE


# 참격 이펙트 씬을 보스의 자식으로 생성 (대쉬하는 동안 보스를 따라다니고, 바라보는 방향에 맞춰 좌우 반전)
func _spawn_slash(damage: float) -> void:
	if slash_effect == null:
		return  # 참격 씬이 아직 없으면 공격 애니메이션과 대쉬만 실행
	var effect := slash_effect.instantiate()
	if "damage" in effect:
		effect.damage = damage
	if "target_group" in effect:
		effect.target_group = player_group  # 플레이어에게만 피해를 줌 (플레이어의 take_damage 호출)
	add_child(effect)
	if effect is Node2D:
		effect.scale.x *= _facing_dir()  # 씬에서 정해 둔 크기는 유지하고 방향만 뒤집음


# 땅 솟아오름 투사체를 플레이어 쪽으로 발사. 투사체는 보스의 자식이 아니라 부모(메인 씬)에 생성함
# 일반(RANGED)과 S!(S_RANGED)는 서로 다른 씬을 사용
func _spawn_ground_wave() -> void:
	var is_s: bool = attack_kind == AttackKind.S_RANGED
	var scene: PackedScene = s_projectile if is_s else ranged_projectile
	if scene == null:
		return  # 투사체 씬이 아직 없으면 휘두르는 모션만 실행
	var dir: float = _facing_dir()
	var target := _get_closest_target()
	if target != null:
		var dx: float = target.global_position.x - global_position.x
		if dx != 0.0:
			dir = signf(dx)
	_set_facing(dir)

	var wave := scene.instantiate()
	if "damage" in wave:
		wave.damage = s_damage if is_s else ranged_damage
	if "direction" in wave:
		wave.direction = dir
	if "target_group" in wave:
		wave.target_group = player_group
	get_parent().add_child(wave)
	if wave is Node2D:
		wave.global_position = global_position + Vector2(projectile_spawn_offset.x * dir, projectile_spawn_offset.y)


# 피해를 받음 (플레이어의 공격 이펙트/투사체가 호출). 체력이 바뀌면 health_changed로 체력바가 갱신됨
func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	health = clamp(health - amount, 0.0, max_health)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()


func _die() -> void:
	state = State.DEAD
	velocity.x = 0.0
	targets.clear()
	poison_stacks = 0
	detection_area.set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)  # 죽은 뒤에는 더 이상 공격에 맞지 않음
	died.emit()
	if anim.sprite_frames.has_animation(die_animation):
		anim.sprite_frames.set_animation_loop(die_animation, false)  # 끝나면 사라지도록 반복을 끔
		anim.play(die_animation)
		anim.animation_finished.connect(queue_free, CONNECT_ONE_SHOT)
	else:
		queue_free()


# 독 효과를 받음 (궁극기 투사체가 맞을 때 호출). 맞을 때마다 스택이 쌓이고 지속시간이 갱신됨
func apply_poison(damage_per_stack: float, duration: float, tick_interval: float, max_stacks: int) -> void:
	if state == State.DEAD:
		return
	var was_poisoned: bool = poison_stacks > 0
	poison_damage_per_stack = damage_per_stack
	poison_tick_interval = max(tick_interval, 0.05)
	poison_stacks = mini(poison_stacks + 1, max_stacks)
	poison_time_left = duration
	if not was_poisoned:
		poison_tick_left = poison_tick_interval  # 처음 걸렸을 때만 틱 타이머를 시작


# 독 피해: tick_interval마다 (스택 수 × 스택당 피해) 만큼 들어감. 예) 1스택 2 → 2스택 4 → 3스택 6
func _process_poison(delta: float) -> void:
	if poison_stacks <= 0 or state == State.DEAD:
		return
	poison_time_left -= delta
	poison_tick_left -= delta
	while poison_tick_left <= 0.0 and state != State.DEAD:
		poison_tick_left += poison_tick_interval
		var tick_damage: float = poison_stacks * poison_damage_per_stack
		take_damage(tick_damage)
		poison_ticked.emit(tick_damage, poison_stacks)
		_spawn_poison_effect()
	if poison_time_left <= 0.0:
		poison_stacks = 0


# 독 피해가 들어갈 때마다 독 이펙트(직접 그린 애니메이션)를 보스에게 생성
func _spawn_poison_effect() -> void:
	if poison_effect == null or state == State.DEAD:
		return
	var effect := poison_effect.instantiate()
	add_child(effect)


# ---------- 방향 / 대상 ----------
# dir이 양수면 오른쪽, 음수면 왼쪽을 바라봄
func _set_facing(dir: float) -> void:
	if dir == 0.0:
		return
	var to_right: bool = dir > 0.0
	anim.flip_h = (not to_right) if sprite_faces_right else to_right


# 가장 가까운 플레이어 쪽을 바라봄 (없으면 그대로)
func _face_target() -> void:
	var target := _get_closest_target()
	if target != null:
		_set_facing(target.global_position.x - global_position.x)


# 바라보는 방향: 오른쪽이면 1, 왼쪽이면 -1
func _facing_dir() -> float:
	var looking_left: bool = anim.flip_h if sprite_faces_right else not anim.flip_h
	return -1.0 if looking_left else 1.0


# 감지 범위 안의 플레이어 중 가장 가까운 대상
func _get_closest_target() -> Node2D:
	var closest: Node2D = null
	var best: float = INF
	for t in targets:
		if not is_instance_valid(t):
			continue
		var d: float = global_position.distance_to(t.global_position)
		if d < best:
			best = d
			closest = t
	return closest


# ---------- 애니메이션 ----------
# 해당 애니메이션이 있을 때만, 같은 애니메이션이 이미 재생 중이면 다시 시작하지 않음
func _play(anim_name: StringName) -> void:
	if not anim.sprite_frames.has_animation(anim_name):
		return
	if anim.animation != anim_name or not anim.is_playing():
		anim.play(anim_name)


# primary 애니메이션이 없으면 fallback을 재생
func _play_or(primary: StringName, fallback: StringName) -> void:
	_play(primary if anim.sprite_frames.has_animation(primary) else fallback)


# 같은 애니메이션이어도 처음부터 다시 재생. 재생한 애니메이션 이름을 돌려줌(없으면 빈 이름)
func _play_restart(anim_name: StringName) -> StringName:
	if not anim.sprite_frames.has_animation(anim_name):
		return &""
	anim.stop()
	anim.play(anim_name)
	return anim_name


# 에디터에서 연결된 시그널 함수
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group(player_group) and not targets.has(body):
		targets.append(body)
		if not is_engaged and state != State.DEAD:
			is_engaged = true
			engaged.emit()  # 처음 감지: 체력바 표시


func _on_detection_area_body_exited(body: Node2D) -> void:
	targets.erase(body)
