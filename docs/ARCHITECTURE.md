# ARCHITECTURE.md — Системная Архитектура игры «Кока-Коля»

Версия: 1.0  
Движок: Godot 4.6.3-stable (Jolt Physics 3D)  

---

## 1. Архитектурные принципы

1. **Композиция сцен над наследованием**: Каждая игровая сущность строится из переиспользуемых независимых компонентов (HealthComponent, InteractionComponent, InventoryComponent, PhysicsInteractor).
2. **Сигнальная развязка**: Вызов методов идет сверху вниз; передача событий наверх родителю/менеджеру — строго через сигналы (Signals).
3. **Data-Driven дизайн**: Навыки, диалоги, параметры транспорта, рецепты и баланс вынесены в `Resource` файлы (`.tres`) и JSON-манифесты.
4. **Службы одного экземпляра (Autoload / Singletons)**:
   - `GameManager`: Управление игровым состоянием, паузой, загрузкой уровней.
   - `InputManager`: Абстракция ввода (мышь/клавиатура/геймпад), поддержка ребиндинга.
   - `SaveManager`: Атомарное сохранение семантического состояния мира и игрока.
   - `LogManager`: Структурированное логирование с уровнями INFO, WARN, ERROR, DEBUG.
   - `AudioManager`: Управление шинами звука, музыкой, пространственным SFX.

---

## 2. Потоки данных и подсистемы

```
Boot Scene -> MainMenu / TestHub -> World / Region -> Player Controller
                                                           |
  +--------------------------------------------------------+
  |
  +--> Physics Interaction (Jolt 3D: RigidBody3D, Raycast, Joints)
  +--> AI Perception (Vision cone, Hearing radius, Blackboard)
  +--> SkillGraph System (Data-Driven Skills, Synergies)
  +--> Vehicle System (RigidBody3D + Raycast Suspension Telemetry)
  +--> Audio System (Web/FMOD-like Bus Architecture, Spatial Audio)
```

---

## 3. Физический слой (Jolt Physics 3D)

* **Backend**: Jolt Physics via `godot-jolt` v0.16.0 GDExtension.
* **Слои коллизий (Collision Layers)**:
  - Layer 1: World Static (земля, стены, архитектура).
  - Layer 2: Player (тело игрока, капсула).
  - Layer 3: Enemies / NPCs (тела мобов и персонажей).
  - Layer 4: Dynamic Physics Objects (ящики, бочки, физические предметы).
  - Layer 5: Projectiles (снаряды, пули, лазеры).
  - Layer 6: Vehicles (транспорт, колеса, кузов).
  - Layer 7: Interactables (триггеры подбора, кнопки, терминалы).
  - Layer 8: Triggers / Volumes (зоны смены погоды, звука, квестов).
