extends MarginContainer

@export var thisLocaleCommunityDataPath: String
@export var fileName: String
@onready var listingContainer = $ScrollContainer/VBoxContainer
@onready var supporterListingPrefab = preload("res://Prefabs/UI/supporter_listing.tscn")

var communityDictionary: Dictionary = {}

func _ready():
	# Open the CSV file for reading
	var file = FileAccess.open(thisLocaleCommunityDataPath+"/"+fileName, FileAccess.READ)
	if file:
		var header = file.get_line().strip_edges()  # Read the header line
		var keys = header.split("\t")  # Split the header into keys
		while not file.eof_reached():
			var line = file.get_line().strip_edges()
			if line == "":  # Skip empty lines
				continue
			var values = line.split("\t")  # Split the line into values
			var row_data = {}
			for i in range(len(keys)):
				row_data[keys[i]] = values[i]  # Map keys to values
			communityDictionary[row_data["Name"]]=row_data
		file.close()
	else:
		push_error("Failed to open file: " + thisLocaleCommunityDataPath)
	
	for listingKey in communityDictionary:
		var busName = communityDictionary[listingKey]["Name"]
		var desc = communityDictionary[listingKey]["Description"]
		var iconPath = communityDictionary[listingKey]["Icon"]
		var listing = supporterListingPrefab.instantiate()
		listingContainer.add_child(listing)
		listing.set_supporter_listing_params(busName,desc,thisLocaleCommunityDataPath+"/icons/"+iconPath)
		pass
