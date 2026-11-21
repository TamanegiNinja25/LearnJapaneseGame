extends RefCounted
class_name UpdateCheck
## Is a newer release on GitHub? Pure helpers: main.gd does the HTTP request (once per launch,
## only when 設定 › 更新を確認する is on) and hands the parsed JSON to [method from_release].

const RELEASES_API := "https://api.github.com/repos/TamanegiNinja25/LearnJapaneseGame/releases/latest"
const RELEASES_PAGE := "https://github.com/TamanegiNinja25/LearnJapaneseGame/releases/latest"


## "v0.3.1" / "0.3.1" -> [0, 3, 1]. Missing or non-numeric parts count as 0.
static func parse_version(text: String) -> Array[int]:
	var parts: Array[int] = []
	for piece in text.strip_edges().trim_prefix("v").trim_prefix("V").split("-")[0].split("."):
		parts.append(int(piece) if piece.is_valid_int() else 0)
	while parts.size() < 3:
		parts.append(0)
	return parts


static func is_newer(latest: String, current: String) -> bool:
	var a := parse_version(latest)
	var b := parse_version(current)
	for i in maxi(a.size(), b.size()):
		var x: int = a[i] if i < a.size() else 0
		var y: int = b[i] if i < b.size() else 0
		if x != y:
			return x > y
	return false


## The fields the popup needs from a GitHub "latest release" response, or {} when the response
## is not a usable published release. "apk", "windows", "linux" and "macos" are direct download
## URLs for each platform's build ("" when the release has none).
static func from_release(data: Dictionary) -> Dictionary:
	var tag := String(data.get("tag_name", ""))
	if tag == "" or data.get("draft", false) or data.get("prerelease", false):
		return {}
	var out := {"version": tag.trim_prefix("v"), "url": String(data.get("html_url", RELEASES_PAGE)),
		"apk": "", "windows": "", "linux": "", "macos": ""}
	for asset: Variant in data.get("assets", []):
		if not asset is Dictionary:
			continue
		var name := String((asset as Dictionary).get("name", ""))
		var url := String((asset as Dictionary).get("browser_download_url", ""))
		if name.ends_with(".apk"):
			out["apk"] = url
		elif name.ends_with("-windows.zip"):
			out["windows"] = url
		elif name.ends_with("-linux.zip"):
			out["linux"] = url
		elif name.ends_with("-macos.zip"):
			out["macos"] = url
	return out


## The download for the running platform ("Android", "Windows", "Linux", "macOS"), falling back
## to the release page (the Web build, or a release without that file).
static func download_url(info: Dictionary, os_name: String) -> String:
	var key: String = {"Android": "apk", "Windows": "windows", "Linux": "linux", "macOS": "macos"}.get(os_name, "")
	var url := String(info.get(key, "")) if key != "" else ""
	return url if url != "" else String(info.get("url", RELEASES_PAGE))
