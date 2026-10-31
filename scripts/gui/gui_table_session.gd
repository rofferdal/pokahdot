class_name GuiTableSession
extends RefCounted

## Recipient-safe GUI session. Core owns rules; this adapter owns presentation pacing.
signal changed

var _match: TournamentMatch
var _recipient: int = Table.NO_SEAT
var _view: GameView
var _avatars: Dictionary[int, String] = {}
var _names: Dictionary[int, String] = {}
var _latest: Dictionary[int, PublicActionRecord] = {}
var _folds: Dictionary[int, PublicActionRecord] = {}
var _lines: Array[String] = []
var _last_result := StepResult.new(StepResult.Status.WAITING_FOR_HUMAN)
var _feedback: String = ""
var _pacer := GuiActionPacer.new()
var _hold_advance: Callable
var _input_blocked: Callable
var _configured: bool = false
var _epoch: int = 0
var _held_pending: bool = false


func configure(
	tree: SceneTree,
	timing: Resource,
	hold_advance: Callable = Callable(),
	input_blocked: Callable = Callable()
) -> void:
	_configured = tree != null
	_pacer.configure(tree, timing)
	_hold_advance = hold_advance
	_input_blocked = input_blocked
	if _match != null and not is_advance_pending():
		_schedule_latest()


func bind_match(
	match_instance: TournamentMatch,
	recipient: int,
	avatars: Dictionary[int, String],
	names: Dictionary[int, String] = {}
) -> bool:
	stop()
	_clear_binding()
	if match_instance == null:
		_fail("A GUI session requires a TournamentMatch.")
		return false
	var view: GameView = match_instance.get_view_for(recipient)
	if view == null:
		_fail("The tournament has no public view for this recipient.")
		return false
	_match = match_instance
	_recipient = recipient
	_avatars = avatars.duplicate()
	_names = names.duplicate()
	_feedback = ""
	_last_result = StepResult.new(StepResult.Status.WAITING_FOR_HUMAN)
	var epoch: int = _epoch
	if not refresh():
		return false
	if epoch == _epoch:
		_schedule_latest()
	return true


func bind_view(
	view: GameView,
	avatars: Dictionary[int, String],
	names: Dictionary[int, String] = {},
	event_lines: Array[String] = []
) -> bool:
	stop()
	_clear_binding()
	if view == null:
		_fail("A GUI session requires a recipient-safe view.")
		return false
	_view = view
	_recipient = view.hero_seat
	_avatars = avatars.duplicate()
	_names = names.duplicate()
	_lines = event_lines.duplicate()
	_latest.clear()
	_folds.clear()
	for record: PublicActionRecord in view.action_history:
		_latest[record.seat] = record
		if (
			record.record_kind == PublicActionRecord.Kind.ACTION
			and record.kind == PlayerAction.Kind.FOLD
		):
			_folds[record.seat] = record
	_feedback = ""
	_last_result = StepResult.new(StepResult.Status.WAITING_FOR_HUMAN)
	changed.emit()
	return true


func get_view() -> GameView:
	return _view


func get_model(density: GuiFitCandidate.Density = GuiFitCandidate.Density.FULL) -> TableViewModel:
	var model: TableViewModel = TableViewModel.build(
		_view, _names, _avatars, _latest, _folds, _lines, density
	)
	if model.valid and not _feedback.is_empty():
		model.actions.status_text = _feedback
		model.actions.phone_status_text = _feedback
	return model


func get_feedback() -> String:
	return _feedback


func refresh() -> bool:
	if _match == null:
		return _view != null
	var next: GameView = _match.get_view_for(_recipient)
	if next == null:
		_fail("The tournament has no public view for this recipient.")
		return false
	_view = next
	_rebuild_events(_match.get_events())
	changed.emit()
	return true


func submit_intent(intent: StringName, raw_draft: String = "") -> StepResult:
	if not _can_submit():
		return _fail("Actions are unavailable while the session is stopped or a dialog is open.")
	return _dispatch_intent(intent, raw_draft)


