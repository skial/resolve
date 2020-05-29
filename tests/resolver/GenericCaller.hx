package resolver;

import be.types.Resolve;

@:asserts
class GenericCaller {

    public function new() {}

    public function test() {
        asserts.assert( typeParam(GenericCaller, 'hello').value == 'hello' );
        asserts.assert( typeParam(this, 123).value == 123 );

        return asserts.done();
    }

    private function mkDecoy1(v:String):GenericCallerHelper<String> throw v;

    private function mkGenericCallerFromInstance(v:Int):GenericCallerHelper<Int> {
        return new GenericCallerHelper(v);
    }

    private function mkDecoy2(v:Float):GenericCallerHelper<Float> throw v;

    private static function mkGenericCallerFromStatic(v:String):GenericCallerHelper<String> {
        return new GenericCallerHelper(v);
    }

    private static function mkDecoy3(v:String):GenericCallerHelper<String> throw v;

    @:generic 
    public static function typeParam<In, Out>(r:Resolve<In->Out, ~/mk([^Decoy])/i, ~//i>, v:In):Out {
        return r(v);
    }

}

class GenericCallerHelper<T> {

    public var value:T;

    public function new(v:T) {
        this.value = v;
    }

}