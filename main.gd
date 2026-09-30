extends Node3D

var player: CharacterBody3D
var camera: Camera3D
var gravity := 22.0
var speed := 7.0
var jump_speed := 10.5
var level := 1
var coins := 0
var checkpoint := Vector3(0, 3, 0)
var ui_level: Label
var ui_coins: Label
var joystick := Vector2.ZERO
var touch_jump := false
var camera_yaw := 0.0
var camera_pitch := -16.0
var moving_platforms: Array[Dictionary] = []

func _ready():
    _make_world()
    _make_player()
    _make_ui()

func mat(c: Color, metallic := 0.0, rough := 0.5, emission := Color.TRANSPARENT) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.metallic = metallic
    m.roughness = rough
    if emission != Color.TRANSPARENT:
        m.emission_enabled = true
        m.emission = emission
        m.emission_energy_multiplier = 2.5
    return m

func box(pos: Vector3, size: Vector3, color: Color, node_name := "Block", parent: Node = self) -> StaticBody3D:
    var b := StaticBody3D.new()
    b.name = node_name
    b.position = pos
    parent.add_child(b)
    var mesh := MeshInstance3D.new()
    var shape_mesh := BoxMesh.new()
    shape_mesh.size = size
    mesh.mesh = shape_mesh
    mesh.material_override = mat(color, 0.2, 0.38)
    b.add_child(mesh)
    var col := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    col.shape = shape
    b.add_child(col)
    return b

func _make_world():
    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("050414")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("5f63aa")
    env.ambient_light_energy = 0.72
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.glow_enabled = true
    env.glow_intensity = 1.1
    env_node.environment = env
    add_child(env_node)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -32, 0)
    sun.light_energy = 1.3
    sun.shadow_enabled = true
    add_child(sun)

    # Large arena floor and glowing border.
    box(Vector3(0,-1,0), Vector3(70,2,70), Color("101026"), "ArenaFloor")
    for p in [Vector3(0,0,-32),Vector3(0,0,32),Vector3(-32,0,0),Vector3(32,0,0)]:
        var rail := box(p, Vector3(70,0.35,0.35) if abs(p.x) < 1 else Vector3(0.35,0.35,70), Color("24dcff"), "ArenaNeon")

    # 24-floor tower with varied shapes, hazards and checkpoints.
    for i in range(24):
        var y := float(i) * 2.55 + 1.0
        var angle := float(i) * 31.0
        var r := 5.0 + float(i % 4) * 0.8
        var center := Vector3(sin(deg_to_rad(angle))*r, y, cos(deg_to_rad(angle))*r)
        var size := Vector3(8.5 - float(i%3)*0.6, 0.65, 7.0 - float(i%2)*0.5)
        var col := Color.from_hsv(fmod(0.70 + i*0.018,1.0),0.72,0.9)
        var platform := box(center,size,col,"TowerFloor_%02d" % i)
        platform.rotation_degrees.y = angle

        if i % 2 == 1:
            for j in range(2):
                var off := Vector3(cos(deg_to_rad(angle))*((j-0.5)*3.0),1.35,sin(deg_to_rad(angle))*((j-0.5)*3.0))
                var hazard := box(center+off,Vector3(1.0,2.7,1.0),Color("ff2e91"),"LaserPillar")
                var glow := OmniLight3D.new()
                glow.position = center+off+Vector3(0,1.5,0)
                glow.light_color = Color("ff2e91")
                glow.omni_range = 5
                glow.light_energy = 2.5
                add_child(glow)
        if i % 3 == 0:
            var bar := box(center+Vector3(0,1.05,0),Vector3(7.0,0.22,0.22),Color("22e6ff"),"NeonBar")
            bar.rotation_degrees.y = angle+90
        if i % 4 == 0 and i > 0:
            _make_checkpoint(center + Vector3(0,0.7,0), i+1)
        if i % 5 == 0:
            _make_coin(center+Vector3(0,1.5,0), i)

    # Moving platforms near the upper floors.
    for i in range(4):
        var p := box(Vector3(10 + i*3, 8+i*4, -4+i*2), Vector3(4,0.5,4), Color("7c55ff"), "MovingPlatform")
        moving_platforms.append({"node":p,"origin":p.position,"phase":float(i)*1.3})

    # Goal tower and beacon.
    box(Vector3(0,62.2,0),Vector3(14,0.8,14),Color("f4d84e"),"Goal")
    var beacon := OmniLight3D.new()
    beacon.position = Vector3(0,66,0)
    beacon.light_color = Color("36e8ff")
    beacon.omni_range = 20
    beacon.light_energy = 8
    add_child(beacon)
    var goal_ring := CSGTorus3D.new()
    goal_ring.position = Vector3(0,65,0)
    goal_ring.inner_radius = 2.2
    goal_ring.outer_radius = 2.45
    goal_ring.material = mat(Color("ff39b9"),0.5,0.2,Color("ff39b9"))
    add_child(goal_ring)

