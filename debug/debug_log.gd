extends Node

const MAX_EVENTS := 10

var _events: Array[String] = []

func event(title: String, detail: String = "") -> void:
	if not BuildInfo.is_development():
		return
	var message := title
	if not detail.is_empty():
		message += ": %s" % detail
	_events.append("%.2f %s" % [Time.get_ticks_msec() / 1000.0, message])
	if _events.size() > MAX_EVENTS:
		_events.pop_front()

func recent_events() -> Array[String]:
	return _events.duplicate()
