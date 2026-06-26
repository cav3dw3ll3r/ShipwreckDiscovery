extends Node3D
class_name LiteWeather

# LITE Weather System:
# Intended to drive reasonably nice looking weather
# with minimal performance impact for quest. 
# instead of sampling large textures, weather lite
# drives flat billboarded meshes for the following:
# Low Clouds: Billboarded cloud images on meshes
# High Clouds: One canvas item shader with a circular
#              mask that points straight down and follows
#              over the players 
