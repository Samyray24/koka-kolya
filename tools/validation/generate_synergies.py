import json
import os

synergies = []

syn_examples = [
    ("Grapple + Shock Baton", "Электрический воздушный удар с прыжком на цель"),
    ("Foam + Magnetic Launcher", "Временная физическая направляющая и ловушка"),
    ("Drone Hack + EMP", "BUBBLE излучает локальную EMP-волну перегрузки"),
    ("Vehicle Hack + Nitro", "Удаленный импульс ускорения беспилотного транспорта"),
    ("Parkour + Stealth", "Бесшумное скоростное преодоление препятствий"),
    ("Rain Analysis + Shock", "Расширенная проводящая электрическая зона лужи"),
    ("Cargo Stabilizer + Off-road Grip", "Безопасная скоростная доставка по гравию и снегу"),
    ("Social Access + Network Ghost", "Легальный цифровой пропуск на закрытые терминалы"),
    ("Cola Collider + Magnetic Pull", "Столкновение банок Колы с индукцией вихревого поля"),
    ("Bubble Light + Visor Filter", "Сквозное сканирование скрытых электрических цепей")
]

for i in range(64):
    ex_idx = i % len(syn_examples)
    title, desc = syn_examples[ex_idx]
    b1 = f"branch_{(i % 16) + 1:02d}"
    b2 = f"branch_{((i * 3 + 1) % 16) + 1:02d}"
    if b1 == b2:
        b2 = f"branch_{((i + 2) % 16) + 1:02d}"
    
    synergies.append({
        "id": f"syn_{i+1:02d}",
        "name": f"{title} #{i+1}",
        "branch_a": b1,
        "branch_b": b2,
        "description": desc,
        "unlocked": i < 8,
        "effect_multiplier": 1.25 + (i % 4) * 0.1
    })

out_path = "c:/Users/Никитос/Documents/KokaKolya/data/skills/synergies_manifest.json"
os.makedirs(os.path.dirname(out_path), exist_ok=True)
with open(out_path, "w", encoding="utf-8") as f:
    json.dump({"total_synergies": len(synergies), "synergies": synergies}, f, ensure_ascii=False, indent=2)

print(f"Generated {len(synergies)} synergies in {out_path}")
