package resolver;

import be.types.ResolveProperty;
import be.types.ResolveProperty.resolve;

@:asserts
class AbsInstancePropertySpec {

    public function new() {}

    public function testAbsInstance_propertyTyped() {
        var a:AbsInstPropHelper = new AbsInstPropHelper();
        var r:ResolveProperty<Float, ~//, ~//> = a;

        asserts.assert( r == 3.1 );

        return asserts.done();
    }

    public function testAbsInstance_propertyNamed() {
        var a:AbsInstPropHelper = new AbsInstPropHelper();
        var r:ResolveProperty<Float, ~/foo[1-9]/i, ~//> = resolve(a);

        asserts.assert( r == 3.1 );

        return asserts.done();
    }

    public function testAbsInstance_propertyMeta() {
        var a:AbsInstPropHelper = new AbsInstPropHelper();
        var r:ResolveProperty<String, ~//, ~/@:noCompletion/> = a;

        asserts.assert( r == 'hey hey hey' );

        return asserts.done();
    }

}

abstract AbsInstPropHelper(String) {

    public var fooA(get, never):String;

    private inline function get_fooA() {
        return this;
    }

    public var foo1(get, never):Float;

    private inline function get_foo1() {
        return this.length + 0.1;
    }

    @:noCompletion public var fooB(get, never):String;

    private inline function get_fooB() {
        return '$this $this $this';
    }

    public var foo2(get, never):Float;

    private inline function get_foo2() {
        return this.length + 0.1;
    }

    public inline function new() {
        this = 'hey';
    }

}