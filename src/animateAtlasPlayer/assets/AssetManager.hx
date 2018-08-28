package animateAtlasPlayer.assets;

import animateAtlasPlayer.core.Animation;
import animateAtlasPlayer.core.AnimationAtlas;
import animateAtlasPlayer.core.AnimationAtlasFactory;
import animateAtlasPlayer.textures.TextureAtlas;
import animateAtlasPlayer.utils.ArrayUtil;
import haxe.Json;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.events.EventDispatcher;
import openfl.utils.ByteArray;

class AssetManager extends EventDispatcher
{
	
	public var verbose(get, set) : Bool;
    public var numQueuedAssets(get, never) : Int;
    public var numConnections(get, set) : Int;
    //public var textureOptions(get, set) : TextureOptions;
    //public var dataLoader(get, set) : DataLoader;
    public var registerBitmapFontsWithFontFace(get, set) : Bool;

    //private var _animateAtlasPlayer : animateAtlasPlayer;
    private var _assets : Map<String,Map<String,Dynamic>>;
    private var _verbose : Bool;
    private var _numConnections : Int;
    //private var _dataLoader : DataLoader;
    //private var _textureOptions : TextureOptions;
    private var _queue : Array<AssetReference>;
    private var _registerBitmapFontsWithFontFace : Bool;
    private var _assetFactories : Array<AssetFactory>;
    private var _numRestoredTextures : Int;
    private var _numLostTextures : Int;
   
    private static inline var NO_NAME : String = "unnamed";
    private static var sNoNameCount : Int = 0;
    
    private static var sNames : Array<String> = [];
    
    public function new(scaleFactor : Float = 1)
    {
        super();
        _assets = new Map<String,Map<String,Dynamic>>();
        _verbose = true;
        //_textureOptions = new TextureOptions(scaleFactor);
        _queue = [];
        _numConnections = 3;
        //_dataLoader = new DataLoader();
        _assetFactories = [];
        
        //registerFactory(new BitmapTextureFactory());
        //registerFactory(new AtfTextureFactory());
        //registerFactory(new SoundFactory());
        registerFactory(new JsonFactory());
        //registerFactory(new XmlFactory());
        //registerFactory(new ByteArrayFactory(), -100);
		registerFactory(new AnimationAtlasFactory(), 10);
    }
	
	public function enqueue(url : String) : Void {
		if (getExtensionFromUrl(url) == "zip") {
			trace ("TODO: zip files");
		} else {
			enqueueSingle(url+"/spritemap.json");
			enqueueSingle(url+"/Animation.json");
			enqueueSingle(url+"/spritemap.png");
		}
	}
    
    public function enqueueSingle(url : String, name : String = null/*, options : TextureOptions = null*/) : String
    {

		var asset = getExtensionFromUrl(url) == "json" ? Json.parse(Assets.getText(url)) : Assets.getBitmapData(url);

        var assetReference : AssetReference = new AssetReference(asset);
        if (name != null) assetReference.name = name;
		else assetReference.name =  getNameFromUrl(url);
        assetReference.extension = getExtensionFromUrl(url);
       // assetReference.textureOptions = options || _textureOptions;
        
        _queue.push(assetReference);
        trace("Enqueuing '" + assetReference.filename + "'");
        return assetReference.name;
    }
    
    public function loadQueue(onComplete : Dynamic, onError : Dynamic = null, onProgress : Dynamic = null) : Void
    {
		var asset:AssetReference;
		for (i in 0..._queue.length) {
			asset = _queue[i];		
			var assetFactory : AssetFactory = getFactoryFor(asset);		
			if (assetFactory == null)
			{
				trace("Warning: no suitable factory found for '" + asset.name + "'");
			}
			else
			{
				assetFactory.create(asset, this/*, helper, onComplete, onCreateError*/);			
			}
			
		}
		
		_queue = [];
		
		onComplete(this);
  
    }
    
    private function getFactoryFor(asset : AssetReference) : AssetFactory
    {		
		var lFactory:AssetFactory = asset.extension == "json" ? new AnimationAtlasFactory() : new BitmapTextureFactory(); 
		return lFactory;
    }
    
