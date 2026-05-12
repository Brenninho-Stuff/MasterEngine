package polymod.hscript._internal;

import haxe.ds.ObjectMap;

@:forward
@:access(polymod.hscript._internal.PolymodScriptClass)
abstract PolymodAbstractScriptClass(PolymodScriptClass) from PolymodScriptClass
{
	static final fieldsCache:ObjectMap<Dynamic, Array<String>> = new ObjectMap();

	// ---------------------------------------------------------------
	//  Field resolution
	// ---------------------------------------------------------------

	private function resolveField(name:String):Dynamic
	{
		switch (name)
		{
			case "superClass":       return this.superClass;
			case "createSuperClass": return this.createSuperClass;
			case "findFunction":     return this.findFunction;
			case "callFunction":     return this.callFunction;

			case _:
				var fromFunction = tryResolveFunction(name);
				if (fromFunction != null)
					return fromFunction;

				var fromVar = tryResolveVar(name);
				if (fromVar != null)
					return fromVar;

				return resolveFromSuperClass(name);
		}
	}

	private function tryResolveFunction(name:String):Null<Dynamic>
	{
		var fn = this.findFunction(name);
		if (fn == null)
			return null;

		var nargs:Int = (fn.args != null) ? fn.args.length : 0;

		return switch (nargs)
		{
			case 0: this.callFunction0.bind(name);
			case 1: this.callFunction1.bind(name, _);
			case 2: this.callFunction2.bind(name, _, _);
			case 3: this.callFunction3.bind(name, _, _, _);
			case 4: this.callFunction4.bind(name, _, _, _, _);
			#if !neko
			case 5: this.callFunction5.bind(name, _, _, _, _, _);
			case 6: this.callFunction6.bind(name, _, _, _, _, _, _);
			case 7: this.callFunction7.bind(name, _, _, _, _, _, _, _);
			case 8: this.callFunction8.bind(name, _, _, _, _, _, _, _, _);
			case _:
				@:privateAccess this._interp.error(ECustom('only 8 params allowed in script class functions (.bind limitation)'));
				null;
			#else
			case _:
				@:privateAccess this._interp.error(ECustom('only 4 params allowed in script class functions (.bind limitation)'));
				null;
			#end
		}
	}

	private function tryResolveVar(name:String):Null<Dynamic>
	{
		var v = this.findVar(name);
		if (v == null)
			return null;

		@:privateAccess
		switch (v.get)
		{
			case "get":
				final getName = 'get_$name';
				if (!this._interp._propTrack.exists(getName))
				{
					this._interp._propTrack.set(getName, true);
					var result = this.callFunction(getName);
					this._interp._propTrack.remove(getName);
					return result;
				}

			case "null":
				return @:privateAccess this._interp.errorEx(EInvalidPropGet(name));
		}

		return readVarValue(name, v);
	}

	private function readVarValue(name:String, v:Dynamic):Dynamic
	{
		@:privateAccess
		{
			if (!this._interp.variables.exists(name))
			{
				if (v.expr != null)
				{
					var value:Dynamic = this._interp.expr(v.expr);
					this._interp.variables.set(name, value);
					return value;
				}
				return null;
			}

			return this._interp.variables.get(name);
		}
	}

	private function resolveFromSuperClass(name:String):Dynamic
	{
		if (this.superClass == null)
			throw 'Field "$name" does not exist in script class "${this.fullyQualifiedName}"';

		if (Type.getClass(this.superClass) == null)
			return resolveFromAnonymousSuper(name);

		if (Std.isOfType(this.superClass, PolymodScriptClass))
			return resolveFromScriptSuperClass(name);

		return resolveFromNativeClass(name);
	}

	private function resolveFromAnonymousSuper(name:String):Dynamic
	{
		if (Reflect.hasField(this.superClass, name))
			return Reflect.field(this.superClass, name);

		throw 'Field "$name" does not exist in script class "${this.fullyQualifiedName}" or anonymous super';
	}

	private function resolveFromScriptSuperClass(name:String):Dynamic
	{
		var superScriptClass:PolymodAbstractScriptClass = cast(this.superClass, PolymodScriptClass);
		try
		{
			return superScriptClass.fieldRead(name);
		}
		catch (e:Dynamic)
		{
			throw 'Field "$name" does not exist in script class "${this.fullyQualifiedName}" or script super class';
		}
	}

	private function resolveFromNativeClass(name:String):Dynamic
	{
		try
		{
			return getClassObjectField(this.superClass, name);
		}
		catch (e:String)
		{
			@:privateAccess this._interp.error(EInvalidAccess(name));
		}

		return null;
	}

	// ---------------------------------------------------------------
	//  Field operators
	// ---------------------------------------------------------------

	@:op(a.b) public function fieldRead(name:String):Dynamic
	{
		return resolveField(name);
	}

	@:op(a.b) public function fieldWrite(name:String, value:Dynamic):Dynamic
	{
		var v = this.findVar(name);

		if (v != null)
			return writeLocalVar(name, value, v);

		if (this.superClass != null && Std.isOfType(this.superClass, PolymodScriptClass))
			return writeScriptSuperClassField(name, value);

		if (this.superClass != null)
			return writeNativeSuperClassField(name, value);

		@:privateAccess
		{
			#if hl
			return
			#end
			this._interp.error(EInvalidAccess(name));
		}
	}

	private function writeLocalVar(name:String, value:Dynamic, v:Dynamic):Dynamic
	{
		if (v.isfinal && v.expr != null)
			throw 'Cannot assign to final field "$name"';

		@:privateAccess
		switch (v.set)
		{
			case "set":
				final setName = 'set_$name';
				if (!this._interp._propTrack.exists(setName))
				{
					this._interp._propTrack.set(setName, true);
					var result = this.callFunction(setName, [value]);
					this._interp._propTrack.remove(setName);
					return result;
				}

			case "never" | "null":
				return @:privateAccess this._interp.errorEx(EInvalidPropSet(name));
		}

		@:privateAccess this._interp.variables.set(name, value);
		return value;
	}

	private function writeScriptSuperClassField(name:String, value:Dynamic):Dynamic
	{
		var superScriptClass:PolymodAbstractScriptClass = cast(this.superClass, PolymodScriptClass);
		try
		{
			return superScriptClass.fieldWrite(name, value);
		}
		catch (e:Dynamic)
		{
			throw 'Field "$name" does not exist in script class "${this.fullyQualifiedName}" or script super class';
		}
	}

	private function writeNativeSuperClassField(name:String, value:Dynamic):Dynamic
	{
		if (setClassObjectField(this.superClass, name, value))
			return value;

		@:privateAccess this._interp.error(EInvalidAccess(name));
		return null;
	}

	// ---------------------------------------------------------------
	//  Class field cache helpers
	// ---------------------------------------------------------------

	private static function retrieveClassObjectFields(o:Dynamic):Array<String>
	{
		final cls = Type.getClass(o);
		if (cls == null)
			throw "Provided object is not a class instance";

		var fields = fieldsCache.get(cls);
		if (fields == null)
		{
			fields = Type.getInstanceFields(cls);
			fieldsCache.set(cls, fields);
		}

		return fields;
	}

	private static function getClassObjectField(o:Dynamic, field:String):Null<Dynamic>
	{
		var fields = retrieveClassObjectFields(o);
		if (fields.contains(field) || fields.contains('get_$field'))
			return Reflect.getProperty(o, field);

		throw 'No such field "$field" on ${Type.getClassName(Type.getClass(o))}';
	}

	private static function setClassObjectField(o:Dynamic, field:String, value:Dynamic):Bool
	{
		var fields = retrieveClassObjectFields(o);
		if (fields.contains(field) || fields.contains('set_$field'))
		{
			Reflect.setProperty(o, field, value);
			return true;
		}
		return false;
	}

	// ---------------------------------------------------------------
	//  Cache management
	// ---------------------------------------------------------------

	/** Clears the fields cache. Call this if classes are hot-reloaded at runtime. */
	public static function clearFieldsCache():Void
	{
		fieldsCache.clear();
	}

	/** Returns whether a field exists (readable) on this script class or its super chain. */
	public function hasField(name:String):Bool
	{
		try
		{
			resolveField(name);
			return true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}
}
