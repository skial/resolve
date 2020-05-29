package resolver;

import be.types.Resolve;
import be.types.Resolve.resolve;

typedef Addable = Resolve<Int->Int->Int, ~/(add(able|ition)|plus)/i, ~/@:op\(([a-z ]+\+[a-z ]+)\)/i>;

@:asserts
class Redefined {

    public function new() {}

    public function test_viaResolveMethod() {
        var m:Addable = resolve(AddableThing1);

        asserts.assert( m(2, 2) == 11 );
        return asserts.done();
    }

    public function test_viaCatchAll() {
        var m:Addable = AddableThing1;

        asserts.assert( m(2, 2) == 11 );
        return asserts.done();
    }

}

class AddableThing1 {

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