@icon("res://addons/dialogue_manager/assets/responses_menu.svg")

## EchoChase 的对白选项布局：长列表分页，结束项固定在分页框外。
class_name EchoDialogueResponsesMenu extends ProjectDialogueResponsesMenu

@export_range(2, 12, 1) var carousel_threshold: int = 5
@export_range(2, 8, 1) var page_size: int = 4

@onready var normal_responses: VBoxContainer = %NormalResponses
@onready var carousel_frame: PanelContainer = %CarouselFrame
@onready var carousel_responses: VBoxContainer = %CarouselResponses
@onready var pinned_responses: VBoxContainer = %PinnedResponses
@onready var previous_page_button: Button = %PreviousPageButton
@onready var next_page_button: Button = %NextPageButton
@onready var page_indicator: Label = %PageIndicator

var _normal_response_data: Array[DialogueResponse] = []
var _pinned_response_data: Array[DialogueResponse] = []
var _page_items: Array[Control] = []
var _pinned_items: Array[Control] = []
var _page_index: int = 0
var _item_serial: int = 0


## Wire the authored page controls and render any responses assigned before ready.
func _ready() -> void:
	super._ready()
	previous_page_button.pressed.connect(_on_previous_page_pressed)
	next_page_button.pressed.connect(_on_next_page_pressed)
	_apply_responses()


## Return only the currently visible dialogue response buttons for focus handling.
func get_menu_items() -> Array:
	var items: Array = []
	for item in _page_items:
		if is_instance_valid(item) and item.visible:
			items.append(item)
	for item in _pinned_items:
		if is_instance_valid(item) and item.visible:
			items.append(item)
	return items


## Arrange vertical focus and connect the inherited response input handlers.
func configure_focus() -> void:
	var items: Array = get_menu_items()
	if items.is_empty():
		_previously_focused_item = null
		return

	for index in items.size():
		var item: Control = items[index]
		var previous: Control = items[index - 1] if index > 0 else item
		var following: Control = items[index + 1] if index + 1 < items.size() else item
		item.focus_mode = Control.FOCUS_ALL
		item.focus_neighbor_top = previous.get_path()
		item.focus_neighbor_bottom = following.get_path()
		item.focus_previous = previous.get_path()
		item.focus_next = following.get_path()
		item.focus_neighbor_left = item.get_path()
		item.focus_neighbor_right = item.get_path()
		if carousel_frame.visible and index < _page_items.size():
			if index == 0 and not previous_page_button.disabled:
				item.focus_neighbor_left = previous_page_button.get_path()
			if index == _page_items.size() - 1 and not next_page_button.disabled:
				item.focus_neighbor_right = next_page_button.get_path()
		if not item.mouse_entered.is_connected(_on_response_mouse_entered):
			item.mouse_entered.connect(_on_response_mouse_entered.bind(item))
		if not item.gui_input.is_connected(_on_response_gui_input):
			item.gui_input.connect(_on_response_gui_input.bind(item, item.get_meta("response")))

	_configure_page_button_focus(items)
	_previously_focused_item = items[0]
	if auto_focus_first_item:
		items[0].grab_focus()


#region Rendering


## Split allowed responses into ordinary and fixed end-of-conversation choices.
func _apply_responses() -> void:
	if not is_node_ready():
		return

	_normal_response_data.clear()
	_pinned_response_data.clear()
	for response_variant in responses:
		var response: DialogueResponse = response_variant
		if hide_failed_responses and not response.is_allowed:
			continue
		if _is_pinned_response(response):
			_pinned_response_data.append(response)
		else:
			_normal_response_data.append(response)

	_page_index = 0
	_item_serial = 0
	_clear_response_items(normal_responses, response_template)
	_clear_response_items(carousel_responses)
	_clear_response_items(pinned_responses)
	_page_items.clear()
	_pinned_items.clear()

	var use_carousel := _normal_response_data.size() > carousel_threshold
	normal_responses.visible = not use_carousel and not _normal_response_data.is_empty()
	carousel_frame.visible = use_carousel
	pinned_responses.visible = not _pinned_response_data.is_empty()

	if use_carousel:
		_render_carousel_page()
	else:
		for response in _normal_response_data:
			_page_items.append(_add_response_item(response, normal_responses))

	for response in _pinned_response_data:
		_pinned_items.append(_add_response_item(response, pinned_responses))

	_update_page_controls(use_carousel)
	if auto_configure_focus:
		configure_focus()