    public function addAsset(name : String, asset : Dynamic, type : String = null) : Void
    {
        if (type == null && Std.is(asset, AnimationAtlas))
        {
            type = AnimationAtlas.ASSET_TYPE;
        }
		
		type = (type != null) ? type : AssetType.fromAsset(asset);
        
        var store : Map<String,Dynamic> = _assets[type];
        if (store == null)
        {
            store = new Map<String,Dynamic>();
            _assets[type]= store;
        }
        
        trace("Adding " + type + " '" + name + "'");
        
        var prevAsset : Map<String,Dynamic> = store[name];
        if (prevAsset != null && prevAsset != asset)
        {
            log("Warning: name was already in use; disposing the previous " + type);
            //TODO: disposeAsset(prevAsset);
        }
        
        store[name]= asset;
    }
	
    public function getAnimationAtlas(name : String) : AnimationAtlas
    {
        return cast getAsset(AnimationAtlas.ASSET_TYPE, name);
    }
	
    public function getAnimationAtlasNames(prefix : String = "", out : Array<String> = null) : Array<String>
    {	
		return getAssetNames(AnimationAtlas.ASSET_TYPE, prefix, true, out);
    }
	
	public function createAnimation(name : String) : Animation
    {
        	
		var atlasNames : Array<String> = getAnimationAtlasNames("", sNames);
        var animation : Animation = null;
        for (atlasName in atlasNames)
        {
            var atlas : AnimationAtlas = getAnimationAtlas(atlasName);
            if (atlas.hasAnimation(name))
            {
				animation = atlas.createAnimation(name);
                break;
            }
        }

        sNames=[];
        return animation;
    }
    
    public function getAsset(type : String, name : String, recursive : Bool = true) : Dynamic
    {

		if (recursive)
        {

            var managerStore : Map<String,Dynamic> = _assets[AssetType.ASSET_MANAGER];
            if (managerStore != null)
            {
				for (manager in managerStore)
                {
                    var asset : Dynamic = manager.getAsset(type, name, true);
                    if (asset != null)
                    {
                        return asset;
                    }
                }
            }

			
            if (type == AssetType.TEXTURE)
            {

				var atlasStore : Map<String,Dynamic> = _assets[AssetType.TEXTURE_ATLAS];
                if (atlasStore != null)
                {
                    for (atlas in atlasStore)
                    {
                        var texture : BitmapData = atlas.getTexture(name);
                        if (texture != null)
                        {
                            return texture;
                        }
                    }
                }
            }
        }
		var store : Map<String,Dynamic> = _assets[type];
        if (store != null)
        {
            return store[name];
        }
        else
        {
            return null;
        }
    }
    
    public function getAssetNames(assetType : String, prefix : String = "", recursive : Bool = true,
            out : Array<String> = null) : Array<String>
    {
        out = (out != null) ? out : new Array<String>();
        
        if (recursive)
        {
            var managerStore : Map<String,Dynamic> = _assets[AssetType.ASSET_MANAGER];
            if (managerStore != null)
            {
                for (manager in managerStore)
                {
                    manager.getAssetNames(assetType, prefix, true, out);
                }
            }
            
            if (assetType == AssetType.TEXTURE)
            {
                var atlasStore : Map<String,Dynamic> = _assets[AssetType.TEXTURE_ATLAS];
                if (atlasStore != null)
                {
                    for (atlas in atlasStore)
                    {
                        atlas.getNames(prefix, out);
                    }
                }
            }
        }
		
	
        getDictionaryKeys(_assets[assetType], prefix, out);
		out.sort(ArrayUtil.CASEINSENSITIVE);
		
        return out;
    }
    
    public function getTexture(name : String) : BitmapData
    {
        return cast getAsset(AssetType.TEXTURE, name);
    }
    
    public function getTextures(prefix : String = "", out : Array<BitmapData> = null) : Array<BitmapData>
    {
        if (out == null)
        {
            out = [];
        }
        
        for (name in getTextureNames(prefix, sNames))
        {
            out[out.length] = getTexture(name);
        }  // avoid 'push'  
        
		sNames = [];
        return out;
    }
    
    public function getTextureNames(prefix : String = "", out : Array<String> = null) : Array<String>
    {
        return getAssetNames(AssetType.TEXTURE, prefix, true, out);
    }

    public function getTextureAtlas(name : String) : TextureAtlas
    {
        return cast getAsset(AssetType.TEXTURE_ATLAS, name);
    }
    
    public function getTextureAtlasNames(prefix : String = "", out : Array<String> = null) : Array<String>
    {
        return getAssetNames(AssetType.TEXTURE_ATLAS, prefix, true, out);
    }
    
