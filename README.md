# 🥤 «КОКА-КОЛЯ» (First-Person 3D Action RPG / Immersive Sim)

> **Рабочее название**: «Кока-Коля»  
> **Жанр**: First-Person 3D Action RPG / Immersive Sim  
> **Движок**: Godot Engine 4.6.3-stable (Jolt Physics 3D)  
> **Скриптовый язык**: Typed GDScript  
> **Версия**: v0.0.1 (Foundation)  

---

## 🎮 О проекте

Главный герой — обычный, находчивый и самоироничный техник-водитель Коля, который оказывается внутри конфликта вокруг автономной логистической сети **MERIDIAN** в индустриально-футуристическом городе Красноград.

### Ключевые системы игры:
- **Отзывчивое передвижение**: first-person ходьба, спринт, прыжки с Coyote Time и буферизацией ввода.
- **Jolt Physics 3D**: взаимодействие с физическими предметами, честная масса, толкание препятствий.
- **Честный AI**: зрение, слух, координация без читерского чтения состояния игрока.
- **Транспорт и доставки**: физическая модель вождения, влияние массы груза на управляемость.
- **Глубокая RPG система**: SkillGraph из 416 узлов (16 веток по 26 узлов) + 64 синергии.
- **Жёсткий лимит размера**: строго `<= 20.0 GB` (целевой `<= 18.0 GB`).

---

## 🚀 Инструкция запуска

### 1. Запуск через локальный Godot Engine:
```powershell
cd c:\Users\Никитос\Documents\KokaKolya
.\tools\godot\Godot_v4.6.3-stable_win64.exe --path .
```

### 2. Запуск в headless-режиме (Smoke Test):
```powershell
cd c:\Users\Никитос\Documents\KokaKolya
.\tools\godot\Godot_v4.6.3-stable_win64.exe --headless --path . -s tests/scenes/headless_smoke_test.gd
```

### 3. Быстрый запуск Graybox сцены:
```powershell
.\tools\godot\Godot_v4.6.3-stable_win64.exe --path . scenes/testlabs/foundation_graybox.tscn
```

---

## 📁 Структура каталогов

```
KokaKolya/
├── project.godot          # Основной конфигурационный файл Godot 4.6
├── README.md              # Документация и инструкция запуска
├── addons/                # godot-jolt v0.16.0 GDExtension
├── docs/                  # Полный пакет архитектурной документации
│   ├── ENVIRONMENT_AUDIT.md
│   ├── PROJECT_CHARTER.md
│   ├── ARCHITECTURE.md
│   ├── DECISIONS.md (ADRs)
│   ├── ROADMAP.md
│   ├── PERFORMANCE_BUDGETS.md
│   ├── STORAGE_BUDGET.md
│   ├── TOOLCHAIN.md
│   ├── LEGAL_AND_LICENSES.md
│   └── RISK_REGISTER.md
├── scenes/
│   ├── boot/boot.tscn
│   ├── ui/main_menu.tscn
│   ├── testlabs/test_hub.tscn
│   ├── testlabs/foundation_graybox.tscn
│   └── characters/player.tscn
├── scripts/
│   ├── core/boot.gd
│   ├── core/player_controller.gd
│   ├── ui/main_menu.gd
│   ├── debug/test_hub.gd
│   └── gameplay/foundation_graybox.gd
├── tests/
│   └── scenes/headless_smoke_test.gd
└── tools/
    └── godot/             # Официальный портативный бинарник Godot 4.6.3
```