func _make_checkpoint(pos: Vector3, n: int):
    var pad := box(pos,Vector3(3,0.18,3),Color("29e6ff"),"Checkpoint_%02d" % n)
    pad.set_meta("checkpoint",true)
    var light := OmniLight3D.new()
    light.position = pos+Vector3(0,1.2,0)
    light.light_color = Color("29e6ff")
    light.omni_range = 5
    light.light_energy = 3
    add_child(light)

func _make_coin(pos: Vector3, idx: int):
    var coin := CSGCylinder3D.new()
    coin.name = "Coin_%02d" % idx
    coin.position = pos
    coin.height = 0.22
    coin.radius = 0.55
    coin.material = mat(Color("6feaff"),0.8,0.18,Color("6feaff"))
    add_child(coin)

func _make_player():
    player = CharacterBody3D.new()
    player.name = "XOLBOR_Player"
    player.position = checkpoint
    add_child(player)

    var body := MeshInstance3D.new()
    var bm := CapsuleMesh.new()
    bm.radius = 0.55
    bm.height = 1.65
    body.mesh = bm
    body.position.y = 1.05
    body.material_override = mat(Color("4779ff"),0.25,0.3,Color("152cff"))
    player.add_child(body)

    var head := MeshInstance3D.new()
    var hm := SphereMesh.new()
    hm.radius = 0.48
    hm.height = 0.96
    head.mesh = hm
    head.position.y = 2.15
    head.material_override = mat(Color("d9ecff"),0.05,0.35)
    player.add_child(head)

    # XOLBOR-style visor.
    var visor := MeshInstance3D.new()
    var vm := BoxMesh.new()
    vm.size = Vector3(0.58,0.18,0.12)
    visor.mesh = vm
    visor.position = Vector3(0,2.16,-0.43)
    visor.material_override = mat(Color("32e7ff"),0.6,0.15,Color("32e7ff"))
    player.add_child(visor)

    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.55
    capsule.height = 2.8
    collider.shape = capsule
    collider.position.y = 1.4
    player.add_child(collider)

    camera = Camera3D.new()
    camera.position = Vector3(0,4.2,7.8)
    camera.rotation_degrees = Vector3(camera_pitch,180,0)
    camera.current = true
    camera.fov = 68
    player.add_child(camera)