func _dispatch_intent(intent: StringName, raw_draft: String) -> StepResult:
	var action: PlayerAction
	match intent:
		&"fold":
			action = PlayerAction.fold_action()
		&"check_call":
			if PlayerAction.Kind.CHECK in _view.legal_actions:
				action = PlayerAction.check_action()
			elif PlayerAction.Kind.CALL in _view.legal_actions:
				action = PlayerAction.call_action()
		&"minimum":
			return submit_wager_total(_view.minimum_wager_total)
		&"pot":
			var target: PotWagerTargetResult = ActionBarViewModel.resolve_pot_target(_view)
			if target.available:
				return submit_wager_total(target.wager_total)
		&"wager":
			return _submit_draft(raw_draft)
		&"all_in":
			action = PlayerAction.all_in_action()
		&"continue":
			return continue_hand()
	if action != null:
		return _submit(action)
	return _fail("The requested action is unavailable.")


func _submit_draft(raw_draft: String) -> StepResult:
	var trimmed: String = raw_draft.strip_edges()
	if not IntegerBounds.fits_signed_64_bit_text(trimmed):
		return _fail("Enter a whole-number wager total.")
	return submit_wager_total(trimmed.to_int())


func submit_wager_total(total: int) -> StepResult:
	if not _can_submit():
		return _fail("Actions are unavailable while the session is stopped or a dialog is open.")
	if PlayerAction.Kind.BET in _view.legal_actions:
		return _submit(PlayerAction.bet_to(total))
	if PlayerAction.Kind.RAISE in _view.legal_actions:
		return _submit(PlayerAction.raise_to(total))
	return _fail("A wager is unavailable for the current player.")


func continue_hand() -> StepResult:
	if (
		not _can_submit()
		or not _view.hand_complete
		or _match.state != TournamentMatch.State.RUNNING
	):
		return _fail("The next hand is unavailable.")
	_epoch += 1
	_pacer.cancel()
	return _advance(true, _epoch, false)


func request_quit() -> StepResult:
	if _match == null:
		return _fail("There is no active tournament to quit.")
	_epoch += 1
	_held_pending = false
	_pacer.cancel()
	_last_result = _match.request_quit()
	_feedback = _last_result.message
	refresh()
	return _last_result


## Explicit adapter/profiler stepping cancels the previous scheduled transition.
func advance_one_action() -> StepResult:
	if not _can_submit():
		return _fail("Actions are unavailable while the session is stopped or a dialog is open.")
	_epoch += 1
	_held_pending = false
	_pacer.cancel()
	return _advance(false, _epoch, false)


func stop() -> void:
	_epoch += 1
	_held_pending = false
	_pacer.cancel()
	_match = null


func is_advance_pending() -> bool:
	return _pacer.is_waiting() or _held_pending


func _clear_binding() -> void:
	_view = null
	_recipient = Table.NO_SEAT
	_avatars.clear()
	_names.clear()
	_latest.clear()
	_folds.clear()
	_lines.clear()


func _can_submit() -> bool:
	return (
		_match != null
		and _view != null
		and (not _input_blocked.is_valid() or not _input_blocked.call())
	)


func _submit(action: PlayerAction) -> StepResult:
	if _view.acting_seat != _recipient:
		return _fail("It is not this recipient's turn.")
	var epoch: int = _epoch
	_last_result = _match.submit_human_action_without_advance(action)
	if _last_result.status in [StepResult.Status.YIELDED, StepResult.Status.HAND_COMPLETED]:
		# A modal may still hold a callback for the previous actor's pause.
		# The accepted action owns a fresh pause, including before view callbacks.
		_epoch += 1
		epoch = _epoch
		_held_pending = false
		_pacer.cancel()
	_feedback = _last_result.message
	var submitted: StepResult = _last_result
	refresh()
	if (
		epoch == _epoch
		and submitted.status in [StepResult.Status.YIELDED, StepResult.Status.HAND_COMPLETED]
	):
		_schedule_latest()
	return submitted


