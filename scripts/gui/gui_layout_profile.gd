class_name GuiLayoutProfile
extends RefCounted

## Classifies the current usable canvas for presentation-only layout decisions.
## Reference GUI only: the replacement policy is GuiSizeClass/GuiFitPolicy.
## Production routing migrates in RG-13; keep this reference behavior until then.
##
## Callers must pass the rectangle left after browser chrome and safe-area
## reductions. Platform feature flags and physical display pixels are
## intentionally not part of the automatic contract. A caller with explicit
## device evidence may supply a profile override; this is required for known
## high-resolution device surfaces whose geometry is also a valid desktop
## window size.

enum Kind {
	PHONE_PORTRAIT,
	PHONE_LANDSCAPE,
	TABLET,
	SMALL_DESKTOP,
	DESKTOP,
}

const PHONE_MAX_SHORT_EDGE: float = 600.0
const PHONE_MAX_LONG_EDGE: float = 920.0
const PHONE_MIN_ASPECT_RATIO: float = 1.35
const TABLET_PORTRAIT_MIN_SHORT_EDGE: float = 680.0
const TABLET_PORTRAIT_MAX_SHORT_EDGE: float = 900.0
const TABLET_LANDSCAPE_MIN_SHORT_EDGE: float = 680.0
const TABLET_LANDSCAPE_MAX_SHORT_EDGE: float = 1200.0
const TABLET_LANDSCAPE_MAX_LONG_EDGE: float = 1200.0
const TABLET_MAX_ASPECT_RATIO: float = 1.8
const SMALL_DESKTOP_MAX_WIDTH: float = 1100.0
const SMALL_DESKTOP_MAX_HEIGHT: float = 760.0
const AUTOMATIC: int = -1


static func classify(usable_size: Vector2, profile_override: int = AUTOMATIC) -> Kind:
	if usable_size.x <= 0.0 or usable_size.y <= 0.0:
		return Kind.DESKTOP
	if _is_valid_override(profile_override):
		return profile_override
	var short_edge: float = minf(usable_size.x, usable_size.y)
	var long_edge: float = maxf(usable_size.x, usable_size.y)
	var aspect_ratio: float = long_edge / short_edge
	var portrait: bool = usable_size.y > usable_size.x

	if (
		short_edge <= PHONE_MAX_SHORT_EDGE
		and long_edge <= PHONE_MAX_LONG_EDGE
		and aspect_ratio >= PHONE_MIN_ASPECT_RATIO
	):
		return Kind.PHONE_PORTRAIT if portrait else Kind.PHONE_LANDSCAPE
	if _is_tablet(short_edge, long_edge, aspect_ratio, portrait):
		return Kind.TABLET
	if (
		not portrait
		and usable_size.x < SMALL_DESKTOP_MAX_WIDTH
		and usable_size.y < SMALL_DESKTOP_MAX_HEIGHT
	):
		return Kind.SMALL_DESKTOP
	return Kind.DESKTOP


static func is_phone(profile: Kind) -> bool:
	return profile == Kind.PHONE_PORTRAIT or profile == Kind.PHONE_LANDSCAPE


static func _is_valid_override(profile_override: int) -> bool:
	return profile_override >= Kind.PHONE_PORTRAIT and profile_override <= Kind.DESKTOP


static func _is_tablet(
	short_edge: float, long_edge: float, aspect_ratio: float, portrait: bool
) -> bool:
	if aspect_ratio >= TABLET_MAX_ASPECT_RATIO:
		return false
	if portrait:
		return (
			short_edge >= TABLET_PORTRAIT_MIN_SHORT_EDGE
			and short_edge <= TABLET_PORTRAIT_MAX_SHORT_EDGE
		)
	return (
		short_edge >= TABLET_LANDSCAPE_MIN_SHORT_EDGE
		and short_edge <= TABLET_LANDSCAPE_MAX_SHORT_EDGE
		and long_edge <= TABLET_LANDSCAPE_MAX_LONG_EDGE
	)
