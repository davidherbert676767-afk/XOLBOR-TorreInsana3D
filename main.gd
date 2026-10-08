extends Node3D

class VirtualJoystick extends Control:
    signal dir_changed(value: Vector2)
    var value := Vector2.ZERO
    var dragging := false
    var radius := 72.0
    var knob_radius := 30.0

    func _ready():
        mouse_filter = Control.MOUSE_FILTER_STOP
        queue_redraw()

    func _draw():
        var center = size * 0.5
        draw_circle(center, radius + 8.0, Color(0.02, 0.02, 0.08, 0.72))
        draw_circle(center, radius, Color(0.10, 0.08, 0.25, 0.88))
        draw_arc(center, radius, 0.0, TAU, 48, Color(0.25, 0.85, 1.0, 0.75), 3.0)
        var knob = center + value * radius
        draw_circle(knob, knob_radius + 5.0, Color(0.03, 0.03, 0.12, 0.9))
        draw_circle(knob, knob_radius, Color(0.30, 0.80, 1.0, 0.95))

    func _gui_input(event):
        if event is InputEventScreenTouch:
            if event.pressed:
                dragging = true
                _update_from_point(event.position)
            else:
                dragging = false
                value = Vector2.ZERO
                dir_changed.emit(value)
                queue_redraw()
            accept_event()
        elif event is InputEventScreenDrag and dragging:
            _update_from_point(event.position)
            accept_event()

    func _update_from_point(p: Vector2):
        var center = size * 0.5
        var delta = p - center
        if delta.length() > radius:
            delta = delta.normalized() * radius
        value = delta / radius
        dir_changed.emit(value)
        queue_redraw()


var player: CharacterBody3D
var camera: Camera3D
var gravity := 22.0
var speed := 7.0
var jump_speed := 10.0
var touch_dir := Vector2.ZERO
var joystick: Control
var avatar_panel: Panel
var settings_panel: Panel
var selected_avatar := 0
var avatars = ["XOLBOR Azul", "XOLBOR Roxo", "XOLBOR Neon"]
var avatar_colors = [Color("4f6cff"), Color("9b5cff"), Color("22d3ee")]
var floor_label: Label

func _ready():
    _make_world()
    _make_player()
    _make_ui()

func mat(c: Color, metallic := 0.0, rough := 0.55) -> StandardMaterial3D:
    var m = StandardMaterial3D.new()
    m.albedo_color = c
    m.metallic = metallic
    m.roughness = rough
    return m

func box(pos: Vector3, size: Vector3, color: Color, block_name := "Block"):
    var b = CSGBox3D.new()
    b.name = block_name
    b.position = pos
    b.size = size
    b.use_collision = true
    b.material = mat(color, 0.15, 0.42)
    add_child(b)
    return b

func _make_world():
    var env = WorldEnvironment.new()
    var e = Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color("09051a")
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("7068c8")
    e.ambient_light_energy = 0.85
    env.environment = e
    add_child(env)

    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50, -28, 0)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    add_child(sun)

    box(Vector3(0, -0.5, 0), Vector3(34, 1, 34), Color("17152d"), "Arena")

    for i in range(24):
        var y = float(i) * 2.2 + 1.0
        var angle = float(i) * 23.0
        var r = 5.0 + float(i % 3) * 0.7
        var x = sin(deg_to_rad(angle)) * r
        var z = cos(deg_to_rad(angle)) * r
        var platform = box(Vector3(x, y, z), Vector3(9, 0.65, 7),
            Color.from_hsv(fmod(0.68 + i * 0.025, 1.0), 0.65, 0.85),
            "TowerLevel_%02d" % (i + 1))
        platform.rotation_degrees.y = angle

        if i % 2 == 1:
            var ox = x + cos(deg_to_rad(angle)) * 2.0
            var oz = z - sin(deg_to_rad(angle)) * 2.0
            box(Vector3(ox, y + 1.4, oz), Vector3(1.2, 2.8, 1.2),
                Color("ff3ca6"), "Obstacle_%02d" % i)

        if i % 3 == 0:
            var rail = box(Vector3(x, y + 1.0, z), Vector3(8.0, 0.3, 0.25),
                Color("37e7ff"), "NeonRail_%02d" % i)
            rail.rotation_degrees.y = angle

    box(Vector3(0, 53.0, 0), Vector3(13, 0.7, 13), Color("f2d65c"), "Goal")

    var goal_light = OmniLight3D.new()
    goal_light.position = Vector3(0, 55, 0)
    goal_light.light_color = Color("37e7ff")
    goal_light.omni_range = 14
    goal_light.light_energy = 7
    add_child(goal_light)

func _make_player():
    player = CharacterBody3D.new()
    player.name = "XOLBOR_Player"
    player.position = Vector3(0, 2.2, 0)
    add_child(player)

    var body = CSGBox3D.new()
    body.size = Vector3(1.2, 1.8, 0.8)
    body.position.y = 0.9
    body.material = mat(avatar_colors[selected_avatar], 0.2, 0.35)
    body.name = "Body"
    player.add_child(body)

    var head = CSGSphere3D.new()
    head.radius = 0.52
    head.height = 1.04
    head.position.y = 2.0
    head.material = mat(Color("d8e7ff"), 0.05, 0.4)
    player.add_child(head)

    var collider = CollisionShape3D.new()
    var shape = CapsuleShape3D.new()
    shape.radius = 0.6
    shape.height = 2.8
    collider.shape = shape
    collider.position.y = 1.4
    player.add_child(collider)

    camera = Camera3D.new()
    camera.position = Vector3(0, 4.2, 7.5)
    camera.current = true
    player.add_child(camera)

