package starling.utils;

import haxe.Timer;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Loader;
import openfl.display.LoaderInfo;
import openfl.display3D.Context3DTextureFormat;
import openfl.errors.ArgumentError;
import openfl.errors.Error;
import openfl.events.HTTPStatusEvent;
import openfl.events.IOErrorEvent;
import openfl.events.ProgressEvent;
import openfl.events.SecurityErrorEvent;
import openfl.media.Sound;
import openfl.media.SoundChannel;
import openfl.media.SoundTransform;
import openfl.net.URLLoader;
import openfl.net.URLLoaderDataFormat;
import openfl.net.URLRequest;
import openfl.system.LoaderContext;
import openfl.system.System;
import openfl.utils.ByteArray;

import starling.core.Starling;
import starling.events.Event;
import starling.events.EventDispatcher;
import starling.text.BitmapFont;
import starling.text.TextField;
import starling.textures.AtfData;
import starling.textures.Texture;
import starling.textures.TextureAtlas;
import starling.textures.TextureOptions;

/** Dispatched when all textures have been restored after a context loss. */
@:meta(Event(name='texturesRestored', type='starling.events.Event'))

/** Dispatched when an URLLoader fails with an IO_ERROR while processing the queue.
 *  The 'data' property of the Event contains the URL-String that could not be loaded. */
@:meta(Event(name='ioError', type='starling.events.Event'))

/** Dispatched when an URLLoader fails with a SECURITY_ERROR while processing the queue.
 *  The 'data' property of the Event contains the URL-String that could not be loaded. */
@:meta(Event(name='securityError', type='starling.events.Event'))

/** Dispatched when an Xml or JSON file couldn't be parsed.
 *  The 'data' property of the Event contains the name of the asset that could not be parsed. */
@:meta(Event(name='parseError', type='starling.events.Event'))

/** The AssetManager handles loading and accessing a variety of asset types. You can 
 *  add assets directly (via the 'add...' methods) or asynchronously via a queue. This allows
 *  you to deal with assets in a unified way, no matter if they are loaded from a file, 
 *  directory, URL, or from an embedded object.
 *  
 *  <p>The class can deal with the following media types:
 *  <ul>
 *    <li>Textures, either from Bitmaps or ATF data</li>
 *    <li>Texture atlases</li>
 *    <li>Bitmap Fonts</li>
 *    <li>Sounds</li>
 *    <li>Xml data</li>
 *    <li>JSON data</li>
 *    <li>ByteArrays</li>
 *  </ul>
 *  </p>
 *  
 *  <p>For more information on how to add assets from different sources, read the documentation
 *  of the "enqueue()" method.</p>
 * 
 *  <strong>Context Loss</strong>
 *  
 *  <p>When the stage3D context is lost (and you have enabled 'Starling.handleLostContext'),
 *  the AssetManager will automatically restore all loaded textures. To save memory, it will
 *  get them from their original sources. Since this is done asynchronously, your images might
 *  not reappear all at once, but during a timeframe of several seconds. If you want, you can
 *  pause your game during that time; the AssetManager dispatches an "Event.TEXTURES_RESTORED"
 *  event when all textures have been restored.</p>
 *
 *  <strong>Error handling</strong>
 *
 *  <p>Loading of some assets may fail while the queue is being processed. In that case, the
 *  AssetManager will dispatch events of type "IO_ERROR", "SECURITY_ERROR" or "PARSE_ERROR".
 *  You can listen to those events and handle the errors manually (e.g., you could enqueue
 *  them once again and retry, or provide placeholder textures). Queue processing will
 *  continue even when those events are dispatched.</p>
 *
 *  <strong>Using variable texture formats</strong>
 *
 *  <p>When you enqueue a texture, its properties for "format", "scale", "mipMapping", and
 *  "repeat" will reflect the settings of the AssetManager at the time they were enqueued.
 *  This means that you can enqueue a bunch of textures, then change the settings and enqueue
 *  some more. Like this:</p>
 *
 *  <listing>
 *  var appDir:File = File.applicationDirectory;
 *  var assets:AssetManager = new AssetManager();
 *  
 *  assets.textureFormat = Context3DTextureFormat.BGRA;
 *  assets.enqueue(appDir.resolvePath("textures/32bit"));
 *  
 *  assets.textureFormat = Context3DTextureFormat.BGRA_PACKED;
 *  assets.enqueue(appDir.resolvePath("textures/16bit"));
 *  
 *  assets.loadQueue(...);</listing>
 */
class AssetManager extends EventDispatcher
{
	// This HTTPStatusEvent is only available in AIR
	private static var HTTP_RESPONSE_STATUS:String = "httpResponseStatus";

	private var _starling:Starling;
	private var _numLostTextures:Int;
	private var _numRestoredTextures:Int;
	private var _numLoadingQueues:Int;

	private var _defaultTextureOptions:TextureOptions;
	private var _checkPolicyFile:Bool;
	private var _keepAtlasXmls:Bool;
	private var _keepFontXmls:Bool;
	private var _numConnections:Int;
	private var _verbose:Bool;
	private var _queue:Array<Dynamic>;
	
	private var _textures:Map<String, Texture>;
	private var _atlases:Map<String, TextureAtlas>;
	private var _sounds:Map<String, Sound>;
	private var _xmls:Map<String, Xml>;
	private var _objects:Map<String, Dynamic>;
	private var _byteArrays:Map<String, ByteArray>;
	
	/** helper objects */
	private static var sNames = new Array<String>();
	
	/** Regex for name / extension extraction from URL. */
	private static var NAME_REGEX = ~/([^\?\/\\]+?)(?:\.([\w\-]+))?(?:\?.*)?$/;
	
	
	
	
	
