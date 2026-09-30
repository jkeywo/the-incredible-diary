extends SceneTree
## Pack imagegen frames without repainting the source art.
const GUESTS := ["guest_male_jacket", "guest_female_dress", "guest_female_coat", "guest_male_waistcoat"]

func _initialize() -> void:
	var source := Image.load_from_file("res://assets/characters/generic/source/guest_waves.png")
	for row in 4:
		var poses: Array[Image] = []
		var bounds: Array[Rect2i] = []
		var tallest := 0
		# Column zero raises the opposite arm; use the five consistent right-arm poses.
		for column in range(1,6):
			var top := roundi(row*source.get_height()/4.0)
			var bottom := roundi((row+1)*source.get_height()/4.0)
			var pose := source.get_region(Rect2i(column*209,top,209,bottom-top))
			for y in pose.get_height():
				for x in pose.get_width():
					var color := pose.get_pixel(x,y)
					if color.a < 0.5: pose.set_pixel(x,y,Color.TRANSPARENT)
			var box := pose.get_used_rect()
			poses.append(pose)
			bounds.append(box)
			tallest = maxi(tallest,box.size.y)
		var scale := 46.0/tallest
		var sheet := Image.create(32*5,48,false,Image.FORMAT_RGBA8)
		for i in 5:
			var box := bounds[i]
			var feet := poses[i].get_region(Rect2i(0,box.end.y-20,209,20)).get_used_rect()
			var center := feet.position.x+feet.size.x*0.5
			var pose := poses[i].get_region(box)
			pose.resize(roundi(box.size.x*scale),roundi(box.size.y*scale),Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(pose,Rect2i(Vector2i.ZERO,pose.get_size()),Vector2i(i*32+roundi(16-(center-box.position.x)*scale),48-pose.get_height()))
		var mask := Image.create(160,48,false,Image.FORMAT_RGBA8)
		for y in 48:
			for x in 160:
				var c := sheet.get_pixel(x,y)
				c.a = 1.0 if c.a >= 0.5 else 0.0
				sheet.set_pixel(x,y,c)
				if c.a == 0: continue
				var garment := (c.h >= 0.46 and c.h <= 0.61 and c.s > 0.23 and c.v > 0.15) if row < 2 else (c.h >= 0.72 and c.h <= 0.91 and c.s > 0.23 and c.v > 0.18) if row == 2 else (y >= 14 and y <= 34 and c.h >= 0.015 and c.h <= 0.105 and c.s > 0.54 and c.g < 0.57)
				var skin := c.h >= 0.015 and c.h <= 0.13 and c.s >= 0.22 and c.s <= 0.78 and c.v > 0.37 and c.r > c.g+0.059 and c.g > c.b+0.031 and y < (35 if row == 2 else 43)
				mask.set_pixel(x,y,Color.GREEN if garment else Color.RED if skin else Color.BLACK)
		sheet.save_png("res://assets/characters/generic/%s_wave.png" % GUESTS[row])
		mask.save_png("res://assets/characters/generic/%s_wave_mask.png" % GUESTS[row])
	print("GUEST WAVE ART PACKED")
	quit()
