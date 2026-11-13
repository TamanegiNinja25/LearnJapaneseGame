## Builds the application icons from tools/icon/app_icon_source.png.
##
##   godot --headless --path game --script ../tools/make_app_icons.gd
##
## The source is a 313 px rounded-square illustration on a lavender backdrop. Outputs:
##   game/icon.png                              project icon (window, Windows .exe, Web favicon)
##   game/assets/app_icon/android_192.png       legacy Android launcher icon
##   game/assets/app_icon/android_fg_432.png    adaptive icon foreground (art inside the viewport)
##   game/assets/app_icon/android_bg_432.png    adaptive icon background (solid night sky)
##   game/assets/app_icon/android_mono_432.png  themed-icon silhouette (the book's 日本語 ink)
extends SceneTree

const SOURCE := "res://../tools/icon/app_icon_source.png"
## The rounded square inside the source, measured from its edge pixels.
const ART_RECT := Rect2i(4, 4, 302, 302)
const ART_RADIUS := 57.0
## Adaptive icons are 108 dp; the launcher shows the inner 72 dp (288 of 432 px). The art is drawn
## slightly larger than that viewport so no backdrop shows at the mask's edges.
const ADAPTIVE_SIZE := 432
const ADAPTIVE_ART := 300
const NIGHT := Color("2a1f3f")
## The 日本語 lettering on the book page, without the furigana above it.
const INK_RECT := Rect2i(74, 173, 170, 50)
## Width of the lettering in the monochrome icon; 250 px keeps its corners inside the 264 px
## safe circle at the centre of the 432 px layer.
const MONO_WIDTH := 250


func _initialize() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if src == null or src.is_empty():
		push_error("Cannot read %s" % SOURCE)
		quit(1)
		return
	src.convert(Image.FORMAT_RGBA8)
	var art := src.get_region(ART_RECT)
	_round_corners(art, ART_RADIUS)

	_save(art, "res://icon.png")
	_save(_scaled(art, 192), "res://assets/app_icon/android_192.png")

	var fg := Image.create_empty(ADAPTIVE_SIZE, ADAPTIVE_SIZE, false, Image.FORMAT_RGBA8)
	var big := _scaled(art, ADAPTIVE_ART)
	var at := (ADAPTIVE_SIZE - ADAPTIVE_ART) / 2
	fg.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(at, at))
	_save(fg, "res://assets/app_icon/android_fg_432.png")

	var bg := Image.create_empty(ADAPTIVE_SIZE, ADAPTIVE_SIZE, false, Image.FORMAT_RGBA8)
	bg.fill(NIGHT)
	_save(bg, "res://assets/app_icon/android_bg_432.png")

	_save(_monochrome(src.get_region(INK_RECT)), "res://assets/app_icon/android_mono_432.png")
	quit()


## Android 13+ tints this layer with the wallpaper colour, so only its alpha matters: dark ink
## becomes opaque white, the cream page becomes transparent.
func _monochrome(ink: Image) -> Image:
	var mask := Image.create_empty(ink.get_width(), ink.get_height(), false, Image.FORMAT_RGBA8)
	for y in ink.get_height():
		for x in ink.get_width():
			var a := clampf((0.45 - ink.get_pixel(x, y).get_luminance()) / 0.2, 0.0, 1.0)
			mask.set_pixel(x, y, Color(1, 1, 1, a))
	var h := roundi(MONO_WIDTH * float(ink.get_height()) / ink.get_width())
	mask.resize(MONO_WIDTH, h, Image.INTERPOLATE_LANCZOS)
	var out := Image.create_empty(ADAPTIVE_SIZE, ADAPTIVE_SIZE, false, Image.FORMAT_RGBA8)
	out.blit_rect(mask, Rect2i(Vector2i.ZERO, mask.get_size()), (Vector2i(ADAPTIVE_SIZE, ADAPTIVE_SIZE) - mask.get_size()) / 2)
	return out


## Makes everything outside a rounded rectangle transparent, with a one-pixel antialiased edge.
func _round_corners(img: Image, radius: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var cx := clampf(x + 0.5, radius, w - radius)
			var cy := clampf(y + 0.5, radius, h - radius)
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			var cover := clampf(radius - d + 0.5, 0.0, 1.0)
			if cover < 1.0:
				var c := img.get_pixel(x, y)
				c.a *= cover
				img.set_pixel(x, y, c)


func _scaled(img: Image, size: int) -> Image:
	var out := img.duplicate() as Image
	out.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return out


func _save(img: Image, path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := img.save_png(abs_path)
	print("%s %s -> %s" % [path, img.get_size(), error_string(err)])