	private var queue(get, null):Array<Dynamic>;
	public var nu_queuedAssets(get, null):Int;
	public var verbose(get, set):Bool;
	public var isLoading(get, null):Bool;
	public var useMipMaps(get, set):Bool;
	public var scaleFactor(get, set):Float;
	public var textureFormat(get, set):Context3DTextureFormat;
	public var checkPolicyFile(get, set):Bool;
	public var keepAtlasXmls(get, set):Bool;
	public var keepFontXmls(get, set):Bool;
	public var numConnections(get, set):Int;
	
	
	/** Create a new AssetManager. The 'scaleFactor' and 'useMipmaps' parameters define
	 *  how enqueued bitmaps will be converted to textures. */
	public function new(scaleFactor:Float=1, useMipmaps:Bool=false)
	{
		_queue = new Array<Dynamic>();
		_defaultTextureOptions = new TextureOptions(scaleFactor, useMipmaps);
		_textures = new Map<String, Texture>();
		_atlases = new Map<String, TextureAtlas>();
		_sounds = new Map<String, Sound>();
		_xmls = new Map<String, Xml>();
		_objects = new Map<String, Dynamic>();
		_byteArrays = new Map<String, ByteArray>();
		_numConnections = 1;
		_verbose = true;
		super();
	}
	
	/** Disposes all contained textures. */
	public function dispose():Void
	{
		for (texture in _textures)
			texture.dispose();
		
		for (atlas in _atlases)
			atlas.dispose();
		
		//for (xml in _xmls)
		//	System.disposeXML(xml);
		
		for (byteArray in _byteArrays)
			byteArray.clear();
	}
	
	// retrieving
	
	/** Returns a texture with a certain name. The method first looks through the directly
	 *  added textures; if no texture with that name is found, it scans through all 
	 *  texture atlases. */
	public function getTexture(name:String):Texture
	{
		if (_textures.exists(name)) {
			return _textures.get(name);
		}
		else
		{
			for (atlas in _atlases)
			{
				var texture:Texture = atlas.getTexture(name);
				if (texture != null) {
					return texture;
				}
			}
			return null;
		}
	}
	
	/** Returns all textures that start with a certain string, sorted alphabetically
	 *  (especially useful for "MovieClip"). */
	public function getTextures(prefix:String="", result:Array<Texture>=null):Array<Texture>
	{
		if (result == null) result = new Array<Texture>();
		
		var names = getTextureNames(prefix, sNames);
		for (name in names)
			result[result.length] = getTexture(name); // avoid 'push'
		
		
		
		sNames.splice(0, sNames.length);
		return result;
	}
	
	/** Returns all texture names that start with a certain string, sorted alphabetically. */
	public function getTextureNames(prefix:String="", result:Array<String>=null):Array<String>
	{
		result = getDictionaryKeys(_textures, prefix, result);
		
		for (atlas in _atlases) {
			result = atlas.getNames(prefix, result);
		}
		
		result.sort( function(a:String, b:String):Int
		{
			a = a.toLowerCase();
			b = b.toLowerCase();
			if (a < b) return -1;
			if (a > b) return 1;
			return 0;
		} );
		return result;
	}
	
	/** Returns a texture atlas with a certain name, or null if it's not found. */
	public function getTextureAtlas(name:String):TextureAtlas
	{
		return cast _atlases[name];
	}
	
	/** Returns a sound with a certain name, or null if it's not found. */
	public function getSound(name:String):Sound
	{
		return _sounds[name];
	}
	
	/** Returns all sound names that start with a certain string, sorted alphabetically.
	 *  If you pass a result Array, the names will be added to that Array. */
	public function getSoundNames(prefix:String="", result:Array<String>=null):Array<String>
	{
		return getDictionaryKeys(_sounds, prefix, result);
	}
	
	/** Generates a new SoundChannel object to play back the sound. This method returns a 
	 *  SoundChannel object, which you can access to stop the sound and to control volume. */ 
	public function playSound(name:String, startTime:Float=0, loops:Int=0, 
							  transform:SoundTransform=null):SoundChannel
	{
		if (_sounds.exists(name))
			return getSound(name).play(startTime, loops, transform);
		else 
			return null;
	}
	
	/** Returns an Xml with a certain name, or null if it's not found. */
	public function getXml(name:String):Xml
	{
		return _xmls[name];
	}
	
	/** Returns all Xml names that start with a certain string, sorted alphabetically. 
	 *  If you pass a result Array, the names will be added to that vector. */
	public function getXmlNames(prefix:String="", result:Array<String>=null):Array<String>
	{
		return getDictionaryKeys(_xmls, prefix, result);
	}

	/** Returns an object with a certain name, or null if it's not found. Enqueued JSON
	 *  data is parsed and can be accessed with this method. */
	public function getObject(name:String):Dynamic
	{
		return _objects[name];
	}
	
	/** Returns all object names that start with a certain string, sorted alphabetically. 
	 *  If you pass a result vector, the names will be added to that vector. */
	public function getObjectNames(prefix:String="", result:Array<String>=null):Array<String>
	{
		return getDictionaryKeys(_objects, prefix, result);
	}
	
	/** Returns a byte array with a certain name, or null if it's not found. */
	public function getByteArray(name:String):ByteArray
	{
		return _byteArrays[name];
	}
	
	/** Returns all byte array names that start with a certain string, sorted alphabetically. 
	 *  If you pass a result vector, the names will be added to that vector. */
	public function getByteArrayNames(prefix:String="", result:Array<String>=null):Array<String>
	{
		return getDictionaryKeys(_byteArrays, prefix, result);
	}
	
	// direct adding
	
	/** Register a texture under a certain name. It will be available right away.
	 *  If the name was already taken, the existing texture will be disposed and replaced
	 *  by the new one. */
	public function addTexture(name:String, texture:Texture):Void
	{
		log("Adding texture '" + name + "'");
		
		if (_textures.exists(name))
		{
			log("Warning: name was already in use; the previous texture will be replaced.");
			_textures[name].dispose();
		}
		
		_textures[name] = texture;
	}
	
	/** Register a texture atlas under a certain name. It will be available right away. 
	 *  If the name was already taken, the existing atlas will be disposed and replaced
	 *  by the new one. */
	public function addTextureAtlas(name:String, atlas:TextureAtlas):Void
	{
		log("Adding texture atlas '" + name + "'");
		
		if (_atlases.exists(name))
		{
			log("Warning: name was already in use; the previous atlas will be replaced.");
			_atlases[name].dispose();
		}
		
		_atlases[name] = atlas;
	}
	
