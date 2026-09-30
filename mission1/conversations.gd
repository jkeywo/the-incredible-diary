extends RefCounted
const Text = preload("res://localisation/source_text.gd")
## Spoken lines and their reveal times are ordinary recorded simulation state.
const Rooms = preload("res://mission1/rooms.gd")
const Messages = preload("res://foundation/message_text.gd")
const CPS := 36.0

static func say(run, speaker: String, text: String, kind := "speech", key := "", duration := 0, message_id := "") -> void:
 var original := text
 text = str(run.authored_content.get("texts",{}).get(text,text))
 if speaker != "amelia" and not run.s.actors.has(speaker): return
 var room: String = run.s.room if speaker == "amelia" else run.s.actors[speaker].room
 if room != run.s.room or run.s.dead.has(speaker): return
 var ticks := duration if duration > 0 else maxi(30,ceili(text.length()/CPS*10)+15)
 var frame := int(run.s.get("frame",run.s.tick))
 run.s.dialogue = {"speaker":speaker,"name":Text.MISSION1_THOUGHT if kind == "thought" else run.display_name(speaker),"text":text,"kind":kind,"room":room,"started":frame,"until":frame+ticks,"key":key}
 run.s.dialogue.text_ref = Messages.capture(text,message_id) if text == original else Messages.literal(text)
 run.s.dialogue.name_ref = Messages.capture(run.s.dialogue.name)
 run.s.dialogue.reveal_ticks = ceili(text.length()/CPS*10)

static func start(run, id: String, lines: Array, people: Array) -> void:
 if run.authored_content.get("scenes",{}).has(id):
  var ids: Array[String] = []
  for actor in run.authored_content.instances: ids.append(str(actor))
  var parsed := preload("res://foundation/dialogue.gd").parse(run.authored_content.scenes[id],ids)
  lines = []
  for step in parsed.steps: lines.append([str(step.speaker).to_lower(),step.text,step.commands_before,step.message_id])
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
 if line.size() > 2:
  for command in line[2]:
   if command.name == "delay_guest": run.s.flags.guest_delay_ticks = int(run.s.flags.get("guest_delay_ticks",0)) + int(command.ticks)
 say(run,line[0],line[1],"speech","spoken_%s_%d" % [scene.id,scene.index],0,str(line[3]) if line.size() > 3 else "")
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
    run.note(active.key,active.name+": "+active.text,true,false,Messages.make_ref("UI_SPOKEN_LINE", {"speaker":active.get("name_ref",Messages.literal(active.name)),"line":active.get("text_ref",Messages.literal(active.text))},active.name+": "+active.text))
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
 if not run.authored_content.is_empty():
  preload("res://mission1/authoring_runtime.gd").play_conversations(run)
  return
 # Important conversations take precedence over ambient exchanges.
 if run.flag("chat_delay") and run.s.tick < run._chat_departure() and run.s.room == str(run.s.flags.get("chat_room","cabins")):
  start(run,"nephew",[["chatterbox",Text.MISSION1_BEFORE_YOU_GO_YOU_MUST_HEAR_ABOUT_MY_NEPHEW],["guest",Text.MISSION1_COULD_IT_WAIT_THEY_ARE_SERVING_DRINKS],["chatterbox",Text.MISSION1_HE_BOUGHT_A_MOTORCAR_WITHOUT_ASKING_HIS_MOTHER],["guest",Text.MISSION1_HOW_VERY_RASH],["chatterbox",Text.MISSION1_THAT_IS_EXACTLY_WHAT_I_SAID_NOW_LISTEN]],["guest","chatterbox"])
  return
 var a: Dictionary = run.s.actors
 if run.s.room == "controls" and run.flag("trapped") and not run.s.safe.has("chatterbox") and not run.s.dead.has("chatterbox"):
  start(run,"steam_help",[["chatterbox",Text.MISSION1_HELP_THE_STEAM_HAS_CUT_OFF_THE_PASSAGE]],["chatterbox"])
  if not run.s.dialogue.is_empty(): return
 if run.s.room == "docks" and not run.flag("bag_found"):
  if a.dock_sailor.action == "talk":
   start(run,"bags",[["guest",Text.MISSION1_WHERE_ARE_MY_BAGS_I_WILL_NOT_BOARD_WITHOUT_THEM],["dock_sailor",Text.MISSION1_I_LL_SEARCH_THE_LUGGAGE_SIR],["guest",Text.MISSION1_BROWN_LEATHER_WITH_MY_INITIALS],["dock_sailor",Text.MISSION1_STAY_HERE_I_LL_BRING_THEM_OVER]],["guest","dock_sailor"])
  elif run.nearby("docks",Rooms.point(a.guest.pos),110):
   start(run,"bags_waiting",[["guest",Text.MISSION1_MY_BROWN_SUITCASE_IS_STILL_MISSING_I_M_WAITING_HERE]],["guest"])
  return
 for pair in [["chandelier_guest","porter","directions",[["chandelier_guest",Text.MISSION1_WHICH_WAY_TO_THE_SALON],["porter",Text.MISSION1_UP_THE_CENTRE_STAIR_MADAM]]],["chandelier_guest","chatterbox","weather",[["chandelier_guest",Text.MISSION1_A_LOVELY_EVENING_FOR_A_DEPARTURE],["chatterbox",Text.MISSION1_PROVIDED_THE_SEA_REMEMBERS_ITS_MANNERS]]],["chatterbox","guest","cabins",[["chatterbox",Text.MISSION1_ARE_YOU_SETTLING_INTO_YOUR_CABIN],["guest",Text.MISSION1_AT_LAST_I_THOUGHT_MY_LUGGAGE_HAD_TAKEN_ITS_OWN_HOLIDAY]]]]:
  if not a.has(pair[0]) or not a.has(pair[1]): continue
  var first: Dictionary = a[pair[0]]
  var second: Dictionary = a[pair[1]]
  if first.room == run.s.room and second.room == run.s.room and first.action == "talk" and second.action in ["talk","idle"] and Rooms.point(first.pos).distance_to(Rooms.point(second.pos)) < 100:
   start(run,pair[2],pair[3],[pair[0],pair[1]])
   if not run.s.dialogue.is_empty(): return
