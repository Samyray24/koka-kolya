# TOOLCHAIN.md — Реестр утвержденных инструментов сборки и разработки

Версия документа: 1.0  
Дата утверждения: 03.09.2026  

---

## 1. Утвержденный инструментарий

| Инструмент | Версия | Источник | Лицензия | Назначение |
|---|---|---|---|---|
| **Godot Engine** | `4.6.3-stable` (Win64) | [github.com/godotengine/godot](https://github.com/godotengine/godot/releases/tag/4.6.3-stable) | MIT License | Основной игровой движок, компилятор GDScript |
| **Jolt Physics** | `v0.16.0-stable` | [github.com/godot-jolt/godot-jolt](https://github.com/godot-jolt/godot-jolt/releases/tag/v0.16.0-stable) | MIT License | 3D физический backend (GDExtension) |
| **Git** | 2.x | [git-scm.com](https://git-scm.com) | GPL v2 | Контроль версий исходного кода |
| **Python** | 3.11+ | [python.org](https://python.org) | PSF License | Скрипты валидации данных и ассетов |

---

## 2. Безопасность и откат (Rollback)

- **Портативность**: Движок Godot расположен локально в `tools/godot/` без изменения системного реестра и не требует прав администратора.
- **Способ отката**: Удаление каталога `tools/godot/` возвращает систему в исходное состояние.
- **Секреты и токены**: Запрещено добавление любых API-ключей, токенов и секретов в репозиторий.