	/** Register a sound under a certain name. It will be available right away.
	 *  If the name was already taken, the existing sound will be replaced by the new one. */
	public function addSound(name:String, sound:Sound):Void
	{
		log("Adding sound '" + name + "'");
		
		if (_sounds.exists(name))
			log("Warning: name was already in use; the previous sound will be replaced.");

		_sounds[name] = sound;
	}
	
	/** Register an Xml object under a certain name. It will be available right away.
	 *  If the name was already taken, the existing Xml will be disposed and replaced
	 *  by the new one. */
	public function addXml(name:String, xml:Xml):Void
	{
		log("Adding Xml '" + name + "'");
		
		if (_xmls.exists(name))
		{
			log("Warning: name was already in use; the previous Xml will be replaced.");
			//System.disposeXML(_xmls[name]);
		}

		_xmls[name] = xml;
	}
	
	/** Register an arbitrary object under a certain name. It will be available right away. 
	 *  If the name was already taken, the existing object will be replaced by the new one. */
	public function addObject(name:String, object:Dynamic):Void
	{
		log("Adding object '" + name + "'");
		
		if (_objects.exists(name))
			log("Warning: name was already in use; the previous object will be replaced.");
		
		_objects[name] = object;
	}
	
	/** Register a byte array under a certain name. It will be available right away.
	 *  If the name was already taken, the existing byte array will be cleared and replaced
	 *  by the new one. */
	public function addByteArray(name:String, byteArray:ByteArray):Void
	{
		log("Adding byte array '" + name + "'");
		
		if (_byteArrays.exists(name))
		{
			log("Warning: name was already in use; the previous byte array will be replaced.");
			_byteArrays[name].clear();
		}
		
		_byteArrays[name] = byteArray;
	}
	
	// removing
	
	/** Removes a certain texture, optionally disposing it. */
	public function removeTexture(name:String, dispose:Bool=true):Void
	{
		log("Removing texture '" + name + "'");
		
		if (dispose && _textures.exists(name))
			_textures[name].dispose();
		
		_textures.remove(name);
	}
	
	/** Removes a certain texture atlas, optionally disposing it. */
	public function removeTextureAtlas(name:String, dispose:Bool=true):Void
	{
		log("Removing texture atlas '" + name + "'");
		
		if (dispose && _atlases.exists(name))
			_atlases[name].dispose();
		
		_atlases.remove(name);
	}
	
	/** Removes a certain sound. */
	public function removeSound(name:String):Void
	{
		log("Removing sound '"+ name + "'");
		_sounds.remove(name);
	}
	
	/** Removes a certain Xml object, optionally disposing it. */
	public function removeXml(name:String, dispose:Bool=true):Void
	{
		log("Removing xml '"+ name + "'");
		
		if (dispose && _xmls.exists(name))
			//System.disposeXML(_xmls[name]);
		
		_xmls.remove(name);
	}
	
	/** Removes a certain object. */
	public function removeObject(name:String):Void
	{
		log("Removing object '"+ name + "'");
		_objects.remove(name);
	}
	
	/** Removes a certain byte array, optionally disposing its memory right away. */
	public function removeByteArray(name:String, dispose:Bool=true):Void
	{
		log("Removing byte array '"+ name + "'");
		
		if (dispose && _byteArrays.exists(name))
			_byteArrays[name].clear();
		
		_byteArrays.remove(name);
	}
	
	/** Empties the queue and aborts any pending load operations. */
	public function purgeQueue():Void
	{
		_queue.splice(0, _queue.length);
		dispatchEventWith(Event.CANCEL);
	}
	
	/** Removes assets of all types, empties the queue and aborts any pending load operations.*/
	public function purge():Void
	{
		log("Purging all assets, emptying queue");
		
		purgeQueue();
		dispose();

		_textures = new Map<String, Texture>();
		_atlases = new Map<String, TextureAtlas>();
		_sounds = new Map<String, Sound>();
		_xmls = new Map<String, Xml>();
		_objects = new Map<String, Dynamic>();
		_byteArrays = new Map<String, ByteArray>();
	}
	
	// queued adding
	
	/** Enqueues one or more raw assets; they will only be available after successfully 
	 *  executing the "loadQueue" method. This method accepts a variety of different objects:
	 *  
	 *  <ul>
	 *    <li>Strings or URLRequests containing an URL to a local or remote resource. Supported
	 *        types: <code>png, jpg, gif, atf, mp3, xml, fnt, json, binary</code>.</li>
	 *    <li>Instances of the File class (AIR only) pointing to a directory or a file.
	 *        Directories will be scanned recursively for all supported types.</li>
	 *    <li>Classes that contain <code>static</code> embedded assets.</li>
	 *    <li>If the file extension is not recognized, the data is analyzed to see if
	 *        contains Xml or JSON data. If it's neither, it is stored as ByteArray.</li>
	 *  </ul>
	 *  
	 *  <p>Suitable object names are extracted automatically: A file named "image.png" will be
	 *  accessible under the name "image". When enqueuing embedded assets via a class, 
	 *  the variable name of the embedded object will be used as its name. An exception
	 *  are texture atlases: they will have the same name as the actual texture they are
	 *  referencing.</p>
	 *  
	 *  <p>XMLs that contain texture atlases or bitmap fonts are processed directly: fonts are
	 *  registered at the TextField class, atlas textures can be acquired with the
	 *  "getTexture()" method. All other XMLs are available via "getXml()".</p>
	 *  
	 *  <p>If you pass in JSON data, it will be parsed into an object and will be available via
	 *  "getObject()".</p>
	 */
	public function enqueue(rawAssets:Dynamic):Void
	{
		if (Std.is(rawAssets, Array)) {
			var rawAssetsArray:Array<Dynamic> = rawAssets;
			for (i in 0...rawAssetsArray.length) 
			{
				enqueueItem(rawAssetsArray[i]);
			}
		}
		else {
			enqueueItem(rawAssets);
		}
	}
	
