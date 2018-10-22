package be.co;

import be.types.Resolve;
#if (eval || macro)
import haxe.macro.Type;
import haxe.macro.Context;

using haxe.macro.TypeTools;
using tink.MacroApi;
#end

@:callable @:notNull abstract Coerce<From, To>(From->To) from From->To {

    #if (eval || macro)
    public static var stringMap = [
        'Int' => macro Std.parseInt,
        'Float' => macro Std.parseFloat,
        'Date' => macro std.Date.fromString,
        'String' => macro Std.string,
    ];
    public static var typeMap = [
        'String' => stringMap,
        'Int' => new Map(),
        'Float' => new Map(),
        'Bool' => new Map(),
        'Array' => new Map()
    ];
    #end

    public static macro function value<From, To>(input:ExprOf<From>):ExprOf<To> {
        var _input = input.typeof().sure();
        var _return = Context.getExpectedType();
        
        var _inputComplex = _input.toComplex();
        var _returnComplex = _return.toComplex();
        
        var result = null;
        if (typeMap.exists( _input.getID() )) {
            var subMap = typeMap.get( _input.getID() );
            if (subMap.exists( _return.getID() )) {
                result = subMap.get( _return.getID() );

            } else {
                // Attempt to find a method that has a matching signature.
                var custom = macro:be.types.Resolve<$_inputComplex->$_returnComplex, ~//i>;
                var tpath = _return.getID().resolve();
                var out = be.types.Resolve.coerceMacro(
                    tpath, 
                    TAnonymous({
                        get:() -> { 
                            fields: [],
                            status: AClassStatics(
                                {get:()->_return.getClass(), toString: ()->''}
                            )
                        },
                        toString:()->'',
                    }),
                    custom.toType().sure()
                );
                result = out;
            }

        }

        if (result == null) {
            Context.fatalError('Unable to coerce ${input.toString()} from type ${_input.getID()} to type ${_return.getID()}.', input.pos);
        }
        
        return macro @:pos(input.pos) $result($input);
    }

}