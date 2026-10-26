## The grade ids. The numbers match "id" in content/grades.json and are what
## the save file stores. Grade rules (dice counts, ranges) live in that JSON.
class_name Grades
extends RefCounted

enum Grade { ACORN = 1, SPROUT = 2, SAPLING = 3, OAK = 4 }

const NAMES := {
	Grade.ACORN: "Acorn",
	Grade.SPROUT: "Sprout",
	Grade.SAPLING: "Sapling",
	Grade.OAK: "Oak",
}


static func name_of(grade: int) -> String:
	return NAMES.get(grade, "?")