	private function enqueueItem(rawAssets:Dynamic):Void
	{
		var fields:Array<String> = Reflect.fields(rawAssets);
		//for (rawAsset in rawAssets)
		for (field in fields)
		{
			var child = Reflect.getProperty(rawAssets, field);
			if (Std.is(child, Array))
			{
				enqueue(child);
			}
			/*else if (Std.is(child, Class))
			{
				trace("child = " + child);
				var typeXml:Xml = describeType(child);
				var childNode:Xml;
				
				trace("typeXml = " + typeXml);*/
				
				/*if (_verbose)
					log("Looking for static embedded assets in '" + 
						(typeXml.@name).split("::").pop() + "'"); 
				
				for each (childNode in typeXml.constant.(@type == "Class"))
					enqueueWithName(child[childNode.@name], childNode.@name);
				
				for each (childNode in typeXml.variable.(@type == "Class"))
					enqueueWithName(child[childNode.@name], childNode.@name);*/
			//}
			/*else if (Type.getClassName(Type.getClass(child)) == "flash.filesystem.File")
			{
				if (!child["exists"])
				{
					log("File or directory not found: '" + child["url"] + "'");
				}
				else if (!child["isHidden"])
				{
					if (child["isDirectory"])
						enqueue.apply(this, child["getDirectoryListing"]());
					else
						enqueueWithName(child);
				}
			}*/
			else if (Std.is(child, String) || Std.is(child, URLRequest))
			{
				enqueueWithName(child);
			}
			else
			{
				log("Ignoring unsupported asset type: " + Type.getClassName(Type.getClass(child)));
			}
		}
	}
	
	/** Enqueues a single asset with a custom name that can be used to access it later.
	 *  If the asset is a texture, you can also add custom texture options.
	 *  
	 *  @param asset    The asset that will be enqueued; accepts the same objects as the
	 *                  'enqueue' method.
	 *  @param name     The name under which the asset will be found later. If you pass null or
	 *                  omit the parameter, it's attempted to generate a name automatically.
	 *  @param options  Custom options that will be used if 'asset' points to texture data.
	 *  @return         the name with which the asset was registered.
	 */
	public function enqueueWithName(asset:Dynamic, name:String=null,
									options:TextureOptions=null):String
	{
		trace("CHECK");
		if (Type.getClassName(Type.getClass(asset)) == "flash.filesystem.File")
			asset = StringTools.urlDecode(Reflect.getProperty(asset, "url"));
		
		if (name == null)    name = getName(asset);
		if (options == null) options = _defaultTextureOptions.clone();
		else                 options = options.clone();
		
		log("Enqueuing '" + name + "'");
		
		_queue.push({
			name: name,
			asset: asset,
			options: options
		});
		
		return name;
	}
	
	/** Loads all enqueued assets asynchronously. The 'onProgress' function will be called
	 *  with a 'ratio' between '0.0' and '1.0', with '1.0' meaning that it's complete.
	 *
	 *  <p>When you call this method, the manager will save a reference to "Starling.Current";
	 *  all textures that are loaded will be accessible only from within this instance. Thus,
	 *  if you are working with more than one Starling instance, be sure to call
	 *  "makeCurrent()" on the appropriate instance before processing the queue.</p>
	 *
	 *  @param onProgress <code>function(ratio:Float):Void;</code>
	 */
	public function loadQueue(onProgress:AssetFunction):Void
	{
		if (onProgress == null)
			throw new ArgumentError("Argument 'onProgress' must not be null");
		
		if (_queue.length == 0)
		{
			onProgress(1.0);
			return;
		}

		_starling = Starling.Current;
		
		if (_starling == null || _starling.context == null)
			throw new Error("The Starling instance needs to be ready before assets can be loaded.");

		var PROGRESS_PART_ASSETS:Float = 0.9;
		var PROGRESS_PART_XMLS:Float = 1.0 - PROGRESS_PART_ASSETS;

		var i:Int;
		var canceled:Bool = false;
		var xmls = new Array<Xml>();
		var assetInfos = _queue.concat(new Array<Dynamic>());
		for (j in 0..._queue.length) 
		{
			assetInfos.push(_queue[j]);
		}
		
		var assetCount:Int = _queue.length;
		var assetProgress = new Array<Float>();
		var assetIndex:Int = 0;
		
		var updateAssetProgress:AssetFunction = null;
		var loadQueueElement:AssetFunction = null;
		var loadNextQueueElement:AssetFunction = null;
		var processXmls:AssetFunction = null;
		var processXml:AssetFunction = null;
		var cancel:AssetFunction = null;
		var finish:AssetFunction = null;
		
		updateAssetProgress = function(index:Int, progress:Float):Void
		{
			assetProgress[index] = progress;

			var sum:Float = 0.0;
			var len:Int = assetProgress.length;

			for (i in 0...len)
				sum += assetProgress[i];

			onProgress(sum / len * PROGRESS_PART_ASSETS);
		};
		
		loadQueueElement = function(index:Int, assetInfo:Dynamic):Void
		{
			if (canceled) return;
			
			var onElementProgress:AssetFunction = function(progress:Float):Void
			{
				updateAssetProgress(index, progress * 0.8); // keep 20 % for completion
			};
			var onElementLoaded:AssetFunction = function():Void
			{
				updateAssetProgress(index, 1.0);
				assetCount--;

				if (assetCount > 0) loadNextQueueElement();
				else                processXmls();
			};
			
			processRawAsset(assetInfo.name, assetInfo.asset, assetInfo.options,
				xmls, onElementProgress, onElementLoaded);
		};
		
		loadNextQueueElement = function():Void
		{
			if (assetIndex < assetInfos.length)
			{
				// increment asset index *before* using it, since
				// 'loadQueueElement' could by synchronous in subclasses.
				var index:Int = assetIndex++;
				loadQueueElement(index, assetInfos[index]);
			}
		};
		
		processXmls = function():Void
		{
			// xmls are processed separately at the end, because the textures they reference
			// have to be available for other XMLs. Texture atlases are processed first:
			// that way, their textures can be referenced, too.
			
			trace("FIX");
			/*xmls.sort(function(a:Xml, b:Xml):Int { 
				return a.localName() == "TextureAtlas" ? -1 : 1; 
			});*/

			//Timer.delay(processXml, 1); //setTimeout(processXml, 1, 0);
			Timer.delay(function () {
				processXml(0);
			}, 1);
		};
		
		processXml = function(index:Int):Void
		{
			if (canceled) return;
			else if (index == xmls.length)
			{
				finish();
				return;
			}
			
			trace("FIX");
			var name:String;
			var texture:Texture;
			var xml:Xml = xmls[index];
			var rootNode:String = "";
			var xmlProgress:Float = (index + 1) / (xmls.length + 1);
			
			var firstElement:Xml = xml.firstElement();
			if(firstElement.nodeType == Xml.Element ) {
				rootNode = firstElement.nodeName;
			}
			
			
			if (rootNode == "TextureAtlas")
			{
				name = firstElement.get("imagePath").split(".")[0];// name = getName(xml.@imagePath.toString());
				texture = getTexture(name);
				
				if (texture != null)
				{
					addTextureAtlas(name, new TextureAtlas(texture, xml));
					removeTexture(name, false);
					
					if (_keepAtlasXmls) addXml(name, xml);
					//else System.disposeXML(xml);
				}
				else log("Cannot create atlas: texture '" + name + "' is missing.");
			}
			else if (rootNode == "font")
			{
				name = "";
				for (font in xml.elementsNamed("font")) {
					if (font.nodeType == Xml.Element ) {
						for (pages in font.elementsNamed("pages")) {
							if (pages.nodeType == Xml.Element ) {
								for (page in pages.elementsNamed("page")) {
									if (page.nodeType == Xml.Element ) {
										name = page.get("file").split(".")[0];
									}
								}
							}
						}
					}
				}
				
				texture = getTexture(name);
				
				if (texture != null)
				{
					log("Adding bitmap font '" + name + "'");
					TextField.registerBitmapFont(new BitmapFont(texture, xml), name);
					removeTexture(name, false);
					
					if (_keepFontXmls) addXml(name, xml);
					//else System.disposeXML(xml);
				}
				else log("Cannot create bitmap font: texture '" + name + "' is missing.");
			}
			else
				throw new Error("Xml contents not recognized: " + rootNode);
			
			onProgress(PROGRESS_PART_ASSETS + PROGRESS_PART_XMLS * xmlProgress);
			//setTimeout(processXml, 1, index + 1);
			Timer.delay(function () {
				processXml(index + 1);
			}, 1);
		};
		
		cancel = function():Void
		{
			removeEventListener(Event.CANCEL, cancel);
			_numLoadingQueues--;
			canceled = true;
		};
		
		finish = function():Void
		{
			// now would be a good time for a clean-up
			//System.pauseForGCIfCollectionImminent(0);
			System.gc();

			// We dance around the final "onProgress" call with some "setTimeout" calls here
			// to make sure the progress bar gets the chance to be rendered. Otherwise, all
			// would happen in one frame.
			
			Timer.delay(function():Void
			{
				if (!canceled)
				{
					cancel();
					onProgress(1.0);
				}
			}, 1);
		};
		
		for (i in 0...assetCount)
			assetProgress[i] = 0.0;

		for (i in 0..._numConnections)
			loadNextQueueElement();
		
		_queue.splice(0, _queue.length);
		_numLoadingQueues++;
		addEventListener(Event.CANCEL, cancel);
	}
	