func _fail(message: String) -> StepResult:
	_last_result = StepResult.new(StepResult.Status.ERROR, message)
	_feedback = message
	changed.emit()
	return _last_result


func _schedule_latest() -> void:
	if _match == null or not _configured or _match.state != TournamentMatch.State.RUNNING:
		return
	if _view.hand_complete:
		_pacer.schedule_after_completed_hand(_advance.bind(true, _epoch))
		return
	var events: Array[DomainEvent] = _match.get_events()
	if not events.is_empty() and events[-1].kind == DomainEvent.Kind.ACTION_APPLIED:
		_schedule_action(events[-1].seat)
	elif _view.acting_seat == Table.NO_SEAT and _view.legal_actions.is_empty():
		if GuiMatchProgressInspector.latest_event_is_community_cards_dealt(events):
			_schedule_action(Table.NO_SEAT)
		else:
			call_deferred("_advance", false, _epoch)


func _schedule_action(actor: int) -> void:
	_pacer.schedule_after_action(actor, _advance.bind(false, _epoch))


func _advance(hand_boundary: bool, epoch: int, respect_hold: bool = true) -> StepResult:
	if epoch != _epoch or _match == null:
		return StepResult.new(StepResult.Status.ERROR, "The pending GUI advance has expired.")
	_held_pending = false
	if (
		respect_hold
		and _hold_advance.is_valid()
		and _hold_advance.call(_advance.bind(hand_boundary, epoch))
	):
		_held_pending = true
		return _last_result
	if _match.state != TournamentMatch.State.RUNNING:
		return _last_result
	var previous_actor: int = GuiMatchProgressInspector.latest_action_seat(_match.get_events())
	_last_result = _match.advance_one_action()
	_feedback = _last_result.message
	var advanced: StepResult = _last_result
	refresh()
	if epoch != _epoch:
		return advanced
	if advanced.status == StepResult.Status.YIELDED:
		if (
			not hand_boundary
			and GuiMatchProgressInspector.latest_event_is_community_cards_dealt(_match.get_events())
		):
			_schedule_action(previous_actor)
		else:
			_schedule_latest()
	elif advanced.status == StepResult.Status.HAND_COMPLETED:
		_pacer.schedule_after_completed_hand(_advance.bind(true, _epoch))
	return advanced


func _rebuild_events(events: Array[DomainEvent]) -> void:
	_lines.clear()
	_latest.clear()
	_folds.clear()
	var action_index: int = 0
	var street_index: int = 0
	var records: Array[PublicActionRecord] = _view.action_history
	for event: DomainEvent in events:
		var record: PublicActionRecord = _record_for_event(event, records, action_index)
		if record != null:
			for index: int in range(action_index, records.size()):
				if records[index] == record:
					action_index = index + 1
					break
		if event.kind in [DomainEvent.Kind.HAND_STARTED, DomainEvent.Kind.STREET_CHANGED]:
			_latest.clear()
		if record != null:
			_latest[record.seat] = record
			if (
				record.record_kind == PublicActionRecord.Kind.ACTION
				and record.kind == PlayerAction.Kind.FOLD
			):
				_folds[record.seat] = record
		if event.kind == DomainEvent.Kind.STREET_CHANGED:
			_lines.append(GuiEventFormatter.street_transition_text(street_index))
			street_index += 1
		else:
			_lines.append(GuiEventFormatter.format_event(event, _view, record))


static func _record_for_event(
	event: DomainEvent, records: Array[PublicActionRecord], start: int
) -> PublicActionRecord:
	if event.kind not in [DomainEvent.Kind.ACTION_APPLIED, DomainEvent.Kind.BLIND_POSTED]:
		return null
	for index: int in range(start, records.size()):
		var record: PublicActionRecord = records[index]
		if record.seat != event.seat or record.amount != event.amount:
			continue
		if event.kind == DomainEvent.Kind.ACTION_APPLIED:
			if record.record_kind == PublicActionRecord.Kind.ACTION:
				return record
		elif record.record_kind != PublicActionRecord.Kind.ACTION:
			return record
	return null
