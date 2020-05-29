package resolver;

import be.types.Resolve;
import be.types.Resolve.resolve;

@:asserts
class ClassSpec {

    public function new() {}

    public function test() {
        var r:Resolve<String->Int, ~/int(2)?/i, ~//> = resolve(ClassSpec);

        // Test that normal methods passed in work.
        asserts.assert( callStringInt(_ -> 1, '126') == 1 );
        // Test previously resolved method.
        asserts.assert( callStringInt(r, '125') == 20000 );
        // Test direct `resolve(_)`.
        asserts.assert( callStringInt(resolve(ClassSpec), '124') == 20000 );
        // Test `catchAll` to resolve correctly.
        asserts.assert( callStringInt(ClassSpec, '123') == 20000 );
        // Test Std is resolved to `parseInt`.
        asserts.assert( callStringInt(Std, '122') == 122 );

        return asserts.done();
    }

    public static function fake(v:String):Int return throw 'bugger';
    public static function fakeParseInt1(v:String):Int return 10000;
    public static function fakeParseInt2(v:String):Int return 20000;

    public static inline function callStringInt(func:Resolve<String->Int, ~/int(2)?/i, ~//i>, v:String):Int {
        return func(v);
    }

}