	private function processRawAsset(name:String, rawAsset:Dynamic, options:TextureOptions,
									 xmls:Array<Xml>,
									 onProgress:AssetFunction, onComplete:AssetFunction):Void
	{
		var canceled:Bool = false;
		var process:AssetFunction = null;
		var progress:AssetFunction = null;
		var cancel:AssetFunction = null;
		
		process = function(asset:Dynamic):Void
		{
			var texture:Texture;
			var bytes:ByteArray;
			var object:Dynamic = null;
			var xml:Xml = null;
			
			// the 'current' instance might have changed by now
			// if we're running in a set-up with multiple instances.
			_starling.makeCurrent();
			
			if (canceled)
			{
				// do nothing
			}
			else if (asset == null)
			{
				onComplete();
			}
			else if (Std.is(asset, Sound))
			{
				addSound(name, cast asset);
				onComplete();
			}
			else if (Std.is(asset, Xml))
			{
				trace("CHECK");
				xml = cast asset;
				
				var firstNodeName:String = "";
				if( xml.firstElement().nodeType == Xml.Element ) {
					firstNodeName = xml.firstElement().nodeName;
				}
				
				if (firstNodeName == "TextureAtlas" || firstNodeName == "font")
					xmls.push(xml);
				else
					addXml(name, xml);
				
				onComplete();
			}
			else if (_starling.context.driverInfo == "Disposed")
			{
				log("Context lost while processing assets, retrying ...");
				Timer.delay(function () {
					process(asset);
				}, 1);
				return; // to keep CANCEL event listener intact
			}
			else if (Std.is(asset, Bitmap))
			{
				texture = Texture.fromData(asset, options);
				texture.root.onRestore = function():Void
				{
					_numLostTextures++;
					loadRawAsset(rawAsset, null, function(asset:Dynamic):Void
					{
						try { texture.root.uploadBitmap(cast asset); }
						catch (e:Error) { log("Texture restoration failed: " + e.message); }
						
						asset.bitmapData.dispose();
						_numRestoredTextures++;
						
						if (_numLostTextures == _numRestoredTextures)
							dispatchEventWith(Event.TEXTURES_RESTORED);
					});
				};

				asset.bitmapData.dispose();
				addTexture(name, texture);
				onComplete();
			}
			else if (Std.is(asset, BitmapData))
			{
				texture = Texture.fromData(asset, options);
				texture.root.onRestore = function():Void
				{
					_numLostTextures++;
					loadRawAsset(rawAsset, null, function(asset:Dynamic):Void
					{
						try { texture.root.uploadBitmapData(cast asset); }
						catch (e:Error) { log("Texture restoration failed: " + e.message); }
						
						asset.dispose();
						_numRestoredTextures++;
						
						if (_numLostTextures == _numRestoredTextures)
							dispatchEventWith(Event.TEXTURES_RESTORED);
					});
				};

				asset.dispose();
				addTexture(name, texture);
				onComplete();
			}
			else if (Std.is(asset, ByteArrayData))
			{
				bytes = cast asset;
				
				var isAtfData = AtfData.isAtfData(bytes);
				if (isAtfData)
				{
					options.onReady = prependCallback(options.onReady, onComplete);
					texture = Texture.fromData(bytes, options);
					texture.root.onRestore = function():Void
					{
						_numLostTextures++;
						loadRawAsset(rawAsset, null, function(asset:Dynamic):Void
						{
							try { texture.root.uploadAtfData(cast asset, 0, true); }
							catch (e:Error) { log("Texture restoration failed: " + e.message); }
							
							asset.clear();
							_numRestoredTextures++;
							
							if (_numLostTextures == _numRestoredTextures)
								dispatchEventWith(Event.TEXTURES_RESTORED);
						});
					};
					
					bytes.clear();
					addTexture(name, texture);
					onComplete();
				}
				else if (byteArrayStartsWith(bytes, "{") || byteArrayStartsWith(bytes, "["))
				{
					trace("FIX");
					/*try { object = JSON.parse(bytes.readUTFBytes(bytes.length)); }
					catch (e:Error)
					{
						log("Could not parse JSON: " + e.message);
						dispatchEventWith(Event.PARSE_ERROR, false, name);
					}

					if (object) addObject(name, object);

					bytes.clear();
					onComplete();*/
				}
				else if (byteArrayStartsWith(bytes, "<"))
				{
					trace("FIX");
					/*try { xml = Xml.parse(bytes); }
					catch (e:Error)
					{
						log("Could not parse Xml: " + e.message);
						dispatchEventWith(Event.PARSE_ERROR, false, name);
					}

					process(xml);
					bytes.clear();*/
				}
				else
				{
					addByteArray(name, bytes);
					onComplete();
				}
			}
			else
			{
				addObject(name, asset);
				onComplete();
			}
			
			// avoid that objects stay in memory (through 'onRestore' functions)
			asset = null;
			bytes = null;
			
			removeEventListener(Event.CANCEL, cancel);
		};
		
		progress = function(ratio:Float):Void
		{
			if (!canceled) onProgress(ratio);
		};
		
		cancel = function():Void
		{
			canceled = true;
		};
		
		addEventListener(Event.CANCEL, cancel);
		loadRawAsset(rawAsset, progress, process);
	}
	
