if (interaction_outline && COLOR.a > 0.1) {
 float edge = 1.0;
 for (int x=-1; x<=1; x++) {
  for (int y=-1; y<=1; y++) {
   vec2 adjacent = UV+vec2(float(x),float(y))*TEXTURE_PIXEL_SIZE;
   vec2 pixel_at = adjacent/TEXTURE_PIXEL_SIZE-frame_origin;
   if (pixel_at.x < 0.0 || pixel_at.y < 0.0 || pixel_at.x >= outline_frame_size.x || pixel_at.y >= outline_frame_size.y) { edge = 0.0; }
   else {
    if (plant_feet && pixel_at.y >= foot_row) adjacent += plant_shift*TEXTURE_PIXEL_SIZE;
    edge = min(edge,texture(TEXTURE,adjacent).a);
   }
  }
 }
 if (edge < 0.2) COLOR.rgb = vec3(1.0,0.79,0.30);
}
