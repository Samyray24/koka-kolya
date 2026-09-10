extends SceneTree

# KokaKolya - Master PCK Builder using Godot 4 native PCKPacker
# Packs ALL game scenes, scripts, shaders, materials, audio, models, and 4K PBR textures
# into a massive standalone distribution package.

var frame: int = 0

func _process(_delta: float) -> bool:
    frame += 1
    if frame == 2:
        _build()
        return true
    return false

func _build():
    print('=======================================================================')
    print('>>> KOKAKOLYA — СБОРКА МАСТЕР-ДИСТРИБУТИВА (PCKPacker) <<<')
    print('=======================================================================')

    var target_pck = 'builds/windows/KokaKolya.pck'
    var packer = PCKPacker.new()
    var err = packer.pck_start(target_pck)
    if err != OK:
        printerr('ОШИБКА: Не удалось инициализировать PCKPacker: ', err)
        quit(1)
        return

    # 1. Корневые метаданные проекта
    packer.add_file('res://project.godot', 'res://project.godot')
    if FileAccess.file_exists('res://icon.svg'):
        packer.add_file('res://icon.svg', 'res://icon.svg')

    # 2. Основные игровые папки
    var core_dirs = [
        'res://scenes',
        'res://scripts',
        'res://shaders',
        'res://data',
        'res://assets/materials',
        'res://assets/scenes_3d',
        'res://assets/audio',
        'res://assets/textures'
    ]

    var total_files = 2
    for cd in core_dirs:
        total_files += _pack_dir_recursive(packer, cd)

    print('[INFO] Упаковка завершена. Всего файлов в пакете: ', total_files)
    print('[INFO] Сброс буферов на диск (flush)...')
    err = packer.flush()
    if err != OK:
        printerr('ОШИБКА: Ошибка сброса PCK: ', err)
        quit(1)
        return

    var f = FileAccess.open(target_pck, FileAccess.READ)
    if f:
        var size_bytes = f.get_length()
        var size_mb = float(size_bytes) / (1024.0 * 1024.0)
        var size_gb = float(size_bytes) / (1024.0 * 1024.0 * 1024.0)
        f.close()
        print('=======================================================================')
        print('>>> МАСТЕР PCK УСПЕШНО СОЗДАН! <<<')
        print('Файл:    %s' % target_pck)
        print('Размер:  %.2f МБ (%.3f ГБ)' % [size_mb, size_gb])
        print('Файлов:  %d' % total_files)
        print('=======================================================================')
    quit(0)

func _pack_dir_recursive(packer: PCKPacker, dir_path: String) -> int:
    var dir = DirAccess.open(dir_path)
    if not dir:
        return 0
    var count = 0
    for f in dir.get_files():
        if f.ends_with('.tmp') or f.ends_with('.log'):
            continue
        var fp = dir_path + '/' + f
        packer.add_file(fp, fp)
        count += 1
    for d in dir.get_directories():
        count += _pack_dir_recursive(packer, dir_path + '/' + d)
    return count
