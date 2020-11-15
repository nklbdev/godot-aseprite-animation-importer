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
            return [{
                        "name": "use_red_anyway",
                        "default_value": false
                    }]
        _:
            return []

func get_option_visibility(option, options):
    return true


func import(source_file, save_path, options, r_platform_variants, r_gen_files):
    var aseprite_path = ProjectSettings.get_setting("aseprite_animation_importer/aseprite_executable_path")
    if aseprite_path == null or aseprite_path == "":
        push_error("Aseprite executable path is not specified in project settings.")
        return ERR_FILE_BAD_PATH
    var source_file_globalized = ProjectSettings.globalize_path(source_file)
    var png_path = save_path + ".png"
    var png_path_globalized = ProjectSettings.globalize_path(png_path)
    var output = []
    var err = OS.execute(aseprite_path, [
        "--batch",
        "--filename-format", "{tag}{tagframe}",
        "--format", "json-array",
        "--list-tags",
        "--sheet-type", "packed",
        "--sheet", png_path_globalized,
        source_file_globalized
        ], true, output)
    if err != OK:
        push_error("Can't execute Aseprite CLI command.")
        return err
    var data = ""
    for line in output:
        data += line
    var json_result = JSON.parse(data)
    if json_result.error != OK:
        push_error("Can't parse Aseprite export json data.")
        return json_result.error
    var json = json_result.result

    var frameDuration = 0;
    for frameTag in json.meta.frameTags:
        for frameIndex in range(frameTag.from, frameTag.to + 1):
            if frameDuration == 0:
                frameDuration = json.frames[frameIndex].duration
    if frameDuration == 0:
        frameDuration = 100

    var image = Image.new()
    err = image.load(png_path)
    if err != OK:
        push_error("Can't load exported png image.")
        return err
    var texture = ImageTexture.new()
    texture.create_from_image(image, 0)
    err = Directory.new().remove(png_path)
    if err != OK:
        push_error("Can't remove temporary png image.")
        return err

    var sprite_frames
    if ResourceLoader.exists(source_file):
        sprite_frames = ResourceLoader.load(source_file, "SpriteFrames", false)
    else:
        sprite_frames = SpriteFrames.new()
    
    var new_names = []
    for frame_tag in json.meta.frameTags:
        new_names.append(frame_tag.name)

    var names = sprite_frames.get_animation_names()
    for name in names:
        if new_names.has(name):
            sprite_frames.clear(name)
        else:
            sprite_frames.remove_animation(name)

    var atlas_textures = {}

    for frame_tag in json.meta.frameTags:
        # frameTag.direction forward, reverse, ping-pong
        var name = frame_tag.name
        var loop = name.left(1)
        if loop == "_":
            name = name.substr(1)
        if not sprite_frames.has_animation(name):
            sprite_frames.add_animation(name)
        sprite_frames.set_animation_loop(name, loop == "_")
        var frame_duration = 100

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

        for frame_index in frame_indices:
            var frame = json.frames[frame_index].frame

            var key = "%d_%d_%d_%d" % [frame.x, frame.y, frame.w, frame.h]
            var atlas_texture = atlas_textures.get(key)
            if atlas_texture == null:
                atlas_texture = AtlasTexture.new()
                atlas_texture.atlas = texture
                atlas_texture.region = Rect2(frame.x, frame.y, frame.w, frame.h)
                atlas_textures[key] = atlas_texture

            sprite_frames.add_frame(name, atlas_texture)
            frame_duration = json.frames[frame_index].duration
        sprite_frames.set_animation_speed(name, 1000 / frame_duration)

    err = ResourceSaver.save(
        save_path + "." + get_save_extension(),
        sprite_frames,
        ResourceSaver.FLAG_COMPRESS |
        ResourceSaver.FLAG_BUNDLE_RESOURCES |
        ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
    if err != OK:
        push_error("Can't save imported resource.")
    return err