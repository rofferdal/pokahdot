class_name GuiCompositionState
extends RefCounted

## One detached policy snapshot per presentation operation. No game or UI nodes.
enum Status { WAITING, GUIDANCE, READY, UNREGISTERED, INVALID_COMPOSITION, CONTENT_MINIMUM }

var geometry: GuiViewportGeometry
var fit: GuiFitPolicy
var status: Status = Status.WAITING
var mode: GuiSizeClass.LayoutMode = GuiSizeClass.LayoutMode.NOT_READY
var density: GuiFitCandidate.Density = GuiFitCandidate.Density.COMPACT
var action_flow: GuiFitCandidate.ActionFlow = GuiFitCandidate.ActionFlow.TWO_ROWS
var seats: GuiSeatRows
var guidance: String = ""


static func from_fit(value: GuiViewportGeometry, policy: GuiFitPolicy) -> GuiCompositionState:
	var result := GuiCompositionState.new()
	result.geometry = value
	result.fit = policy
	result.guidance = policy.guidance
	if policy.status != GuiFitPolicy.Status.FIT:
		result.status = (
			Status.WAITING if policy.status == GuiFitPolicy.Status.NOT_READY else Status.GUIDANCE
		)
		return result
	result.status = Status.READY
	result.mode = policy.selected.mode
	result.density = policy.selected.density
	result.action_flow = policy.selected.action_flow
	result.seats = policy.selected.seats
	return result
