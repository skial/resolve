package resolver;

import be.types.ResolveProperty;
import be.types.ResolveProperty.resolve;

@:asserts
class ClassStaticPropertySpec {

    public function new() {}

    public function testPropertySignature() {
        var r:ResolveProperty<String, ~//, ~//> = ClassStaticPropertyHelper;

        asserts.assert( r == 'Hello World!' );

        return asserts.done();
    }

    public function testPropertyNameEReg() {
        var r:ResolveProperty<Dynamic, ~/foo[0-9]/i, ~//> = resolve(ClassStaticPropertyHelper);

        asserts.assert( r == 'Hello World!' );

        return asserts.done();
    }

    public function testPropertyMetaEReg() {
        var r:ResolveProperty<Dynamic, ~//, ~/@:isVar/> = resolve(ClassStaticPropertyHelper);

        asserts.assert( r == 'Hello World!' );

        return asserts.done();
    }

}

class ClassStaticPropertyHelper {

    public static var fooA:String = 'Wrong choice!';
    @:isVar public static var fooB:Float = -1.1;
    @:isVar public static var foo0:String = 'Hello World!';

    public static function foo1():String {
        throw 'Wrong choice from foo1.';
        return 'Wrong choice from foo1.';
    }

    public static function foo2():String {
        throw 'Wrong choice from foo2.';
        return 'Wrong choice from foo2.';
    }

}