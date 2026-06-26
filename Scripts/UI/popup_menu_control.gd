extends Node3D

class_name FrontMenu

@onready var menuRoot = $PopupMenu
@onready var contentArea = $PopupMenu/Viewport/MainMenu/MenuPanel/HBoxContainer/ContentArea
@onready var player_cam = get_tree().get_first_node_in_group("Player")

var last_scanned:Scannable

signal on_close

func _ready() -> void:
	closeMenu()
	ground_menu($"../Environment/HomeBase")
	call_deferred("registerCloseBtn")

func ground_menu(anchor:Node3D):
	pass
	#reparent(anchor)

func registerCloseBtn():
	var closeButton = $PopupMenu/Viewport/MainMenu/MenuPanel/HBoxContainer/ButtonHolder/CloseButton
	closeButton.pressed.connect(closeMenu)

func closeMenu():
	menuRoot.enabled=false
	menuRoot.visible=false
	if len(contentArea.get_children())<=0: return
	if contentArea.get_child(0):
		if(contentArea.get_child(0).has_method("on_close")):
			contentArea.get_child(0).on_close()
	emit_signal("on_close")

func displayMenu(menu: PackedScene) -> void:
	global_rotation.y = player_cam.global_rotation.y

	var forward = -player_cam.global_transform.basis.z.normalized()
	forward.y = 0
	var distance = 4.0
	global_position = player_cam.global_transform.origin + forward * distance

	menuRoot.enabled = true
	menuRoot.visible = true

	# free children deferred
	for child in contentArea.get_children():
		child.queue_free()

	await get_tree().process_frame
	call_deferred("setup_menu_node",menu)

func setup_menu_node(menu:PackedScene):
	var menuNode = menu.instantiate()
	contentArea.add_child(menuNode)
	if menuNode.has_method("add_dynamic_scan_content"):
		menuNode.add_dynamic_scan_content(last_scanned)
