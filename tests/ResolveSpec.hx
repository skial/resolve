package ;

import be.types.Pick;
import be.types.Resolve;
import be.types.Resolve.resolve;

// TODO might need to add a follow somewhere 
//typedef Addable = Resolve<Int->Int->Int, ~/(add(able|ition)|plus)/i, ~/@:op\(([a-z ]+\+[a-z ]+)\i)/>;

@:asserts
class ResolveSpec {

    public function new() {}

    public function testResolve_staticFields() {
        var a:Resolve<String->Int, ~/int(2)?/i, ~//i> = resolve(ReEntry);

        asserts.assert( ReEntry.callStringInt(_ -> 1, '125') == 1 );
        asserts.assert( ReEntry.callStringInt(a, '124') == 20000 );

        var input = '999';
        asserts.assert( ReEntry.asInt(resolve(Std), input) == 999 );
        asserts.assert( ReEntry.asInt(resolve(Fake), input) == 1000 );
        asserts.assert( ReEntry.mkFake(resolve(Fake), input).name == input );

        return asserts.done();
    }

    public function testResolve_instanceFields() {
        var input = '999';
        var fakeString = 'hello fake world.';
        var fakey = new Fake(fakeString);
        var expected = '$fakeString$input';

        asserts.assert( ReEntry.mkFake(resolve(fakey), input).name == expected );

        return asserts.done();
    }

    public function testResolve_typeParams() {
        asserts.assert( ReEntry.typeParam(resolve(Fake), 'fakeyyyy').name == 'fakeyyyy' );
        asserts.assert( ReEntry.typeParam(resolve(Bake), 'bakeyyyy').name == 'bakeyyyy' );
        asserts.assert( ReEntry.typeParam(resolve(Cake), 100).amount == 100 ); // cakeyyyy

        return asserts.done();
    }

    public function testResolve_metadata() {
        var m:Resolve<Int->Int->Int, ~/(add(able|ition)|plus)/i, ~/@:op\(([a-z ]+\+[a-z ]+)\)/i> = resolve(BarAddable);

        asserts.assert( m(2, 2) == 11 );

        return asserts.done();
    }

}

class ReEntry {

    public static inline function mkFake(r:Pick<String->Fake>, v:String):Fake return r(v);

    public static function fake(v:String):Int return throw 'bugger';
    public static function fakeParseInt1(v:String):Int return 10000;
    public static function fakeParseInt2(v:String):Int return 20000;

    public static inline function callStringInt(func:Resolve<String->Int, ~/int(2)?/i, ~//>, v:String):Int return func(v);

    public static inline function asInt(r:Resolve<String->Int, ~/int/i, ~//>, v:String):Int return r(v);

    @:generic public static function typeParam<In, Out>(r:Resolve<In->Out, ~/mk/i, ~//i>, v:In):Out {
        return r(v);
    }

}

class Fake {
    public var name:String;
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
    public var name:String;
    public function new(v:String) {
        name = v;
    }

    public static function mk(v:String):Bake return new Bake(v);
}

class Cake {
    public var amount:Int;
    public function new(v:Int) {
        amount = v;
    }

    public static function mk(v:Int):Cake return new Cake(v);
}

class BarAddable {

    public function new() {}

    public static function bluff(a:Int, b:Int):Int {
        throw 'WRONG 1';
        return a + b;
    }

    @:op(A + OTHER) public static function obf123456789(a:Int, b:Int):Int {
        return a*a + 1 + b*b + 2;
    }

    public static function bluffy(a:Int, b:Int):Int {
        throw 'WRONG 2';
        return a + b;
    }

}