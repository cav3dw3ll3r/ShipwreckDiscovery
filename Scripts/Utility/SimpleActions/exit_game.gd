extends SimpleAction
class_name ExitGameAction

func do() -> void:
	SaveLoad.save_all()
	get_tree().quit()
