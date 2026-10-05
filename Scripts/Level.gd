extends Node3D

# Root script for each level scene.

@export var level_index := 0
@export var title := "Level"
@export var subtitle := ""

func _ready():
	GameManager.level_started(level_index)
	$UserInterface/GameUI.show_level_title(title, subtitle)
