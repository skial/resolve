package coerce;

import be.types.Resolve.coerce;

@:asserts
class IntString {

    public function new() {}

    @:variant(100, '100')
    @:variant(10, '10')
    @:variant(11, '11')
    public function test(input:Int, expected:String) {
        var string:String = coerce(input);
        asserts.assert( string == expected );

        return asserts.done();
    }

}