extends RefCounted
## Shared, side-effect-free work eligibility for actor, props and conversation.
## The scene separately withholds work presentation while paused or conversing.

const PHASES := ["bench", "shelf", "yard", "terrace"]


static func work_site(status: Dictionary, view: Dictionary) -> String:
	# Do not coerce missing values, numbers or strings into valid state flags.
	for key in ["id", "phase", "goal", "blocked"]:
		if typeof(status.get(key)) != TYPE_STRING:
			return ""
	if status["id"] != "workshop_resident" or typeof(status.get("moving")) != TYPE_BOOL:
		return ""
	if status["moving"] or status["blocked"] != "":
		return ""
	var phase: String = status["phase"]
	var goal: String = status["goal"]
	# During travel goal equals phase. A different valid goal projects a dwell.
	if not ["bench", "yard"].has(phase) or not PHASES.has(goal) or goal == phase:
		return ""
	if typeof(view.get("toolbox_anchor")) != TYPE_STRING or view["toolbox_anchor"] != phase:
		return ""
	if phase == "bench" and (typeof(view.get("lamp_on")) != TYPE_BOOL or not view["lamp_on"]):
		return ""
	return phase
