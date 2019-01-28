package ;

import be.types.Pick;
import be.types.Resolve;
import be.types.Resolve.coerce;
import be.types.Resolve.resolve;

class Entry {

    public static function main() {
        var m:Pick<String->Int> = resolve(Std);
        var a:Resolve<String->Int, ~/int(2)?/i> = resolve(Entry);
        
        trace( foo(m, '123') );
        trace( foo(a, '124') );
        trace( foo(_ -> 1, '125') );

        var input = '999';
        trace( asInt(resolve(Std), input) );     // trace(999);
        trace( asInt(resolve(Fake), input) );    // trace(1000);

        //

        var input = '2018-11-15';
        var aInt:Int = coerce( input );
        var aFloat:Float = coerce( input );
        var aDate:Date = coerce( input );
        var aFake:Fake = coerce( input );

        trace( aInt /*2018*/, aFloat /*2018*/, aDate /*Novemeber 15th 2018*/, aFake );
        
        // Select instances

        var fakey = new Fake('hello fake world.');
        trace( fakey /* {name:"hello fake world"} */ );
        trace( mkFake(resolve(Fake), input) ); // Static access on Fake via `mkFake`
        trace( mkFake(resolve(fakey), input) ); // Instance access on Fake via `mutate`

        trace( typeParam(resolve(Fake), 'fakeyyyy') );
        trace( typeParam(resolve(Bake), 'bakeyyyy') );
        trace( typeParam(resolve(Cake), 100) ); // cakeyyyy

        var input = 'a';
        var charA:Char = coerce(input);
        var charB:Char = coerce('B');
        
        trace( charA, charB, (cast charA:Int) == 'a'.code, (cast charB:Int) == 'B'.code );

        var chars:Chars = [charA, charB];
        trace( chars );
        chars = coerce('hello');
        trace( chars, '' + chars == '' + ['h'.code, 'e'.code, 'l'.code, 'l'.code, 'o'.code] );
        chars = coerce('hello'.split(''));
        trace( chars, '' + chars == '' + ['h'.code, 'e'.code, 'l'.code, 'l'.code, 'o'.code] );

        var foo:Foo = coerce([1, 2, 3, 4, 5]);
        trace( foo, (cast foo:Int) == 15 );
    }

    public static inline function mkFake(r:Pick<String->Fake>, v:String):Fake return r(v);

    public static function fake(v:String):Int return throw 'bugger';
    public static function fakeParseInt1(v:String):Int return 10000;
    public static function fakeParseInt2(v:String):Int return 20000;

    public static inline function foo(func:Pick<String->Int, ~/int(2)?/i>, v:String):Int return func(v);

    public static inline function asInt(r:Resolve<String->Int, ~/int/i>, v:String):Int return r(v);

    #if static @:generic #end public static inline function typeParam<I, O>(r:Resolve<I->O, ~/mk/i>, v:I):O {
        return r(v);
    }

}

class Fake {
    var name:String;
    public function new(v:String) {
        name = v;
    }
    public static function parseFloat(v:String):Float return 0.0;
    public static function falseSig(v:String):Int return throw 'This is skipped due to the `~/int/i` regular expression';
    public static function parseInt(v:String):Int return 1000;
    public static function mkFake(v:String):Fake return new Fake(v);

    public function mutate(newName:String):Fake {
        name += newName;
        return this;
    }
}

class Bake {
    var name:String;
    public function new(v:String) {
        name = v;
    }

    public static function mk(v:String):Bake return new Bake(v);
}

class Cake {
    var amount:Int;
    public function new(v:Int) {
        amount = v;
    }

    public static function mk(v:Int):Cake return new Cake(v);
}

abstract Char(Int) {

    public inline function new(v) this = v;

    @:from public #if !debug inline #end static function fromString(v:String) {
        return new Char(v.charCodeAt(0));
    }

}

abstract Chars(Array<Char>) from Array<Char> {

    public inline function new(v) this = v;

    @:from public #if !debug inline #end static function fromString(v:String):Chars {
        return new Chars([for (i in 0...v.length) (v.charAt(i):Char)]);
    }

    @:from public #if !debug inline #end static function fromStringArray(v:Array<String>) {
        return new Chars(v.map( s -> (s:Char) ));
    }

}

abstract Foo(Int) {
    public inline function new(v) this = v;

    @:from public #if !debug inline #end static function fromIntArray(v:Array<Int>) {
        var t = 0;
        for (i in v) t += i;
        return new Foo(t);
    }

}