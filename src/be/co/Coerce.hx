package be.co;

#if (eval || macro)
import haxe.macro.Context;
using tink.MacroApi;
#end

@:callable @:notNull abstract Coerce<From, To>(From->To) from From->To {

    @:noCompletion public static var stringint:Coerce<String, Int> = Std.parseInt;
    @:noCompletion public static var stringfloat:Coerce<String, Float> = Std.parseFloat;
    

    public static macro function value<From, To>(input:ExprOf<From>):ExprOf<To> {
        trace( input );
        var _input = input.typeof().sure();
        var _return = Context.getExpectedType();
        trace( _input, _return );
        var _property = (_input.getID() + _return.getID()).toLowerCase();
        return 'be.co.Coerce.$_property'.resolve(input.pos).call([input]);
    }

}

/**
General Structure Layout
---
Builtin @:from conversions for basic types.
---
Self = {
    public function from${InputTypeName}:${Self};
    public function as${OutputTypeName}(v:${InputType}):${OutputType};
    ...
}

**/

typedef InputString = {
    public function fromString(v:String):InputString;
    public function asInt():Int;
    public function asFloat():Int;
    public function asDate():Date;
}