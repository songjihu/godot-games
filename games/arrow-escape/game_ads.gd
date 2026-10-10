extends Node
signal finished(placement: String, granted: bool, error: String)
var settings: Dictionary = {}
var pending: String = ""
var sdk: Node

func _ready() -> void:
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://config/ads.json"))
	sdk = get_node_or_null("/root/MiniGameSDK")
	if sdk != null:
		sdk.ad_created.connect(_created)
		sdk.rewarded_ad_result.connect(_closed)

func available(placement: String, level_number: int) -> bool:
	return bool(settings.get("enabled",false)) and level_number > int(settings.get("ad_free_levels",10)) and str(settings.get("rewarded_" + placement + "_id","")).begins_with("adunit-") and sdk != null and sdk.is_mini_game

func request(placement: String, level_number: int) -> void:
	if pending != "":
		return
	if not available(placement,level_number):
		finished.emit(placement,false,"暂时没有可用广告，可免费重开")
		return
	pending = placement
	sdk.create_rewarded_ad(str(settings["rewarded_" + placement + "_id"]))

func _created(kind: String, success: bool, error: String) -> void:
	if kind != "rewarded" or pending == "":
		return
	if not success:
		_closed(false,error)
	else:
		sdk.show_rewarded_ad()

func _closed(is_ended: bool, error: String) -> void:
	if pending == "":
		return
	var placement := pending
	pending = ""
	finished.emit(placement,is_ended and error == "",error)
