tool
extends EditorImportPlugin

func get_importer_name():
    return "aseprite_animation_importer"

func get_visible_name():
    return "Aseprite animation"

func get_recognized_extensions():
    return ["ase", "aseprite"]

func get_save_extension():
    return "res"

func get_resource_type():
    return "SpriteFrames"

enum Presets { ANIMATION }

func get_preset_count():
    return Presets.size()

func get_preset_name(preset):
    match preset:
        Presets.ANIMATION:
            return "Animation"
        _:
            return "Unknown"

func get_import_options(preset):
    match preset:
        Presets.ANIMATION:
            return [
                {
                    "name": "extrude",
                    "type": TYPE_BOOL,
                    "default_value": false,
                    "usage": PROPERTY_USAGE_EDITOR
                },
                {
                    "name": "default_direction",
                    "type": TYPE_STRING,
                    "property_hint": PROPERTY_HINT_ENUM,
                    "hint_string": "Forward,Reverse,Ping-pong",
                    "default_value": "Forward",
                    "usage": PROPERTY_USAGE_EDITOR
                },
                {
                    "name": "default_loop",
                    "type": TYPE_BOOL,
                    "default_value": false,
                    "usage": PROPERTY_USAGE_EDITOR
                }
            ]
        _:
            return []

var direction_map = {
    "Forward": "forward",
    "Reverse": "reverse",
    "Ping-pong": "pingpong"
}

func get_option_visibility(_option, _options):
    return true

func export_sprite_sheet(save_path, source_file, extrude):
    var aseprite_path = ProjectSettings.get_setting("aseprite_animation_importer/aseprite_executable_path")
    if aseprite_path == null or aseprite_path == "":
        push_error("Aseprite executable path is not specified in project settings.")
        return { "error": ERR_FILE_BAD_PATH }
    var png_path = save_path + ".png"
    var output = []
    var error = OS.execute(aseprite_path, [
        "--batch",
        "--filename-format", "{tag}{tagframe}",
        "--format", "json-array",
        "--list-tags",
        "--ignore-empty",
        "--trim",
        "--inner-padding", "1" if extrude else "0",
        "--sheet-type", "packed",
        "--sheet", ProjectSettings.globalize_path(png_path),
        ProjectSettings.globalize_path(source_file)
        ],
        true, output)
    if error != OK:
        push_error("Can't execute Aseprite CLI command.")
        return { "error": error }
    var data = ""
    for line in output:
        data += line
    var json_result = JSON.parse(data)
    if json_result.error != OK:
        push_error("Can't parse Aseprite export json data.")
        return { "error": json_result.error }
    var json = json_result.result

    var image = Image.new()
    error = image.load(png_path)
    if error != OK:
        push_error("Can't load exported png image.")
        return { "error": error }
    if extrude:
        extrude_edges_into_padding(image, json)
    var texture = ImageTexture.new()
    texture.create_from_image(image, 0)
    error = Directory.new().remove(png_path)
    if error != OK:
        push_error("Can't remove temporary png image.")
        return { "error": error }
    return { "texture": texture, "json": json, "error": OK }

func extrude_edges_into_padding(image, json):
    image.lock()
    for frame_data in json.frames:
        var frame = frame_data.frame
        var x = 0
        var y = frame.y
        for i in range(frame.w):
            x = frame.x + i
            image.set_pixel(x, y, image.get_pixel(x, y + 1))
        x = frame.x + frame.w - 1
        for i in range(frame.h):
            y = frame.y + i
            image.set_pixel(x, y, image.get_pixel(x - 1, y))
        y = frame.y + frame.h - 1
        for i in range(frame.w):
            x = frame.x + i
            image.set_pixel(x, y, image.get_pixel(x, y - 1))
        x = frame.x
        for i in range(frame.h):
            y = frame.y + i
            image.set_pixel(x, y, image.get_pixel(x + 1, y))
    image.unlock()

