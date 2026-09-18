extends Node

const Metadata = preload("res://debug/build_metadata.gd")

func is_development() -> bool:
	return Metadata.BUILD_TYPE == "dev"

func version() -> String:
	return "v%s" % Metadata.VERSION

func build_type() -> String:
	return Metadata.BUILD_TYPE

func commit() -> String:
	return Metadata.COMMIT_SHA

func built_at() -> String:
	return Metadata.BUILD_TIMESTAMP if not Metadata.BUILD_TIMESTAMP.is_empty() else "local"

func compact_label() -> String:
	return "DEV · %s" % commit()
