package resolver;

import be.types.Resolve;

@:asserts
class MetaSpec {

    public function new() {}

    public function test() {
        /**
            Why do these two not compile or resolve?
            With `Resolve` being the first arg, T is unknown.
            Moving it to the last arg, allows the compiler to infer `T`'s
            type, allowing `Resolve` to ... resolve.
        */
        //asserts.assert( call(MetaSpec, 'hello ', 'world') == 'hello world' );
        //asserts.assert( call(MetaSpec, 1, 2) == 3 );
        asserts.assert( call('hello ', 'world', MetaSpec) == 'hello world' );
        asserts.assert( call(1, 2, MetaSpec) == 3 );
        return asserts.done();
    }

    private static function call<T>(a:T, b:T, m:Resolve<T->T->T, ~/(add(able|ition)|plus)/i, ~/@:op\(([a-z ]+\+[a-z ]+)\)/i>):T {
        return m(a, b);
    }

    @:op(A + B) public static function addString(a:String, b:String):String {
        return a + b;
    }

    @:op(A+BBBBBBBB) public static function addInt(a:Int, b:Int):Int {
        return a + b;
    }

}