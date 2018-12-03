# coerce

Helpful Types to select functions based on method signatures.

### Types

#### `Resolve`

```haxe
abstract Resolve<T:Function, @:const R:EReg> {
    @:from static function coerce<In, Out>(expr:ExprOf<In>):ExprOf<Out>;
    @:from static function resolve<Int, Out:Function>(expr:ExprOf<Class<Int>>):ExprOf<Out>;
}
```

##### _Parsing one type to another_
```haxe
import be.types.Resolve.coerce;

class Main {
    public static function main() {
        var input = '2018-11-15';
        var aInt:Int = coerce( input );
        var aFloat:Float = coerce( input );
        var aDate:Date = coerce( input );
        var aFake:Fake = coerce( input );

        trace( aInt /*2018*/, aFloat /*2018*/, aDate /*Novemeber 15th 2018*/, aFake /* {name:"2018-11-15"} */ );
    }
}

class Fake {
    var name:String;
    public function new(v:String) {
        name = v;
    }
    public static function mkFake(v:String):Fake return new Fake(v);
}
```

##### _Filter static methods based on type signature._
```haxe
import be.types.Resolve.resolve;

class Main {
    public static function main() {
        var input = '999';
        trace( asInt(resolve(Std), input) );     // trace(999);
        trace( asInt(resolve(Fake), input) );    // trace(1000);
        trace( asInt(_ -> 1, '125') );          // trace(1);
    }

    public static inline function asInt(r:Resolve<String->Int, ~/int/i>, v:String):Int return r(v);
}

class Fake {
    public static function parseInt(v:String):Int return 1000;
    public static function parseFloat(v:String):Float return 0.0;
    public static function falseSig(v:String):Int return throw 'This is skipped due to the `~/int/i` regular expression';
}
```

#### `Pick`

`Pick` is a `@:genericBuild` macro which wraps `Resolve` making it a more UX friendly type to work with. 
`Pick` only requires the type signature.

```haxe
import be.types.Pick;
import be.types.Resolve.resolve;

class Main {
    public static function main() {
        var input = '999';
        trace( asInt(resolve(Std), input) );     // trace(999);
        trace( asInt(resolve(Fake), input) );    // trace(1000);
    }

    public static function asInt(r:Pick<String->Int>, v:String):Int return r(v);
}

class Fake {
    public static function parseFloat(v:String):Float return 0.0;
    public static function parseInt(v:String):Int return 1000;
}
```

### Notes

- It's recommended to `import be.type.Resolve.resolve` and to wrap classes in `resolve` to avoid false autocompletion errors.

### Defines

- `-D coerce-verbose` - Paired with `-debug`, this will have the build macros print a bunch of trace statements.