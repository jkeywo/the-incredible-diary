extends RefCounted
class_name FoundationProjectAssets

const MAX_IMAGE_BYTES := 12 * 1024 * 1024

static func import_image(name: String, bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_IMAGE_BYTES:
		return {"ok": false, "reason": "Background image must be 1 byte to 12 MB"}
	var extension := name.get_extension().to_lower()
	var mime: String = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "webp": "image/webp"}.get(extension, "")
	if mime.is_empty():
		return {"ok": false, "reason": "Background must be PNG, JPEG or WebP"}
	var image := Image.new()
	var error := _load_image(image, mime, bytes)
	if error != OK or image.get_width() < 1 or image.get_height() < 1:
		return {"ok": false, "reason": "Image data could not be decoded"}
	var checksum := _sha256(bytes)
	return {"ok": true, "id": "image-" + checksum.substr(0, 20), "asset": {"name": name.get_file(), "mime": mime, "sha256": checksum, "base64": Marshalls.raw_to_base64(bytes), "width": image.get_width(), "height": image.get_height()}}

static func validate(asset: Variant) -> String:
	if not asset is Dictionary:
		return "Asset manifest entry must be an object"
	if not asset.get("base64") is String or not asset.get("mime") is String or not asset.get("sha256") is String:
		return "Asset needs encoded image data, MIME type and checksum"
	var bytes := Marshalls.base64_to_raw(str(asset.base64))
	if bytes.is_empty() or bytes.size() > MAX_IMAGE_BYTES:
		return "Asset image data is missing or too large"
	if _sha256(bytes) != asset.sha256:
		return "Asset checksum does not match image data"
	var image := Image.new()
	if _load_image(image, str(asset.mime), bytes) != OK:
		return "Asset image data cannot be decoded as " + str(asset.mime)
	if image.get_width() != int(asset.get("width", -1)) or image.get_height() != int(asset.get("height", -1)):
		return "Asset dimensions do not match image data"
	return ""

static func texture(asset: Dictionary) -> ImageTexture:
	var image := Image.new()
	var bytes := Marshalls.base64_to_raw(str(asset.get("base64", "")))
	if _load_image(image, str(asset.get("mime", "")), bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)

static func _load_image(image: Image, mime: String, bytes: PackedByteArray) -> Error:
	match mime:
		"image/png": return image.load_png_from_buffer(bytes)
		"image/jpeg": return image.load_jpg_from_buffer(bytes)
		"image/webp": return image.load_webp_from_buffer(bytes)
		_: return ERR_FILE_UNRECOGNIZED

static func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
