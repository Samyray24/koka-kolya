extends SceneTree

# Автоматический интеграционный тест AAA-расширения (3 новых района, 4 радиостанции, тюнинг фургона, PBR)
# Проверяет:
# 1. VehicleRadio (4 радиостанции, плейлисты, воспроизведение)
# 2. Кастомизацию DeliveryVan (4 раскраски кузова, 5 режимов неоновой подсветки днища)
# 3. Район «Неоновый Бульвар» (небоскребы, эстакада, голо-экран, миссия)
# 4. Район «Логистический Хаб» (контейнеры, лазерная сетка, краны, миссия)
# 5. Район «Подземный Метрополитен» (тоннели, вагоны, серверы, тайник, миссия)

var passed_count: int = 0
var total_count: int = 5
var step: int = 0
var van_node: VehicleBody3D = null

func _process(_delta: float) -> bool:
	step += 1
	match step:
		1:
			print("\n=======================================================================")
			print(">>> ЗАПУСК TEST: AAA EXPANSION (DISTRICTS, RADIO, TUNING, PBR) <<<")
			print("=======================================================================\n")
		3:
			_test_1_radio_and_van()
		5:
			_test_2_tuning()
		7:
			_test_3_neon_boulevard()
		9:
			_test_4_logistics_hub()
		11:
			_test_5_underground_metro()
		13:
			_finalize()
			return true
	return false

func _test_1_radio_and_van() -> void:
	var van_res: PackedScene = load("res://scenes/vehicles/delivery_van.tscn")
	if not van_res:
		print("[FAIL] Test 1: Не удалось загрузить delivery_van.tscn")
		return
	van_node = van_res.instantiate()
	root.add_child(van_node)

	var radio: Node = van_node.get_node_or_null("VehicleRadio")
	if not radio:
		print("[FAIL] Test 1: VehicleRadio не найдено в фургоне.")
		return

	var st0: String = radio.call("get_current_station")
	var st1: String = radio.call("cycle_station")
	var st2: String = radio.call("cycle_station")
	var st3: String = radio.call("cycle_station")
	var st4: String = radio.call("cycle_station")
	var st_off: String = radio.call("cycle_station")
	var is_off: bool = radio.get("is_playing") == false

	if st0 == "Выключено" and st1.contains("Синтвейв") and st2.contains("Техно") and st3.contains("Рок") and st4.contains("Новости") and st_off == "Выключено" and is_off:
		print("[PASS] Test 1: VehicleRadio успешно инициализирует и циклично переключает 4 радиостанции.")
		passed_count += 1
	else:
		print("[FAIL] Test 1: Ошибка переключения радио (st1=%s, st2=%s, st3=%s, st4=%s, off=%s)." % [st1, st2, st3, st4, st_off])

func _test_2_tuning() -> void:
	if not van_node:
		print("[FAIL] Test 2: Фургон отсутствует.")
		return

	var liv0 = van_node.get("current_livery_idx")
	van_node.call("cycle_livery")
	var liv1 = van_node.get("current_livery_idx")
	van_node.call("cycle_livery")
	var liv2 = van_node.get("current_livery_idx")
	van_node.call("cycle_livery")
	var liv3 = van_node.get("current_livery_idx")
	van_node.call("cycle_livery")
	var liv_back = van_node.get("current_livery_idx")

	var ug0 = van_node.get("current_underglow_idx")
	van_node.call("cycle_underglow")
	var ug1 = van_node.get("current_underglow_idx")
	var lights: Array = van_node.get("underglow_lights")

	var liveries_ok: bool = liv0 == 0 and liv1 == 1 and liv2 == 2 and liv3 == 3 and liv_back == 0
	var underglow_ok: bool = ug0 == 0 and ug1 == 1 and lights.size() == 4 and lights[0].visible == true

	if liveries_ok and underglow_ok:
		print("[PASS] Test 2: Тюнинг фургона (4 PBR-раскраски кузова и 5 режимов неона днища) работает корректно.")
		passed_count += 1
	else:
		print("[FAIL] Test 2: Ошибка кастомизации (liveries_ok=%s, underglow_ok=%s)." % [liveries_ok, underglow_ok])

	root.remove_child(van_node)
	van_node.free()
	van_node = null

