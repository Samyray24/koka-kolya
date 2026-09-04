# ROADMAP.md — Дорожная карта разработки «Кока-Коля»

---

## Этап 0 — Discovery / v0.0.1 (ЗАВЕРШЕН)
- [x] Аудит аппаратной среды и доступного ПО (`docs/ENVIRONMENT_AUDIT.md`).
- [x] Проверка официального стабильного релиза Godot 4.6.3 и Jolt Physics.
- [x] Определение Project Charter, Architecture, Budgets, Toolchain, ADRs.
- [x] Создание структуры каталогов (Section 26) и `project.godot`.
- [x] Установка `godot-jolt` v0.16.0 в `addons/`.
- [x] Разработка минимальных сцен: `Boot`, `MainMenu`, `TestHub`, `FoundationGraybox`.
- [x] Разработка первого контроллера игрока (First-Person Jolt Controller).
- [x] Проведение Headless Smoke Test.
- [x] Проверка запуска графической сцены.

## Этап 1 — Core Foundation / v0.1.0 (ЗАВЕРШЕН)
- [x] Абстракция ввода (мышь/клавиатура + геймпад).
- [x] Взаимодействие с физическими предметами (raycast, pick up, throw).
- [x] Базовый UI настроек графики, звука, управления и доступности (Accessibility).
- [x] Менеджер сохранений (семантическое сохранение прогресса).
- [x] Автоматический интеграционный тест `tests/integration/test_core_foundation.gd` (5/5 PASS).

## Этап 2 — System Prototypes / v0.2.0 (ЗАВЕРШЕН)
- [x] **Physics Lab**: конвейеры, двери на петлях Jolt, бьющееся стекло (6/6 PASS).
- [x] **SkillGraph Architecture**: 416 узлов, 64 синергии, DAG валидатор.
- [x] **Fair AI & AI Arena**: `NoiseManager`, зрение, слух, координация охраны (5/5 PASS).
- [x] **BUBBLE Companion Drone**: следование, 6-DOF полет, сканирование, фонарь (5/5 PASS).
- [x] **Delivery Van & Vehicle Lab**: Jolt `VehicleBody3D`, 4 колеса, штраф за груз (6/6 PASS).
- [x] **Combat & Tools Arsenal**: электродубинка, пена BUBBLE-BLOC, кибер-дека взлома (5/5 PASS).
- [x] **Graphics Lab & Scalability Profiles**: LOW (60+ FPS FSR 77%), MEDIUM, HIGH (5/5 PASS).
- [x] **SkillGraph Runtime Modifiers**: активные рантайм модификаторы для 28 узлов (5/5 PASS).

## Этап 3 — First Playable / v0.3.0 (ЗАВЕРШЕН)
- [x] 20-30 минут сквозного геймплея в Старом Районе (`scenes/levels/old_district.tscn`).
- [x] `MissionManager` и `DialogueManager` (радиопереговоры СашиV и Коли).
- [x] Погрузка физических ящиков «Кока-Коля» в кузов фургона.
- [x] Проникновение в терминал MERIDIAN и кража чипа секретной рецептуры.
- [x] Автоматический тест `tests/integration/test_first_playable.gd` (5/5 PASS).

## Этап 4 — Vertical Slice / v0.5.0 (ЗАВЕРШЕН)
- [x] 45-60 минут полированного контента: Завод «Красная Линия» (`scenes/levels/red_line_plant.tscn`).
- [x] Камеры безопасности MERIDIAN (`SecurityCamera3D`) с панорамным обзором, взломом и ослеплением пеной.
- [x] Рецептурный верстак (`CraftingStation`) для синтеза концентрата Коли.
- [x] Главная сиропная башня (`SyrupTower`) и физическая канистра концентрата.
- [x] Терминал промышленной автоматизации (`AutomationTerminal`) и запуск конвейеров розлива.
- [x] Автоматический тест `tests/integration/test_vertical_slice.gd` (5/5 PASS).
- [x] Полный прогон тестовых сьютов (100% PASS, 0 ошибок).
- [x] Однокликовые лаунчеры `run_game.bat` и `run_tests.bat`.

## Этап 5 — Production Core & System Integration / v0.6.0 (ЗАВЕРШЕН)
- [x] Менеджер сохранений (`SaveManager`) с атомарной сериализацией состояния мира, игрока, навыков и квестов в `user://saves/save_slot_X.json`.
- [x] Менеджер процедурного звука (`AudioManager`) с синтезом 12 PCM-семплов (шаги, прыжки, приземления, захват/бросок, рация СашиV, шокер, пена, взлом, тревога, победные фанфары) с нулевым оверхедом на диск.
- [x] Оверлейное меню паузы (`PauseMenu`) с горячими клавишами быстрого сохранения (`F5`) и быстрой загрузки (`F9`).
- [x] Интеграция звукового отклика во все ключевые сущности (`PlayerController`, `PhysicsGrabber`, `DialogueManager`, `StunBaton`, `FoamLauncher`, `HackingTool`).
- [x] Автоматический интеграционный тест `tests/integration/test_save_audio_systems.gd` (5/5 PASS).
- [x] Полный прогон всех 12 тестовых сьютов (100% PASS, 0 ошибок).

## Этап 6 — Open World District Hub, Dynamic Environment & Campaign Flow / v0.7.0 (ЗАВЕРШЕН)
- [x] **GameManager**: глобальный контроллер межрайонных переходов, баланса валюты (Коля-рубли), репутации сопротивления и архива сюжетных миссий.
- [x] **EnvironmentManager**: система динамического времени суток (утро, полдень, закат, неоновая ночь) и переключения атмосферных погодных профилей (CLEAR, INDUSTRIAL_SMOG, NEON_RAIN).
- [x] **VehicleRadio**: автомобильная аудиосистема фургона доставки с переключением 4 радиостанций Краснограда на клавишу `[R]` с 3D-позиционированием звука.
- [x] **Шоссе Краснограда — Миссия 3 (`scenes/levels/city_highway.tscn`)**:
  - Скоростной заезд на фургоне с грузом Кока-Коли по автостраде.
  - Преодоление автоматизированного охранного блокпоста КПП №2 корпорации MERIDIAN (взлом электронного шлагбаума `PhysicalDoor`, обход CCTV-камер).
  - Прибытие на городскую площадь к Центральной Медиа-Башне.
  - Взлом вещательного терминала и трансляция манифеста свободы Кока-Коли на все медиаэкраны Краснограда!
- [x] **Автоматический интеграционный тест `tests/integration/test_campaign_and_highway.gd` (5/5 PASS)**.
- [x] **Обновлен Test Hub**: добавлена лаборатория и прямой запуск Миссии 3 «Шоссе Краснограда».
- [x] **100% Quality Gate: 13 из 13 тестовых сьютов пройдены без единой ошибки (`run_all_tests.ps1`)**.
- [x] **Визуальная GPU-верификация на Forward Plus (AMD Radeon RX 550)**: `docs/screenshots/city_highway.png`.