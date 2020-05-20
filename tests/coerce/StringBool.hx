package coerce;

import be.types.Resolve;
import be.types.Resolve.coerce;

@:asserts
class StringBool {

    public function new() {}

    @:variant('true', true)
    @:variant('TRUE', true)
    @:variant('false', false)
    @:variant('FALSE', false)
    @:variant('TrUe', true)
    @:variant('fAlSe', false)
    @:variant('  true', false)
    public function test(input:String, expected:Bool) {
        var bool:Bool = coerce(input);
        asserts.assert( bool == expected );

        return asserts.done();
    }

}