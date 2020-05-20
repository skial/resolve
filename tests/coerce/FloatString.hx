package coerce;

import be.types.Resolve;
import be.types.Resolve.coerce;

@:asserts
class FloatString {

    public function new() {}

    @:variant(100, '100')
    @:variant(10, '10')
    @:variant(11.1, '11.1')
    public function test(input:Float, expected:String) {
        var string:String = coerce(input);
        asserts.assert( string == expected );

        return asserts.done();
    }

}