	/** This method is called internally for each element of the queue when it is loaded.
	 *  'rawAsset' is typically either a class (pointing to an embedded asset) or a string
	 *  (containing the path to a file). For texture data, it will also be called after a
	 *  context loss.
	 *
	 *  <p>The method has to transform this object into one of the types that the AssetManager
	 *  can work with, e.g. a Bitmap, a Sound, Xml data, or a ByteArray. This object needs to
	 *  be passed to the 'onComplete' callback.</p>
	 *
	 *  <p>The calling method will then process this data accordingly (e.g. a Bitmap will be
	 *  transformed into a texture). Unknown types will be available via 'getObject()'.</p>
	 *
	 *  <p>When overriding this method, you can call 'onProgress' with a number between 0 and 1
	 *  to update the total queue loading progress.</p>
	 */
	private function loadRawAsset(rawAsset:Dynamic, onProgress:AssetFunction, onComplete:AssetFunction):Void
	{
		var onIoError:AssetFunction = null;
		var onSecurityError:AssetFunction = null;
		var onHttpResponseStatus:AssetFunction = null;
		var onLoadProgress:AssetFunction = null;
		var onUrlLoaderComplete:AssetFunction = null;
		var onLoaderComplete:AssetFunction = null;
		var complete:AssetFunction = null;
		
		var extension:String = null;
		var loaderInfo:LoaderInfo = null;
		var urlLoader:URLLoader = null;
		var urlRequest:URLRequest = null;
		var url:String = null;
		
		onIoError = function(event:IOErrorEvent):Void
		{
			log("IO error: " + event.text);
			dispatchEventWith(Event.IO_ERROR, false, url);
			complete(null);
		};

		onSecurityError = function(event:SecurityErrorEvent):Void
		{
			log("security error: " + event.text);
			dispatchEventWith(Event.SECURITY_ERROR, false, url);
			complete(null);
		};

		onHttpResponseStatus = function(event:HTTPStatusEvent):Void
		{
			trace("FIX");
			/*if (extension == null)
			{
				var headers:Array<Dynamic> = event.responseHeaders;// event["responseHeaders"];
				var contentType:String = getHttpHeader(headers, "Content-Type");

				if (contentType != null && ~/(audio|image)\//.exec(contentType))
					extension = contentType.split("/").pop();
			}*/
		};

		onLoadProgress = function(event:ProgressEvent):Void
		{
			if (onProgress != null && event.bytesTotal > 0)
				onProgress(event.bytesLoaded / event.bytesTotal);
		};
		
		onUrlLoaderComplete = function(event:Dynamic):Void
		{
			var bytes:ByteArray = transformData(cast urlLoader.data, url);
			var sound:Sound;
			
			if (bytes == null)
			{
				complete(null);
				return;
			}
			
			if (extension != null)
				extension = extension.toLowerCase();
			
			switch (extension)
			{
				case "mpeg":
				case "mp3":
					sound = new Sound();
					sound.loadCompressedDataFromByteArray(bytes, bytes.length);
					bytes.clear();
					complete(sound);
				case "jpg":
				case "jpeg":
				case "png":
				case "gif":
					var loaderContext:LoaderContext = new LoaderContext(_checkPolicyFile);
					var loader:Loader = new Loader();
					//loaderContext.imageDecodingPolicy = ImageDecodingPolicy.ON_LOAD;
					loaderInfo = loader.contentLoaderInfo;
					loaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
					loaderInfo.addEventListener(Event.COMPLETE, onLoaderComplete);
					loader.loadBytes(bytes); // loader.loadBytes(bytes, loaderContext);
				default: // any Xml / JSON / binary data 
					complete(bytes);
			}
		};
		
		onLoaderComplete = function(event:Dynamic):Void
		{
			urlLoader.data.clear();
			complete(event.target.content);
		};
		
		complete = function(asset:Dynamic):Void
		{
			// clean up event listeners
			
			if (urlLoader != null)
			{
				urlLoader.removeEventListener(IOErrorEvent.IO_ERROR, onIoError);
				urlLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
				urlLoader.removeEventListener(HTTP_RESPONSE_STATUS, onHttpResponseStatus);
				urlLoader.removeEventListener(ProgressEvent.PROGRESS, onLoadProgress);
				urlLoader.removeEventListener(Event.COMPLETE, onUrlLoaderComplete);
			}

			if (loaderInfo != null)
			{
				loaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onIoError);
				loaderInfo.removeEventListener(Event.COMPLETE, onLoaderComplete);
			}

			// On mobile, it is not allowed / endorsed to make stage3D calls while the app
			// is in the background. Thus, we pause queue processing if that's the case.
			
			//if (SystemUtil.isDesktop)
				onComplete(asset);
			//else
			//	SystemUtil.executeWhenApplicationIsActive(onComplete, asset);
		};
		
		
		if (Std.is(rawAsset, Class))
		{
			Timer.delay(function () { // setTimeout(complete, 1, Type.createInstance(rawAsset));
				complete(Type.createInstance(rawAsset, []));
			}, 1);
		}
		else if (Std.is(rawAsset, String) || Std.is(rawAsset, URLRequest))
		{
			if (Std.is(rawAsset, String)) {
				urlRequest = new URLRequest(rawAsset);
			}
			else {
				urlRequest = cast rawAsset;
			}
			
			//if (urlRequest == null) urlRequest = new URLRequest(cast rawAsset);
			url = urlRequest.url;
			extension = getExtensionFromUrl(url);

			urlLoader = new URLLoader();
			urlLoader.dataFormat = URLLoaderDataFormat.BINARY;
			urlLoader.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
			urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
			urlLoader.addEventListener(HTTP_RESPONSE_STATUS, onHttpResponseStatus);
			urlLoader.addEventListener(ProgressEvent.PROGRESS, onLoadProgress);
			urlLoader.addEventListener(Event.COMPLETE, onUrlLoaderComplete);
			urlLoader.load(urlRequest);
		}
		else if (Std.is(rawAsset, Dynamic)) {
			Timer.delay(function () {
				complete(rawAsset);
			}, 1);
		}
	}
	
	// helpers

	/** This method is called by 'enqueue' to determine the name under which an asset will be
	 *  accessible; override it if you need a custom naming scheme. Note that this method won't
	 *  be called for embedded assets.
	 *
	 *  @param rawAsset   either a String, an URLRequest or a FileReference.
	 */
	private function getName(rawAsset:Dynamic):String
	{
		var name:String = null;

		if      (Std.is(rawAsset, String))        name =  cast(rawAsset, String);
		else if (Std.is(rawAsset, URLRequest))    name =  cast(rawAsset, URLRequest).url;
		//else if (Std.is(rawAsset, FileReference)) name =  cast(rawAsset, FileReference).name;

		if (name != null)
		{
			name = StringTools.replace(name, "%20", " ");// name.replace(~/%20/g, " "); // URLs use '%20' for spaces
			name = getBasenameFromUrl(name);

			if (name != null) return name;
			else throw new ArgumentError("Could not extract name from String '" + rawAsset + "'");
		}
		else
		{
			name = Type.getClassName(Type.getClass(rawAsset));
			throw new ArgumentError("Cannot extract names for objects of type '" + name + "'");
		}
	}

	/** This method is called when raw byte data has been loaded from an URL or a file.
	 *  Override it to process the downloaded data in some way (e.g. decompression) or
	 *  to cache it on disk.
	 *
	 *  <p>It's okay to call one (or more) of the 'add...' methods from here. If the binary
	 *  data contains multiple objects, this allows you to process all of them at once.
	 *  Return 'null' to abort processing of the current item.</p> */
	private function transformData(data:ByteArray, url:String):ByteArray
	{
		return data;
	}

	/** This method is called during loading of assets when 'verbose' is activated. Per
	 *  default, it traces 'message' to the console. */
	private function log(message:String):Void
	{
		if (_verbose) trace("[AssetManager]", message);
	}
	
	private function byteArrayStartsWith(bytes:ByteArray, char:String):Bool
	{
		var start:Int = 0;
		var length:Int = bytes.length;
		var wanted:Int = char.charCodeAt(0);
		
		var b0:Int = 0;
		var b1:Int = 0;
		var b2:Int = 0;
		var b3:Int = 0;
		
		
		var pass:Bool = false;
		// recognize BOMs
		if (pass == false && length >= 4) {
			bytes.position = 0;
			b0 = bytes.readByte();
			b1 = bytes.readByte();
			b2 = bytes.readByte();
			b3 = bytes.readByte();
			
			if ((b0 == 0x00 && b1 == 0x00 && b2 == 0xfe && b3 == 0xff) || (b0 == 0xff && b1 == 0xfe && b2 == 0x00 && b3 == 0x00)) {
				start = 4; // UTF-32
				pass = true;
			}
		}
		if (pass == false && length >= 3) {
			bytes.position = 0;
			b0 = bytes.readByte();
			b1 = bytes.readByte();
			b2 = bytes.readByte();
			
			if (b0 == 0xef && b1 == 0xbb && b2 == 0xbf) {
				start = 3; // UTF-8
				pass = true;
			}
		}
		if (pass == false && length >= 2) {
			bytes.position = 0;
			b0 = bytes.readByte();
			b1 = bytes.readByte();
			
			if ((b0 == 0xfe && b1 == 0xff) || (b0 == 0xff && b1 == 0xfe)) {
				start = 2; // UTF-16
				pass = true;
			}
		}
		
		// find first meaningful letter
		
		bytes.position = start;
		for (i in start...length)
		{
			
			var byte:Int = bytes.readByte();// bytes[i];
			if (byte == 0 || byte == 10 || byte == 13 || byte == 32) continue; // null, \n, \r, space
			else return byte == wanted;
		}
		
		return false;
	}
	
	private function getDictionaryKeys(map:Map<String,Dynamic>, prefix:String="", result:Array<String>=null):Array<String>
	{
		if (result == null) result = new Array<String>();
		
		trace("CHECK!");
		for (key in map.keys())
		{
			if (key.indexOf(prefix) == 0) {
				//result[result.length] = name; // avoid 'push'
				result.push(key); // why do we avoid 'push'?
			}
		}
		/*for (name in map) {
			if (name.indexOf(prefix) == 0) {
				//result[result.length] = name; // avoid 'push'
				result.push(cast name); // why do we avoid 'push'?
			}
		}*/
		
		trace("CHECK Array.CASEINSENSITIVE is needed");
		//result.sort(Array.CASEINSENSITIVE);
		return result;
	}
	
	private function getHttpHeader(headers:Array<Dynamic>, headerName:String):String
	{
		if (headers != null)
		{
			for (i in 0...headers.length) 
			{
				var header:Dynamic = headers[i];
				if (Reflect.getProperty(header, "name") == headerName) return Reflect.getProperty(header, "value");
			}
			//for (var header:Dynamic in headers)
			//	if (header.name == headerName) return header.value;
		}
		return null;
	}

	/** Extracts the base name of a file path or URL, i.e. the file name without extension. */
	private function getBasenameFromUrl(url:String):String
	{
		trace("RESTORE REGEX");
		var split:Array<String> = url.split("/");
		var returnVal:String = split[split.length - 1];
		var split1:Array<String> = url.split(".");
		return split1[0];
		/*var matches:Array = NAME_REGEX.exec(url);
		if (matches && matches.length > 0) return matches[1];
		else return null;*/
	}

	/** Extracts the file extension from an URL. */
	private function getExtensionFromUrl(url:String):String
	{
		trace("RESTORE REGEX");
		var split:Array<String> = url.split("/");
		var returnVal:String = split[split.length - 1];
		var split1:Array<String> = url.split(".");
		return split1[split1.length - 1];
		/*var matches:Array = NAME_REGEX.exec(url);
		if (matches && matches.length > 1) return matches[2];
		else return null;*/
	}

	private function prependCallback(oldCallback:AssetFunction, newCallback:AssetFunction):AssetFunction
	{
		// TODO: it might make sense to add this (together with "appendCallback")
		//       as a public utility method ("FunctionUtil"?)

		if (oldCallback == null) return newCallback;
		else if (newCallback == null) return oldCallback;
		else return function():Void
		{
			newCallback();
			oldCallback();
		};
	}

	// properties
	
	/** The queue contains one 'Dynamic' for each enqueued asset. Each object has 'asset'
	 *  and 'name' properties, pointing to the raw asset and its name, respectively. */
	private function get_queue():Array<Dynamic> { return _queue; }
	
	/** Returns the number of raw assets that have been enqueued, but not yet loaded. */
	private function get_nu_queuedAssets():Int { return _queue.length; }
	
	/** When activated, the class will trace information about added/enqueued assets.
	 *  @default true */
	private function get_verbose():Bool { return _verbose; }
	private function set_verbose(value:Bool):Bool
	{
		_verbose = value;
		return value;
	}
	
	/** Indicates if a queue is currently being loaded. */
	private function get_isLoading():Bool { return _numLoadingQueues > 0; }

	/** For bitmap textures, this flag indicates if mip maps should be generated when they 
	 *  are loaded; for ATF textures, it indicates if mip maps are valid and should be
	 *  used. @default false */
	private function get_useMipMaps():Bool { return _defaultTextureOptions.mipMapping; }
	private function set_useMipMaps(value:Bool):Bool
	{
		_defaultTextureOptions.mipMapping = value;
		return value;
	}
	
	/** Textures that are created from Bitmaps or ATF files will have the scale factor 
	 *  assigned here. @default 1 */
	private function get_scaleFactor():Float { return _defaultTextureOptions.scale; }
	private function set_scaleFactor(value:Float):Float
	{
		_defaultTextureOptions.scale = value;
		return value;
	}

	/** Textures that are created from Bitmaps will be uploaded to the GPU with the
	 *  <code>Context3DTextureFormat</code> assigned to this property. @default "bgra" */
	private function get_textureFormat():Context3DTextureFormat { return _defaultTextureOptions.format; }
	private function set_textureFormat(value:Context3DTextureFormat):Context3DTextureFormat
	{
		_defaultTextureOptions.format = value;
		return value;
	}
	
	/** Specifies whether a check should be made for the existence of a URL policy file before
	 *  loading an object from a remote server. More information about this topic can be found 
	 *  in the 'flash.system.LoaderContext' documentation. @default false */
	private function get_checkPolicyFile():Bool { return _checkPolicyFile; }
	private function set_checkPolicyFile(value:Bool):Bool
	{
		_checkPolicyFile = value;
		return value;
	}

	/** Indicates if atlas Xml data should be stored for access via the 'getXml' method.
	 *  If true, you can access an Xml under the same name as the atlas.
	 *  If false, XMLs will be disposed when the atlas was created. @default false. */
	private function get_keepAtlasXmls():Bool { return _keepAtlasXmls; }
	private function set_keepAtlasXmls(value:Bool):Bool
	{
		_keepAtlasXmls = value;
		return value;
	}

	/** Indicates if bitmap font Xml data should be stored for access via the 'getXml' method.
	 *  If true, you can access an Xml under the same name as the bitmap font.
	 *  If false, XMLs will be disposed when the font was created. @default false. */
	private function get_keepFontXmls():Bool { return _keepFontXmls; }
	private function set_keepFontXmls(value:Bool):Bool
	{
		_keepFontXmls = value;
		return value;
	}

	/** The maximum number of parallel connections that are spawned when loading the queue.
	 *  More connections can reduce loading times, but require more memory. @default 3. */
	private function get_numConnections():Int { return _numConnections; }
	private function set_numConnections(value:Int):Int
	{
		_numConnections = value;
		return value;
	}
}

typedef AssetFunction = Dynamic