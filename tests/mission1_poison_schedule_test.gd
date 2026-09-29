extends SceneTree
const Sim = preload("res://mission1/simulation.gd")
const Content = preload("res://mission1/authoring_content.gd")
func _initialize() -> void: call_deferred("checks")
func advance(run, tick: int) -> void:
 while run.s.tick < tick: run.step()
func fresh(authored: bool, delayed: bool):
 var run := Sim.new(false)
 if authored: assert(run.apply_authored(Content.seed(run.s.actors)).ok)
 if delayed: run.s.flags.bag_delayed = true
 return run
func at_bar(run) -> void:
 assert(run.s.actors.guest.room == "salon")
 assert(Sim.Rooms.point(run.s.actors.guest.pos).distance_to(Sim.Rooms.BAR_GUEST)<35)
func checks() -> void:
 # A subpixel remainder must not strand passengers on a doorway waypoint.
 var before := {"guest":{"room":"docks","pos":[580.0047,105.0203],"action":"walk"}}
 var planned := {"guest":{"room":"foyer","pos":[735,460],"action":"walk"}}
 var resolved := Sim.Crowd.separate(planned,{},before)
 resolved = Sim.Crowd.separate(planned,{},resolved)
 assert(resolved.guest.room == "foyer")
 for authored in [false,true]:
  var early = fresh(authored,false)
  advance(early,Sim.CREAK-32)
  assert(not early.flag("spiked"))
  advance(early,Sim.CREAK-30)
  assert(early.flag("spiked"))
  at_bar(early)
  advance(early,Sim.CREAK+10)
  assert(early.s.dead.has("guest") and early.flag("chandelier_warning"))
  assert(not early.flag("chandelier_fallen"))
  var delayed = fresh(authored,true)
  advance(delayed,Sim.CREAK)
  delayed.s.room = "foyer"
  delayed.s.pos = [580,450]
  delayed.s.dialogue = {}
  delayed.s.conversation = {}
  assert(delayed.start("shove"))
  advance(delayed,Sim.FALL+1)
  assert(delayed.s.safe.has("chandelier_guest") and not delayed.flag("chat_delay"))
  assert(not delayed.flag("spiked") and not delayed.s.dead.has("guest"))
  advance(delayed,3*Sim.HOUR+450)
  at_bar(delayed)
  assert(delayed.flag("spiked") and delayed.flag("trapped"))
  assert(not delayed.s.safe.has("chatterbox") and not delayed.s.dead.has("chatterbox"))
  advance(delayed,3*Sim.HOUR+530)
  assert(delayed.s.dead.has("guest") and delayed.s.tick<Sim.STEAM_FATAL)
  var saved = fresh(authored,true)
  advance(saved,Sim.CREAK)
  saved.s.room = "foyer"
  saved.s.pos = [580,450]
  saved.s.dialogue = {}
  saved.s.conversation = {}
  assert(saved.start("shove"))
  advance(saved,Sim.FALL+1)
  saved.s.room = "controls"
  saved.s.pos = [350,300]
  advance(saved,Sim.TRAP+10)
  assert(saved.start("panel"))
  saved.s.entry = saved.s.code
  assert(saved.submit_code())
  advance(saved,Sim.STEAM_FATAL)
  assert(saved.flag("chat_delay") and not saved.flag("spiked"))
  assert(saved.party_arrival() == Sim.POISON)
  # This is Mabel's preserved routine; rescuing Evelyn alone did not unlock it.
  assert(saved.s.safe.has("chatterbox"))
  advance(saved,Sim.POISON-2)
  assert(not saved.flag("spiked"))
  saved.s.room = "salon"
  saved.s.pos = [Sim.Rooms.BAR_GUEST.x,Sim.Rooms.BAR_GUEST.y+40]
  advance(saved,Sim.POISON)
  at_bar(saved)
  assert(saved.s.flags.spike_tick == Sim.POISON)
  assert(Sim.observation_time(saved.s.flags.spike_tick) == "05:15")
  var restored := Sim.new(false)
  restored.restore_record({"current":saved.s,"history":saved.history,"memory":saved.memory,"authored_content":saved.authored_content,"content_versions":saved.content_versions})
  assert(restored.s.flags.drink_tick == Sim.POISON+80)
  var recorded: Dictionary = restored.history[-1].duplicate(true)
  advance(restored,Sim.POISON+80)
  assert(restored.s.dead.has("guest") and restored.history[recorded.frame] == recorded)
  assert(saved.start("bump"))
  advance(saved,Sim.END)
  assert(saved.s.dead.is_empty() and saved.s.safe.size() == 3)
 print("MISSION1 POISON SCHEDULE PASS: early chandelier conflict, steam conflict, rescued Mabel delays to 5:15, physical arrival, save/history and complete rescue")
 quit()
