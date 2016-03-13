
class EmbeddedAssets
{
	/** ATTENTION: Naming conventions!
	 *  
	 *  - Classes for embedded IMAGES should have the exact same name as the file,
	 *	without extension. This is required so that references from XMLs (atlas, bitmap font)
	 *	won't break.
	 *	
	 *  - Atlas and Font XML files can have an arbitrary name, since they are never
	 *	referenced by file name.
	 * 
	 */
	
	// Texture Atlas
	
	@:meta(Embed(source="../../demo/assets/textures/1x/atlas.xml",mimeType="application/octet-stream"))

	public static var atlas_xml:Class<Dynamic>;
	
	@:meta(Embed(source="../../demo/assets/textures/1x/atlas.png"))

	public static var atlas:Class<Dynamic>;
	
	// Bitmap textures
	
	@:meta(Embed(source="../../demo/assets/textures/1x/background.jpg"))

	public static var background:Class<Dynamic>;
	
	// Compressed textures
	
	@:meta(Embed(source="../../demo/assets/textures/1x/compressed_texture.atf",mimeType="application/octet-stream"))

	public static var compressed_texture:Class<Dynamic>;
	
	// Bitmap Fonts
	
	@:meta(Embed(source="../../demo/assets/fonts/1x/desyrel.fnt",mimeType="application/octet-stream"))

	public static var desyrel_fnt:Class<Dynamic>;
	
	@:meta(Embed(source="../../demo/assets/fonts/1x/desyrel.png"))

	public static var desyrel:Class<Dynamic>;
	
	// Sounds
	
	@:meta(Embed(source="../../demo/assets/audio/wing_flap.mp3"))

	public static var wing_flap:Class<Dynamic>;

	public function new()
	{
	}
}
