package ;

import be.types.Pick;
import be.types.Resolve;
import be.types.Resolve.coerce;

class Entry {

    public static function main() {
        var m:Pick<String->Int> = coerce(Std);
        var a:Resolve<String->Int, ~/int(2)?/i> = coerce(Entry);
        
        trace( foo(m, '123') );
        trace( foo(a, '124') );
        trace( foo(_ -> 1, '125') );

        var input = '999';
        trace( asInt(coerce(Std), input) );     // trace(999);
        trace( asInt(coerce(Fake), input) );    // trace(1000);
    }

    public static function fake(v:String):Int return throw 'bugger';
    public static function fakeParseInt1(v:String):Int return 10000;
    public static function fakeParseInt2(v:String):Int return 20000;

    public static inline function foo(func:Pick<String->Int, ~/int(2)?/i>, v:String):Int return func(v);

    public static inline function asInt(r:Resolve<String->Int, ~/int/i>, v:String):Int return r(v);

}

class Fake {
    public static function parseFloat(v:String):Float return 0.0;
    public static function falseSig(v:String):Int return throw 'This is skipped due to the `~/int/i` regular expression';
    public static function parseInt(v:String):Int return 1000;
}