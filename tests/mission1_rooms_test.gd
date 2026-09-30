extends SceneTree
const Simulation = preload("res://mission1/simulation.gd")
const Rooms = preload("res://mission1/rooms.gd")
func _initialize() -> void:
 var sim := Simulation.new(false)
 sim.s.pos = [390,430]
 for i in 51: sim.step()
 assert(sim.flag("bag_lead"))
 sim.s.pos = [145,390]
 assert(sim.start("hide_bag"))
 for i in 21: sim.step()
 assert(sim.flag("bag_hidden"))
 sim.reset()
 assert(sim.memory.bag and not sim.flag("bag_lead") and not sim.flag("bag_hidden"))
 sim.s.pos = [145,390]
 assert(sim.start("inspect_bag"))
 for i in 11: sim.step()
 assert(sim.flag("bag_lead"))
 assert(not Rooms.can_stand("controls", Vector2(590,420)))
 assert(not Rooms.can_stand("passage", Vector2(1120,480)))
 for room in Rooms.ROOMS:
  for door in Rooms.exits(room, true):
   assert(Rooms.can_stand(room, Rooms.point(door.point)))
   assert(Rooms.can_stand(door.room, Rooms.point(door.arrival)))
 print("MISSION1 ROOMS PASS: gates, reset knowledge and connected floor endpoints")
 quit()
