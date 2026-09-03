# ENVIRONMENT_AUDIT.md — Аудит среды разработки «Кока-Коля»

Дата проведения аудита: 03.09.2026  
Проект: «Кока-Коля» (First-Person 3D Action RPG / Immersive Sim)  
Статус: Этап 0 — Discovery / v0.0.1  

---

## 1. Аппаратное обеспечение (Hardware)

| Компонент | Значение | Оценка применимости к разработке |
|---|---|---|
| **Операционная система** | Microsoft Windows 10 Pro (Build 10.0.19045, 64-bit) | Полная совместимость с Windows PC target |
| **Процессор (CPU)** | AMD Ryzen 3 3200G (4 ядра, 4 потока, ~3.6-4.0 GHz) | Базовый 4-ядерный CPU (соответствует Minimum Profile) |
| **Оперативная память (RAM)** | 16.0 GB DDR4 | Достаточно для комфортной сборки и запуска Godot |
| **Видеокарта (GPU)** | AMD Radeon RX 550 / Radeon Vega 8 Graphics (Драйвер: 31.0.21923.11000) | Поддержка Vulkan 1.2+, Direct3D 12, OpenGL 4.6 |
| **Дисковое пространство (C:)** | Свободно: 28.5+ GB / Занято: 209+ GB | Удовлетворяет лимиту игры (<= 20 GB) с запасом для сборки |

---

## 2. Программный инструментарий (Software & Toolchain)

| Инструмент | Версия / Путь | Статус и Назначение |
|---|---|---|
| **Godot Engine** | 4.6.3-stable (Win64 Official, Commit `7d41c59c4`) | Основной 3D движок игры, typed GDScript runtime |
| **3D Physics Backend** | Jolt Physics (godot-jolt v0.16.0-stable GDExtension) | Детерминированный высокопроизводительный физический движок |
| **Git** | 2.x (`C:\Program Files\Git\cmd\git.exe`) | Система контроля версий |
| **GitHub CLI (gh)** | 2.x (`C:\Program Files\GitHub CLI\gh.exe`) | Автоматизация репозитория, проверка релизов и PR |
| **Python** | 3.11.x (`C:\Users\Никитос\AppData\Local\Programs\Python\Python311\python.exe`) | Автоматизация проверок, генерация ассетов и манифестов |
| **Node.js / npm** | Node v20+ (`C:\Program Files\nodejs\node.exe`) | Вспомогательные скрипты валидации и CI |
| **Blender** | Не обнаружен в PATH | Запланирован для установки при старте художественного пайплайна |

---

## 3. Модели и навыки Antigravity

* **Агентная среда**: Google Antigravity 2.0.
* **Доступные навыки**: `godot-game-engine`, `clean-code-architecture`, `game-loop-math-physics`, `state-machine-game-logic`, `windows-desktop-native`.
* **MCP Серверы**: Внешние сторонние MCP серверы отключены во избежание блокировок и утечек процессов. Разработка ведется через прямой контролируемый интерфейс инструментов с наименьшими привилегиями.
