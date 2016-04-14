package starling.openfl; #if (!flash)

@:native("openfl.display3D.Context3DTextureFormat") enum Context3DTextureFormat {
	
	BGRA;
	BGRA_PACKED;
	BGR_PACKED;
	COMPRESSED;
	COMPRESSED_ALPHA;
	RGBA_HALF_FLOAT;
	
}
#else
typedef Context3DTextureFormat = openfl.display3D.Context3DTextureFormat;
#end