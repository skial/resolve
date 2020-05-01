package ;

import be.types.Resolve;
import be.types.Resolve.coerce;

@:asserts
class CoerceSpec {

    public function new() {}

    public function testString_Class() {
        var input = '2018-11-15';
        var aInt:Int = coerce( input );
        var aFloat:Float = coerce( input );
        var aDate:Date = coerce( input );
        var aFake:CoFake = coerce( input );

        asserts.assert( aInt == 2018 );
        asserts.assert( aFloat == 2018 );
        asserts.assert( aDate.toString() == "2018-11-15 00:00:00" );
        asserts.assert( '' + aFake == '' + new CoFake(input) );

        return asserts.done();
    }

    public function testString_Abstract() {
        var input = 'a';
        var charA:CoChar = coerce(input);
        var charB:CoChar = coerce('B');

        asserts.assert( (charA:Int) == 'a'.code );
        asserts.assert( charB == 'B'.code );

        var chars:CoChars = coerce('hello');

        asserts.assert( '' + chars == '' + ['h'.code, 'e'.code, 'l'.code, 'l'.code, 'o'.code] );

        chars = coerce('hello'.split(''));

        asserts.assert( '' + chars == '' + ['h'.code, 'e'.code, 'l'.code, 'l'.code, 'o'.code] );

        var foo:CoFoo = coerce([1, 2, 3, 4, 5]);
        asserts.assert( foo == 15 );

        return asserts.done();
    }

}

class CoFake {
    var name:String;
    public function new(v:String) {
        name = v;
    }
    public static function parseFloat(v:String):Float return 0.0;
    public static function falseSig(v:String):Int return throw 'This is skipped due to the `~/int/i` regular expression';
    public static function parseInt(v:String):Int return 1000;
    public static function mkFake(v:String):CoFake return new CoFake(v);

    public function mutate(newName:String):CoFake {
        name += newName;
        return this;
    }
}

abstract CoChar(Int) to Int {

    public inline function new(v) this = v;

    @:from public #if !debug inline #end static function fromString(v:String) {
        return new CoChar(v.charCodeAt(0));
    }

}


abstract CoChars(Array<CoChar>) from Array<CoChar> {

    public inline function new(v) this = v;

    @:from public #if !debug inline #end static function fromString(v:String):CoChars {
        return new CoChars([for (i in 0...v.length) (v.charAt(i):CoChar)]);
    }

    @:from public #if !debug inline #end static function fromStringArray(v:Array<String>) {
        return new CoChars(v.map( s -> (s:CoChar) ));
    }

}

abstract CoFoo(Int) to Int {
    public inline function new(v) this = v;

    @:from public #if !debug inline #end static function fromIntArray(v:Array<Int>) {
        var t = 0;
        for (i in v) t += i;
        return new CoFoo(t);
    }

}