func get_sprite_frames(source_file):
    var sprite_frames
    if ResourceLoader.exists(source_file):
        sprite_frames = ResourceLoader.load(source_file, "SpriteFrames", false)
    else:
        sprite_frames = SpriteFrames.new()
    return sprite_frames

func import(source_file, save_path, options, _r_platform_variants, _r_gen_files):
    var export_result = export_sprite_sheet(save_path, source_file, options.extrude)
    if export_result.error != OK:
        return export_result.error
    
    if export_result.json.meta.frameTags.empty():
        export_result.json.meta.frameTags.push_back({
            "name": ("_" if options.default_loop else "") + "default",
            "from": 0,
            "to": export_result.json.frames.size() - 1,
            "direction": direction_map[options.default_direction]
        })

    var sprite_frames = get_sprite_frames(source_file)
    
    var unique_names = []
    for frame_tag in export_result.json.meta.frameTags:
        frame_tag.name = frame_tag.name.strip_edges().strip_escapes()
        if frame_tag.name.empty():
            push_error("Found empty tag name")
            return ERR_INVALID_DATA
        var loop = frame_tag.name.left(1)
        frame_tag.looped = loop == "_"
        if frame_tag.looped:
            frame_tag.name = frame_tag.name.substr(1)
        if unique_names.has(frame_tag.name):
            push_error("Found duplicated tag name")
            return ERR_INVALID_DATA
        unique_names.append(frame_tag.name)

    var names = sprite_frames.get_animation_names()
    for name in names:
        if unique_names.has(name):
            sprite_frames.clear(name)
        else:
            sprite_frames.remove_animation(name)

    var atlas_textures = {}

    for frame_tag in export_result.json.meta.frameTags:
        var name = frame_tag.name
        if not sprite_frames.has_animation(name):
            sprite_frames.add_animation(name)
        sprite_frames.set_animation_loop(name, frame_tag.looped)
        var frame_indices = []
        for frame_index in range(frame_tag.from, frame_tag.to + 1):
            frame_indices.append(frame_index)
        match frame_tag.direction:
            "forward":
                pass
            "reverse":
                frame_indices.invert()
            "pingpong":
                var l = frame_indices.size()
                if l > 2:
                    for frame_index in range(frame_tag.to - 1, frame_tag.from, -1):
                        frame_indices.append(frame_index)

        var frame_duration = null
        for frame_index in frame_indices:
            var frame_data = export_result.json.frames[frame_index]
            var frame = frame_data.frame
            var sprite_source_size = frame_data.spriteSourceSize
            var source_size = frame_data.sourceSize

            var x = frame.x + 1 if options.extrude else frame.x
            var y = frame.y + 1 if options.extrude else frame.y
            var w = frame.w - 2 if options.extrude else frame.w
            var h = frame.h - 2 if options.extrude else frame.h

            var key = "%d_%d_%d_%d" % [x, y, w, h]
            var atlas_texture = atlas_textures.get(key)
            if atlas_texture == null:
                atlas_texture = AtlasTexture.new()
                atlas_texture.atlas = export_result.texture
                atlas_texture.region = Rect2(x, y, w, h)
                atlas_texture.margin = Rect2(sprite_source_size.x, sprite_source_size.y, source_size.w - w, source_size.h - h)
                atlas_textures[key] = atlas_texture

            sprite_frames.add_frame(name, atlas_texture)
            if frame_duration == null:
                frame_duration = export_result.json.frames[frame_index].duration
        sprite_frames.set_animation_speed(name, 1000 / frame_duration)

    var error = ResourceSaver.save(
        save_path + "." + get_save_extension(),
        sprite_frames,
        ResourceSaver.FLAG_COMPRESS |
        ResourceSaver.FLAG_BUNDLE_RESOURCES |
        ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
    if error != OK:
        push_error("Can't save imported resource.")
    return error