    public function getObject(name : String) : Dynamic
    {
        return getAsset(AssetType.OBJECT, name);
    }
    
    public function getObjectNames(prefix : String = "", out : Array<String> = null) : Array<String>
    {
        return getAssetNames(AssetType.OBJECT, prefix, true, out);
    }
    
    public function getByteArray(name : String) : ByteArray
    {
        return cast getAsset(AssetType.BYTE_ARRAY, name);
    }
    
    public function getByteArrayNames(prefix : String = "", out : Array<String> = null) : Array<String>
    {
        return getAssetNames(AssetType.BYTE_ARRAY, prefix, true, out);
    }
    
    public function getAssetManager(name : String) : AssetManager
    {
        return cast getAsset(AssetType.ASSET_MANAGER, name);
    }
    
    public function getAssetManagerNames(prefix : String = "", out : Array<String> = null) : Array<String>
    {
        return getAssetNames(AssetType.ASSET_MANAGER, prefix, true, out);
    }
    
    public function registerFactory(factory : AssetFactory, priority : Int = 0) : Void
    {
        factory.priority = priority;
        
        _assetFactories.push(factory);
        _assetFactories.sort(comparePriorities);
    }
    
    private static function comparePriorities(a : Dynamic, b : Dynamic) : Int
    {
        if (a.priority == b.priority)
        {
            return 0;
        }
        return (a.priority > b.priority) ? -1 : 1;
    }
    
    private function getNameFromUrl(url : String) : String
    {
        var separator : String = "/";
		var elements : Array<Dynamic> = url.split(separator);
		var folderName : String = elements[elements.length - 2];
		var fileName : String = elements[elements.length - 1];
		var suffix : String = (fileName == "Animation.json") ? AnimationAtlasFactory.ANIMATION_SUFFIX : AnimationAtlasFactory.SPRITEMAP_SUFFIX;
		return folderName+suffix;
    }


    private function getExtensionFromUrl(url : String) : String
    {
        if (url != null)
        {
			return url.split("?")[0].split(".").pop();
        }
		
        return "";
    }
    
    private function log(message : String) : Void
    {
        if (_verbose)
        {
            trace("[AssetManager]", message);
        }
    }
    
    private static function getDictionaryKeys(dictionary : Map<String,Dynamic>, prefix : String = "", out : Array<String> = null) : Array<String>
    {
        if (dictionary != null)
        {
            for (name in dictionary.keys())
            {
                if (name.indexOf(prefix) == 0)
                {
                    out[out.length] = name;
                }
            }  // avoid 'push'  
            
            out.sort(ArrayUtil.CASEINSENSITIVE);
        }
        return out;
    }
    
    private static function getUniqueName() : String
    {
        return NO_NAME + "-" + sNoNameCount++;
    }
    
    private function get_verbose() : Bool
    {
        return _verbose;
    }
    private function set_verbose(value : Bool) : Bool
    {
        _verbose = value;
        return value;
    }
    
    private function get_numQueuedAssets() : Int
    {
        return _queue.length;
    }
    
    private function get_numConnections() : Int
    {
        return _numConnections;
    }
    private function set_numConnections(value : Int) : Int
    {
        _numConnections = Std.int(Math.min(1, value));
        return value;
    }
    
    private function get_registerBitmapFontsWithFontFace() : Bool
    {
        return _registerBitmapFontsWithFontFace;
    }
    
    private function set_registerBitmapFontsWithFontFace(value : Bool) : Bool
    {
        _registerBitmapFontsWithFontFace = value;
        return value;
    }
}

class AssetPostProcessor
{
    public var priority(get, never) : Int;

    private var _priority : Int;
    private var _callback : Dynamic;
    
    public function new(callback : Dynamic, priority : Int)
    {
		//TODO:
		//if (callback == null || as3hx.Compat.getFunctionLength(callback) != 1)
        //{
            //throw new ArgumentError("callback must be a function " +
            //"accepting one 'AssetStore' parameter");
        //}
        
        _callback = callback;
        _priority = priority;
    }
    
    @:allow(animateAtlasPlayer.assets.AssetManager)
    private function execute(store : AssetManager) : Void
    {
        _callback(store);
    }
    
    private function get_priority() : Int
    {
        return _priority;
    }
}