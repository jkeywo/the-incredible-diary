extends RefCounted
## Spoken lines and their reveal times are ordinary recorded simulation state.
const Rooms = preload("res://mission1/rooms.gd")
const CPS := 36.0

static func say(run, speaker: String, text: String, kind := "speech", key := "", duration := 0) -> void:
 if speaker != "amelia" and not run.s.actors.has(speaker): return
 var room: String = run.s.room if speaker == "amelia" else run.s.actors[speaker].room
 if room != run.s.room or run.s.dead.has(speaker): return
 var ticks := duration if duration > 0 else maxi(30,ceili(text.length()/CPS*10)+15)
 var frame := int(run.s.get("frame",run.s.tick))
 run.s.dialogue = {"speaker":speaker,"name":"Thought" if kind == "thought" else run.display_name(speaker),"text":text,"kind":kind,"room":room,"started":frame,"until":frame+ticks,"key":key}

static func start(run, id: String, lines: Array, people: Array) -> void:
 var seen: Array = run.s.get("conversations_seen",[])
 if seen.has(id): return
 seen.append(id)
 run.s.conversations_seen = seen
 run.s.conversation = {"id":id,"lines":lines,"people":people,"index":0,"room":run.s.room}
 _next(run)

static func _next(run) -> void:
 var scene: Dictionary = run.s.conversation
 if scene.index >= scene.lines.size():
  run.s.conversation = {}
  return
 var line: Array = scene.lines[scene.index]
 say(run,line[0],line[1],"speech","spoken_%s_%d" % [scene.id,scene.index])
 scene.index += 1

static func update(run) -> void:
 var active: Dictionary = run.s.get("dialogue",{})
 if not active.is_empty():
  var speaker: String = active.speaker
  var room: String = run.s.room if speaker == "amelia" else run.s.actors.get(speaker,{}).get("room","")
  if active.room != run.s.room or room != active.room or run.s.dead.has(speaker):
   run.s.dialogue = {}
   run.s.conversation = {}
  else:
   if int(run.s.get("frame",run.s.tick))-active.started >= ceili(active.text.length()/CPS*10) and not str(active.get("key","")).is_empty():
    run.note(active.key,active.name+": "+active.text,true,false)
   if int(run.s.get("frame",run.s.tick)) < active.until: return
   run.s.dialogue = {}
 var scene: Dictionary = run.s.get("conversation",{})
 if not scene.is_empty():
  var together: bool = scene.room == run.s.room
  for id in scene.people:
   together = together and (run.s.room if id == "amelia" else run.s.actors.get(id,{}).get("room","")) == scene.room
  if together:
   _next(run)
   if not run.s.dialogue.is_empty(): return
  else: run.s.conversation = {}
 if run.tutorial_active(): return
 # Important conversations take precedence over ambient exchanges.
 if run.flag("chat_delay") and run.s.tick < run._chat_departure() and run.s.room == str(run.s.flags.get("chat_room","cabins")):
  start(run,"nephew",[["chatterbox","Before you go, you must hear about my nephew."],["guest","Could it wait? They are serving drinks."],["chatterbox","He bought a motorcar. Without asking his mother!"],["guest","How very rash."],["chatterbox","That is exactly what I said. Now, listen…"]],["guest","chatterbox"])
  return
 var a: Dictionary = run.s.actors
 if run.s.room == "controls" and run.flag("trapped") and not run.s.safe.has("chatterbox") and not run.s.dead.has("chatterbox"):
  start(run,"steam_help",[["chatterbox","Help! The steam has cut off the passage!"]],["chatterbox"])
  if not run.s.dialogue.is_empty(): return
 if run.s.room == "docks" and not run.flag("bag_found"):
  if a.dock_sailor.action == "talk":
   start(run,"bags",[["guest","Where are my bags? I will not board without them!"],["dock_sailor","I'll search the luggage, sir."],["guest","Brown leather. With my initials."],["dock_sailor","Stay here. I'll bring them over."]],["guest","dock_sailor"])
  elif run.nearby("docks",Rooms.point(a.guest.pos),110):
   start(run,"bags_waiting",[["guest","My brown suitcase is still missing. I'm waiting here."]],["guest"])
  return
 for pair in [["chandelier_guest","porter","directions",[["chandelier_guest","Which way to the Salon?"],["porter","Up the centre stair, madam."]]],["chandelier_guest","chatterbox","weather",[["chandelier_guest","A lovely evening for a departure."],["chatterbox","Provided the sea remembers its manners."]]],["chatterbox","guest","cabins",[["chatterbox","Are you settling into your cabin?"],["guest","At last. I thought my luggage had taken its own holiday."]]]]:
  if not a.has(pair[0]) or not a.has(pair[1]): continue
  var first: Dictionary = a[pair[0]]
  var second: Dictionary = a[pair[1]]
  if first.room == run.s.room and second.room == run.s.room and first.action == "talk" and second.action in ["talk","idle"] and Rooms.point(first.pos).distance_to(Rooms.point(second.pos)) < 100:
   start(run,pair[2],pair[3],[pair[0],pair[1]])
   if not run.s.dialogue.is_empty(): return