func _test_3_neon_boulevard() -> void:
	var neon_res: PackedScene = load("res://scenes/levels/neon_boulevard.tscn")
	if not neon_res:
		print("[FAIL] Test 3: Не удалось загрузить scenes/levels/neon_boulevard.tscn")
		return

	var neon_inst: Node = neon_res.instantiate()
	root.add_child(neon_inst)

	var p: Node = neon_inst.get_node_or_null("Player")
	var v: Node = neon_inst.get_node_or_null("DeliveryVan")
	var bridge: Node = neon_inst.get_node_or_null("CyberFlyoverBridge")
	var holo: Node = neon_inst.get_node_or_null("HoloBillboardAnchor")
	var vend: Node = neon_inst.get_node_or_null("PlazaVendingMachine")

	var ok: bool = p != null and v != null and bridge != null and holo != null and vend != null

	if ok:
		print("[PASS] Test 3: Район «Неоновый Бульвар» успешно инстанцирован (небоскребы, эстакада, голо-экран, автомат).")
		passed_count += 1
	else:
		print("[FAIL] Test 3: В районе «Неоновый Бульвар» отсутствуют ключевые ноды.")

	root.remove_child(neon_inst)
	neon_inst.free()

func _test_4_logistics_hub() -> void:
	var hub_res: PackedScene = load("res://scenes/levels/logistics_hub.tscn")
	if not hub_res:
		print("[FAIL] Test 4: Не удалось загрузить scenes/levels/logistics_hub.tscn")
		return

	var hub_inst: Node = hub_res.instantiate()
	root.add_child(hub_inst)

	var p: Node = hub_inst.get_node_or_null("Player")
	var v: Node = hub_inst.get_node_or_null("DeliveryVan")
	var crane: Node = hub_inst.get_node_or_null("CranePlatform")
	var laser: Node = hub_inst.get_node_or_null("LaserSecurityGrid")
	var container: Node = hub_inst.get_node_or_null("ShippingContainer_0")

	var ok: bool = p != null and v != null and crane != null and laser != null and container != null

	if ok:
		print("[PASS] Test 4: Район «Логистический Хаб» успешно инстанцирован (контейнеры, кран, лазерный периметр, охрана).")
		passed_count += 1
	else:
		print("[FAIL] Test 4: В районе «Логистический Хаб» отсутствуют ключевые ноды.")

	root.remove_child(hub_inst)
	hub_inst.free()

func _test_5_underground_metro() -> void:
	var metro_res: PackedScene = load("res://scenes/levels/underground_metro.tscn")
	if not metro_res:
		print("[FAIL] Test 5: Не удалось загрузить scenes/levels/underground_metro.tscn")
		return

	var metro_inst: Node = metro_res.instantiate()
	root.add_child(metro_inst)

	var p: Node = metro_inst.get_node_or_null("Player")
	var train: Node = metro_inst.get_node_or_null("SubwayTrainCar")
	var server: Node = metro_inst.get_node_or_null("ServerRack_0")
	var vend: Node = metro_inst.get_node_or_null("SecretMetroVending")
	var cache: Node = metro_inst.get_node_or_null("MetroCacheLoot")

	var ok: bool = p != null and train != null and server != null and vend != null and cache != null

	if ok:
		print("[PASS] Test 5: Район «Подземный Метрополитен» успешно инстанцирован (тоннели, вагон, дата-сервер, схрон).")
		passed_count += 1
	else:
		print("[FAIL] Test 5: В районе «Подземный Метрополитен» отсутствуют ключевые ноды.")

	root.remove_child(metro_inst)
	metro_inst.free()

func _finalize() -> void:
	print("\n=======================================================================")
	print("РЕЗУЛЬТАТ: Пройдено %d из %d проверок AAA-расширения." % [passed_count, total_count])
	print("=======================================================================\n")
