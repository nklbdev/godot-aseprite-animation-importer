tool
extends EditorImportPlugin

func get_importer_name():
    return "aseprite_animation_importer"

func get_visible_name():
    return "Aseprite animation"

func get_recognized_extensions():
    return ["ase"]

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
        printerr("Aseprite executable path is not specified in project settings.")
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
        printerr("Can't execute Aseprite CLI command.")
        return err
    var data = ""
    for line in output:
        data += line
    var json_result = JSON.parse(data)
    if json_result.error != OK:
        printerr("Can't parse Aseprite export json data.")
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
        printerr("Can't load exported png image.")
        return err
    var texture = ImageTexture.new()
    texture.create_from_image(image, 0)
    err = Directory.new().remove(png_path)
    if err != OK:
        printerr("Can't remove temporary png image.")
        return err

    var sprite_frames
    if ResourceLoader.has_cached(source_file):
        sprite_frames = ResourceLoader.load(source_file, "SpriteFrames", false)
    else:
        sprite_frames = SpriteFrames.new()

    var names = sprite_frames.get_animation_names()
    for name in names:
        sprite_frames.remove_animation(name)

    for frame_tag in json.meta.frameTags:
        # frameTag.direction forward, reverse, ping-pong
        var name = frame_tag.name
        var loop = name.left(1)
        if loop == "_":
            name = name.substr(1)
        sprite_frames.add_animation(name)
        sprite_frames.set_animation_loop(name, loop == "_")
        var frame_duration = 100
        for frame_index in range(frame_tag.from, frame_tag.to + 1):
            var frame = json.frames[frame_index].frame
            var atlas_texture = AtlasTexture.new()
            atlas_texture.atlas = texture
            atlas_texture.region = Rect2(frame.x, frame.y, frame.w, frame.h)
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
        printerr("Can't save imported resource.")
    return err
