class_name DecisionModelRegistry
extends RefCounted

## Explicit composition-root registry for decision model and parameter scripts.

var _model_scripts: Dictionary[StringName, Script] = {}
var _parameter_scripts: Dictionary[StringName, Script] = {}


func register_model(model_id: StringName, model_script: Script, parameter_script: Script) -> bool:
	if model_id.is_empty() or model_script == null or parameter_script == null:
		return false
	if _model_scripts.has(model_id):
		return false
	_model_scripts[model_id] = model_script
	_parameter_scripts[model_id] = parameter_script
	return true


func has_model(model_id: StringName) -> bool:
	return _model_scripts.has(model_id)


func create_model(model_id: StringName) -> DecisionModel:
	if not has_model(model_id):
		return null
	return _model_scripts[model_id].new() as DecisionModel


func accepts_parameters(model_id: StringName, parameters: DecisionModelParameters) -> bool:
	return (
		has_model(model_id)
		and parameters != null
		and parameters.get_script() == _parameter_scripts[model_id]
	)