func _make_ui():
    var layer = CanvasLayer.new()
    layer.name = "HUD"
    add_child(layer)

    var info = Panel.new()
    info.position = Vector2(24, 20)
    info.size = Vector2(300, 78)
    layer.add_child(info)

    var title = Label.new()
    title.text = "TORRE INSANA"
    title.position = Vector2(18, 10)
    title.add_theme_font_size_override("font_size", 24)
    info.add_child(title)

    floor_label = Label.new()
    floor_label.text = "Andar: 1 / 24"
    floor_label.position = Vector2(18, 43)
    floor_label.add_theme_font_size_override("font_size", 18)
    info.add_child(floor_label)

    var avatar_btn = Button.new()
    avatar_btn.text = "PERSONAGEM"
    avatar_btn.position = Vector2(1015, 20)
    avatar_btn.size = Vector2(220, 56)
    avatar_btn.add_theme_font_size_override("font_size", 18)
    avatar_btn.pressed.connect(_toggle_avatar)
    layer.add_child(avatar_btn)

    var settings_btn = Button.new()
    settings_btn.text = "CONFIGURAÇÕES"
    settings_btn.position = Vector2(1015, 88)
    settings_btn.size = Vector2(220, 56)
    settings_btn.add_theme_font_size_override("font_size", 18)
    settings_btn.pressed.connect(_toggle_settings)
    layer.add_child(settings_btn)

    var exit_btn = Button.new()
    exit_btn.text = "SAIR"
    exit_btn.position = Vector2(1015, 156)
    exit_btn.size = Vector2(220, 52)
    exit_btn.add_theme_font_size_override("font_size", 18)
    exit_btn.pressed.connect(func(): get_tree().quit())
    layer.add_child(exit_btn)

    joystick = VirtualJoystick.new()
    joystick.position = Vector2(28, 510)
    joystick.size = Vector2(190, 190)
    joystick.dir_changed.connect(func(v): touch_dir = v)
    layer.add_child(joystick)

    var jump = Button.new()
    jump.text = "PULAR"
    jump.position = Vector2(1040, 540)
    jump.size = Vector2(190, 105)
    jump.add_theme_font_size_override("font_size", 24)
    jump.pressed.connect(_jump)
    layer.add_child(jump)

    _build_avatar_panel(layer)
    _build_settings_panel(layer)

func _build_avatar_panel(layer):
    avatar_panel = Panel.new()
    avatar_panel.position = Vector2(780, 220)
    avatar_panel.size = Vector2(420, 230)
    avatar_panel.visible = false
    layer.add_child(avatar_panel)

    var label = Label.new()
    label.name = "AvatarLabel"
    label.text = "PERSONAGEM\n" + avatars[selected_avatar]
    label.position = Vector2(25, 20)
    label.add_theme_font_size_override("font_size", 24)
    avatar_panel.add_child(label)

    var next = Button.new()
    next.text = "TROCAR PERSONAGEM"
    next.position = Vector2(25, 110)
    next.size = Vector2(360, 62)
    next.add_theme_font_size_override("font_size", 20)
    next.pressed.connect(_next_avatar)
    avatar_panel.add_child(next)

    var close = Button.new()
    close.text = "FECHAR"
    close.position = Vector2(25, 180)
    close.size = Vector2(120, 38)
    close.pressed.connect(func(): avatar_panel.visible = false)
    avatar_panel.add_child(close)

func _build_settings_panel(layer):
    settings_panel = Panel.new()
    settings_panel.position = Vector2(780, 220)
    settings_panel.size = Vector2(420, 230)
    settings_panel.visible = false
    layer.add_child(settings_panel)

    var label = Label.new()
    label.text = "CONFIGURAÇÕES\n\nControles: joystick + PULAR\nCâmera: arraste na tela\nModo: Torre Insana 3D"
    label.position = Vector2(25, 20)
    label.add_theme_font_size_override("font_size", 20)
    settings_panel.add_child(label)

    var close = Button.new()
    close.text = "FECHAR"
    close.position = Vector2(25, 180)
    close.size = Vector2(120, 38)
    close.pressed.connect(func(): settings_panel.visible = false)
    settings_panel.add_child(close)

func _toggle_avatar():
    avatar_panel.visible = not avatar_panel.visible
    settings_panel.visible = false

func _toggle_settings():
    settings_panel.visible = not settings_panel.visible
    avatar_panel.visible = false

func _next_avatar():
    selected_avatar = (selected_avatar + 1) % avatars.size()
    var body = player.get_node("Body") as CSGBox3D
    body.material = mat(avatar_colors[selected_avatar], 0.2, 0.35)
    var label = avatar_panel.get_node("AvatarLabel") as Label
    label.text = "PERSONAGEM\n" + avatars[selected_avatar]

func _jump():
    if player and player.is_on_floor():
        player.velocity.y = jump_speed

func _physics_process(delta):
    if not player:
        return

    var keyboard = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var dir2 = keyboard

    if touch_dir.length() > 0.08:
        dir2 = touch_dir

    var dir = Vector3(dir2.x, 0, dir2.y)

    if dir.length() > 1.0:
        dir = dir.normalized()

    player.velocity.x = dir.x * speed
    player.velocity.z = dir.z * speed

    if not player.is_on_floor():
        player.velocity.y -= gravity * delta

    if Input.is_action_just_pressed("jump"):
        _jump()

    player.move_and_slide()
    camera.look_at(player.global_position + Vector3(0, 1.2, 0))

    var floor_num = clampi(int(floor(player.position.y / 2.2)) + 1, 1, 24)

    if floor_label:
        floor_label.text = "Andar: %d / 24" % floor_num

    if player.position.y < -8:
        player.position = Vector3(0, 2.2, 0)
        player.velocity = Vector3.ZERO
