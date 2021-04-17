package resolver;

import be.types.ResolveProperty;
import be.types.ResolveProperty.resolve;

@:asserts
class AbsStaticPropertySpec {

    public function new() {}

    public function testAbsInstance_propertyTyped() {
        var r:ResolveProperty<Float, ~//, ~//> = AbsStaticPropHelper;

        asserts.assert( r == 3.1 );

        return asserts.done();
    }

    public function testAbsInstance_propertyNamed() {
        var r:ResolveProperty<Float, ~/foo[1-9]/i, ~//> = resolve(AbsStaticPropHelper);

        asserts.assert( r == 3.1 );

        return asserts.done();
    }

    public function testAbsInstance_propertyMeta() {
        var r:ResolveProperty<String, ~//, ~/@:noCompletion/> = AbsStaticPropHelper;

        asserts.assert( r == 'hey hey hey' );

        return asserts.done();
    }

}

abstract AbsStaticPropHelper(String) {

    public static var fooA(get, never):String;

    private static inline function get_fooA() {
        return 'hey';
    }

    public static var foo1(get, never):Float;

    private static inline function get_foo1() {
        return 3 + 0.1;
    }

    @:noCompletion public static var fooB(get, never):String;

    private static inline function get_fooB() {
        return 'hey hey hey';
    }

    public static var foo2(get, never):Float;

    private static inline function get_foo2() {
        return 3 + 0.1;
    }

}