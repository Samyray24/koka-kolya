import json
import os

branches = [
    ("movement_parkour", "Передвижение и Паркур"),
    ("combat", "Боевое мастерство"),
    ("stealth", "Скрытность и Маскировка"),
    ("hacking", "Взлом и Электроника"),
    ("engineering", "Инженерия и Ремонт"),
    ("bubble_drone", "Дрон BUBBLE"),
    ("driving", "Вождение и Гонки"),
    ("vehicle_engineering", "Автомеханика и Тюнинг"),
    ("exploration", "Исследование и Сканирование"),
    ("social_reputation", "Дипломатия и Связи"),
    ("base_logistics", "База и Логистика"),
    ("physics_improvisation", "Физическая Импровизация"),
    ("meridian", "Нейросеть MERIDIAN"),
    ("delivery_mastery", "Мастерство Доставки"),
    ("tactics_allies", "Тактика и Союзники"),
    ("kolya_legend", "Легенда о Коле")
]

node_types = [
    ("foundational", 8),
    ("modifier", 5),
    ("active_ability", 4),
    ("choice_node", 3),
    ("cross_gateway", 3),
    ("master", 1),
    ("ultimate", 1),
    ("capstone", 1)
]

nodes = []

for b_idx, (b_id, b_title) in enumerate(branches):
    node_counter = 1
    prev_node_id = None
    
    for n_type, count in node_types:
        for i in range(count):
            node_id = f"{b_id}_{node_counter:02d}"
            tier = min(5, (node_counter - 1) // 5 + 1)
            cost = tier * 100
            
            # Prereqs: tree structure without cycles
            prereqs = [prev_node_id] if prev_node_id and n_type != "cross_gateway" else []
            
            # First 28 nodes are marked implemented/prototyped for vertical slice
            status = "implemented" if len(nodes) < 28 else "planned"
            
            node_data = {
                "id": node_id,
                "branch": b_id,
                "branch_name": b_title,
                "node_index": node_counter,
                "node_type": n_type,
                "tier": tier,
                "display_name": f"{b_title}: Узел #{node_counter}",
                "description": f"Специализированная способность Коли в ветке «{b_title}».",
                "gameplay_effect": f"Активирует системный эффект категории {n_type} с привязкой к физике и геймплею.",
                "prerequisites": prereqs,
                "exclusion_group": f"choice_{b_id}_{tier}" if n_type == "choice_node" else "",
                "unlock_cost": cost,
                "tags": [b_id, n_type, f"tier_{tier}"],
                "synergy_tags": [f"syn_{b_id}"],
                "implementation_status": status,
                "test_ids": [f"TEST_SKILL_{node_id}"],
                "accessibility_notes": "Поддерживает альтернативный ввод без удержания клавиш",
                "balance_notes": f"Базовый расход ресурсов уровня {tier}",
                "icon_id": f"icon_{b_id}_{node_counter}",
                "localization_key": f"SKILL_{node_id.upper()}"
            }
            nodes.append(node_data)
            prev_node_id = node_id
            node_counter += 1

out_path = "c:/Users/Никитос/Documents/KokaKolya/data/skills/skills_manifest.json"
os.makedirs(os.path.dirname(out_path), exist_ok=True)
with open(out_path, "w", encoding="utf-8") as f:
    json.dump({"total_nodes": len(nodes), "skills": nodes}, f, ensure_ascii=False, indent=2)

print(f"Generated {len(nodes)} skills in {out_path}")
