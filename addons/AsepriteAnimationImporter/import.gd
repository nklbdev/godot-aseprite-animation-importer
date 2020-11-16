tool
extends EditorPlugin

var plugin
var aseprite_path_setting_name = "aseprite_animation_importer/aseprite_executable_path"

func _enter_tree():
    if not ProjectSettings.has_setting(aseprite_path_setting_name):
        ProjectSettings.set_setting(aseprite_path_setting_name, "")
        ProjectSettings.add_property_info({
            "name": aseprite_path_setting_name,
            "type": TYPE_STRING,
            "hint": PROPERTY_HINT_GLOBAL_FILE,
            "hint_string": ""})
        ProjectSettings.set_initial_value(name, "")
        var err = ProjectSettings.save()
        if err: push_error("Can't save project settings")

    plugin = preload("plugin.gd").new()
    add_import_plugin(plugin)

func _exit_tree():
    remove_import_plugin(plugin)
    plugin = null