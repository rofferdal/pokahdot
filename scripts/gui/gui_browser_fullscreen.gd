class_name GuiBrowserFullscreen
extends RefCounted


## Browser-owned fullscreen preserves orientation and the existing canvas state.
static func is_supported() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(
		JavaScriptBridge.eval("!!(document.fullscreenEnabled || document.webkitFullscreenEnabled)")
	)


## Call from an explicit user action while transient browser activation is live.
static func request() -> void:
	if not OS.has_feature("web"):
		return
	(
		JavaScriptBridge
		. eval(
			"""(() => {
			if (document.fullscreenElement || document.webkitFullscreenElement) return;
			const element = document.documentElement;
			try {
				const result = element.requestFullscreen
					? element.requestFullscreen({navigationUI: 'hide'})
					: element.webkitRequestFullscreen?.();
				result?.catch(error => console.info('Fullscreen unavailable:', error.message));
			} catch (error) {
				console.info('Fullscreen unavailable:', error.message);
			}
		})()"""
		)
	)