## Rebuild the visible page while preserving the authored response template.
func _render_carousel_page() -> void:
	_clear_response_items(carousel_responses)
	_page_items.clear()
	var first_index := _page_index * page_size
	var last_index := mini(first_index + page_size, _normal_response_data.size())
	for index in range(first_index, last_index):
		_page_items.append(_add_response_item(_normal_response_data[index], carousel_responses))
	_update_page_controls(true)


## Duplicate the authored response button and attach its DialogueResponse metadata.
func _add_response_item(response: DialogueResponse, container: Container) -> Control:
	var item := response_template.duplicate(DUPLICATE_GROUPS | DUPLICATE_SCRIPTS | DUPLICATE_SIGNALS) as Control
	item.name = "Response%d" % _item_serial
	_item_serial += 1
	item.show()
	if "response" in item:
		item.response = response
	else:
		item.text = response.text
	item.set_meta("response", response)
	container.add_child(item)
	return item


## Remove generated response buttons but keep authored templates intact.
func _clear_response_items(container: Container, template: Control = null) -> void:
	for child in container.get_children():
		if child == template or child.is_queued_for_deletion():
			continue
		container.remove_child(child)
		child.queue_free()


## Treat terminal dialogue targets as fixed choices outside the carousel.
func _is_pinned_response(response: DialogueResponse) -> bool:
	var target_id := response.next_id.split("|")[0]
	return target_id in [DMConstants.ID_END, DMConstants.ID_END_CONVERSATION]


## Update arrows and page text only when the long-list carousel is active.
func _update_page_controls(use_carousel: bool) -> void:
	previous_page_button.visible = use_carousel
	next_page_button.visible = use_carousel
	page_indicator.visible = use_carousel
	if not use_carousel:
		return
	var total_pages := maxi(1, ceili(float(_normal_response_data.size()) / float(page_size)))
	previous_page_button.disabled = _page_index <= 0
	next_page_button.disabled = _page_index >= total_pages - 1
	page_indicator.text = "%d / %d" % [_page_index + 1, total_pages]


## Keep the arrow buttons reachable without making them response choices.
func _configure_page_button_focus(items: Array) -> void:
	if not carousel_frame.visible or items.is_empty():
		return
	var first_item: Control = _page_items.front() if not _page_items.is_empty() else items.front()
	var last_item: Control = _page_items.back() if not _page_items.is_empty() else items.front()
	previous_page_button.focus_mode = Control.FOCUS_ALL if not previous_page_button.disabled else Control.FOCUS_NONE
	next_page_button.focus_mode = Control.FOCUS_ALL if not next_page_button.disabled else Control.FOCUS_NONE
	previous_page_button.focus_neighbor_right = first_item.get_path()
	previous_page_button.focus_neighbor_bottom = first_item.get_path()
	previous_page_button.focus_neighbor_left = previous_page_button.get_path()
	previous_page_button.focus_neighbor_top = previous_page_button.get_path()
	next_page_button.focus_neighbor_left = last_item.get_path()
	next_page_button.focus_neighbor_bottom = last_item.get_path()
	next_page_button.focus_neighbor_right = next_page_button.get_path()
	next_page_button.focus_neighbor_top = next_page_button.get_path()


#endregion

#region Paging


## Move one page toward the beginning of the response list.
func _on_previous_page_pressed() -> void:
	if _page_index <= 0:
		return
	_page_index -= 1
	_render_carousel_page()
	configure_focus()


## Move one page toward the end of the response list.
func _on_next_page_pressed() -> void:
	var total_pages := maxi(1, ceili(float(_normal_response_data.size()) / float(page_size)))
	if _page_index >= total_pages - 1:
		return
	_page_index += 1
	_render_carousel_page()
	configure_focus()


#endregion
