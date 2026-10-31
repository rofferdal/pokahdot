class_name GuiWebGeometryProbe
extends RefCounted

## CSS layout, visual and canvas rectangles share layout-viewport coordinates.
## A hidden env() probe measures safe insets without altering app layout.
const READ_SCRIPT: String = """
(() => {
 const canvas = document.getElementById('canvas') || document.querySelector('canvas');
 if (!canvas) return '';
 if (!window.__pokahdotGeometryState) {
   const state = {revision: 1};
   window.__pokahdotGeometryState = state;
   const bump = () => { state.revision++; };
   window.addEventListener('resize', bump);
   window.addEventListener('orientationchange', bump);
   if (window.visualViewport) {
     visualViewport.addEventListener('resize', bump);
     visualViewport.addEventListener('scroll', bump);
   }
   if (window.ResizeObserver) {
     state.observer = new ResizeObserver(bump); state.observer.observe(canvas);
   }
 }
 let probe = document.getElementById('__pokahdotSafeAreaProbe');
 if (!probe) {
   probe = document.createElement('div'); probe.id = '__pokahdotSafeAreaProbe';
   probe.style.cssText = 'position:fixed;left:0;top:0;width:0;height:0;'
     + 'visibility:hidden;pointer-events:none;'
     + 'padding-left:env(safe-area-inset-left,0px);padding-top:env(safe-area-inset-top,0px);'
     + 'padding-right:env(safe-area-inset-right,0px);'
     + 'padding-bottom:env(safe-area-inset-bottom,0px)';
   (document.body || document.documentElement).appendChild(probe);
 }
 const style = getComputedStyle(probe), rect = canvas.getBoundingClientRect();
 const layout = document.documentElement;
 const width = layout.clientWidth || innerWidth, height = layout.clientHeight || innerHeight;
 const visual = window.visualViewport;
 return JSON.stringify({
   canvas: [rect.x,rect.y,rect.width,rect.height], layout: [0,0,width,height],
   visual: visual
     ? [visual.offsetLeft,visual.offsetTop,visual.width,visual.height] : [0,0,width,height],
   insets: [parseFloat(style.paddingLeft)||0,parseFloat(style.paddingTop)||0,
            parseFloat(style.paddingRight)||0,parseFloat(style.paddingBottom)||0],
   dpr: devicePixelRatio || 1
 });
})()
"""

## Events can precede settled browser metrics during rotation/chrome transitions.
const REVISION_SCRIPT: String = """
(() => {
 const state = window.__pokahdotGeometryState;
 if (!state) return 0;
 const canvas = document.getElementById('canvas') || document.querySelector('canvas');
 if (!canvas) return state.revision;
 const rect = canvas.getBoundingClientRect(), visual = window.visualViewport;
 const signature = JSON.stringify([
   rect.x, rect.y, rect.width, rect.height,
   innerWidth, innerHeight, document.documentElement.clientWidth,
   document.documentElement.clientHeight, devicePixelRatio,
   visual ? [visual.offsetLeft, visual.offsetTop, visual.width, visual.height] : null
 ]);
 if (signature !== state.signature) {
   state.signature = signature;
   state.revision++;
 }
 return state.revision;
})()
"""


static func capture(backing_size: Vector2i) -> GuiViewportGeometry:
	if not OS.has_feature("web"):
		return GuiViewportGeometry.new()
	var raw: Variant = JavaScriptBridge.eval(READ_SCRIPT)
	if not raw is String:
		return GuiViewportGeometry.new()
	var data: Variant = JSON.parse_string(raw)
	if not data is Dictionary:
		return GuiViewportGeometry.new()
	var insets: Array = data.insets
	return GuiViewportGeometry.from_web(
		backing_size,
		_rect(data.canvas),
		_rect(data.layout),
		_rect(data.visual),
		Vector4(insets[0], insets[1], insets[2], insets[3]),
		float(data.dpr)
	)


static func revision() -> int:
	if not OS.has_feature("web"):
		return 0
	var value: Variant = JavaScriptBridge.eval(REVISION_SCRIPT)
	return int(value) if value != null else 0


static func _rect(value: Array) -> Rect2:
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