func _make_ui():
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := ColorRect.new()
    panel.position = Vector2(18,18)
    panel.size = Vector2(290,88)
    panel.color = Color(0.02,0.02,0.08,0.82)
    layer.add_child(panel)
    var title := Label.new()
    title.position = Vector2(32,25)
    title.text = "🗼 TORRE INSANA"
    title.add_theme_font_size_override("font_size",26)
    layer.add_child(title)
    ui_level = Label.new()
    ui_level.position = Vector2(32,58)
    ui_level.text = "Andar: 1 / 24"
    ui_level.add_theme_font_size_override("font_size",18)
    layer.add_child(ui_level)
    ui_coins = Label.new()
    ui_coins.position = Vector2(185,58)
    ui_coins.text = "◆ 0"
    ui_coins.add_theme_font_size_override("font_size",18)
    layer.add_child(ui_coins)

    var hint := Label.new()
    hint.position = Vector2(20,670)
    hint.text = "WASD / joystick • Espaço / PULAR • arraste para olhar"
    hint.add_theme_font_size_override("font_size",16)
    layer.add_child(hint)

    # Mobile controls.
    var left := Button.new(); left.text="◀"; left.position=Vector2(35,540); left.size=Vector2(70,70); layer.add_child(left)
    var right := Button.new(); right.text="▶"; right.position=Vector2(185,540); right.size=Vector2(70,70); layer.add_child(right)
    var forward := Button.new(); forward.text="▲"; forward.position=Vector2(110,500); forward.size=Vector2(70,70); layer.add_child(forward)
    var back := Button.new(); back.text="▼"; back.position=Vector2(110,580); back.size=Vector2(70,70); layer.add_child(back)
    var jump := Button.new(); jump.text="PULAR"; jump.position=Vector2(1080,565); jump.size=Vector2(150,80); layer.add_child(jump)
    left.button_down.connect(func(): joystick.x=-1); left.button_up.connect(func(): joystick.x=0)
    right.button_down.connect(func(): joystick.x=1); right.button_up.connect(func(): joystick.x=0)
    forward.button_down.connect(func(): joystick.y=-1); forward.button_up.connect(func(): joystick.y=0)
    back.button_down.connect(func(): joystick.y=1); back.button_up.connect(func(): joystick.y=0)
    jump.button_down.connect(func(): touch_jump=true); jump.button_up.connect(func(): touch_jump=false)

func _physics_process(delta):
    if not player: return
    var input_vec := Input.get_vector("move_left","move_right","move_forward","move_back")
    if joystick.length() > 0.1:
        input_vec = joystick
    var direction := Vector3(input_vec.x,0,input_vec.y)
    if direction.length() > 0.1:
        direction = direction.normalized()
        player.velocity.x = direction.x * speed
        player.velocity.z = direction.z * speed
        player.rotation.y = lerp_angle(player.rotation.y, atan2(direction.x,direction.z), delta*8.0)
    else:
        player.velocity.x = move_toward(player.velocity.x,0,speed*7*delta)
        player.velocity.z = move_toward(player.velocity.z,0,speed*7*delta)
    if not player.is_on_floor(): player.velocity.y -= gravity*delta
    else:
        if Input.is_action_just_pressed("jump") or touch_jump: player.velocity.y=jump_speed
    player.move_and_slide()
    if player.position.y < -8:
        player.position = checkpoint
        player.velocity = Vector3.ZERO
    level = clamp(int(player.position.y / 2.55)+1,1,24)
    ui_level.text = "Andar: %d / 24" % level
    ui_coins.text = "◆ %d" % coins
    for item in moving_platforms:
        var n: Node3D = item.node
        var o: Vector3 = item.origin
        var ph: float = item.phase
        n.position = o + Vector3(sin(Time.get_ticks_msec()/1000.0+ph)*3.5,0,cos(Time.get_ticks_msec()/1200.0+ph)*2.5)

func _unhandled_input(event):
    if event is InputEventScreenDrag:
        player.rotate_y(-event.relative.x*0.006)
        camera_pitch = clamp(camera_pitch-event.relative.y*0.08,-55.0,20.0)
        camera.rotation_degrees.x = camera_pitch
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        player.rotate_y(-event.relative.x*0.004)
        camera_pitch = clamp(camera_pitch-event.relative.y*0.05,-55.0,20.0)
        camera.rotation_degrees.x = camera_pitch
