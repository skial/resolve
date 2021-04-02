package resolver;

import be.types.Resolve;

@:asserts
class AbsInstanceMatchStatic {

    public function new() {}

    public function test() {
        var a = new AbstractInstanceStaticHelper(10);
        var r:Resolve<Int->AbstractInstanceStaticHelper, ~//, ~/@:op\([a-z ]+\+[a-z ]+\)/i> = a;

        asserts.assert( r(10).value == 20 );

        return asserts.done();
    }

}


abstract AbstractInstanceStaticHelper(Int) {

    public var value(get, never):Int;
    private function get_value() return this;

    public inline function new(v) this = v;

    @:op(a+b) public static function plus(a:AbstractInstanceStaticHelper, b:String):AbstractInstanceStaticHelper {
        throw "plus: Should not have been selected";
        return new AbstractInstanceStaticHelper(a.value + b.length);
    }

    @:op(A + B) public static function add(a:AbstractInstanceStaticHelper, b:Int):AbstractInstanceStaticHelper {
        return new AbstractInstanceStaticHelper(a.value + b);
    }

    @:op(a + B) public static function addition(a:AbstractInstanceStaticHelper, b:Float):AbstractInstanceStaticHelper {
        throw "addition: Should not have been selected";
        return new AbstractInstanceStaticHelper(a.value + Std.int(b));
    }

}