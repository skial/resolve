package resolver;

import be.types.ResolveProperty;
import be.types.ResolveProperty.resolve;

@:asserts
class ClassPropertySpec {

    public function new() {}

    public function testPropertySignature() {
        var a:ClassPropertyHelper = new ClassPropertyHelper();
        var r:ResolveProperty<String, ~//, ~//> = resolve(a);

        asserts.assert( r == 'Hello World!' );

        return asserts.done();
    }

    public function testPropertyNameEReg() {
        var a:ClassPropertyHelper = new ClassPropertyHelper();
        var r:ResolveProperty<Dynamic, ~/foo[0-9]/i, ~//> = resolve(a);

        asserts.assert( r == 'Hello World!' );

        return asserts.done();
    }

    public function testPropertyMetaEReg() {
        var a:ClassPropertyHelper = new ClassPropertyHelper();
        var r:ResolveProperty<Dynamic, ~//, ~/@:isVar/> = resolve(a);

        asserts.assert( r == 'Hello World!' );

        return asserts.done();
    }

}

class ClassPropertyHelper {

    public function new() {}

    public var fooA:String = 'Wrong choice!';
    @:isVar public var fooB:Float = -1.1;
    @:isVar public var foo0:String = 'Hello World!';

    public function foo1():String {
        throw 'Wrong choice from foo1.';
        return 'Wrong choice from foo1.';
    }

    public static function foo2():String {
        throw 'Wrong choice from foo2.';
        return 'Wrong choice from foo2.';
    }

}