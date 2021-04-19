package coerce;

import be.types.Resolve.coerce;

@:asserts
class StringFloat {

    public function new() {}

    @:variant('100', 100)
    @:variant('010', 10)
    @:variant('11.1', 11.1)
    public function test(input:String, expected:Float) {
        var float:Float = coerce(input);
        asserts.assert( float == expected );

        return asserts.done();
    }

}