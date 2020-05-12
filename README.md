# coerce

An `abstract` type to help filter and select functions based on method signatures and regular expressions for naming schemes and metadata.

### Types

#### `Resolve`

```haxe
abstract Resolve<T:Function, @:const R:EReg, @:const M:EReg> {
    static function coerce<In, Out>(expr:ExprOf<In>):ExprOf<Out>;
    static function resolve<Int, Out:Function>(expr:ExprOf<Class<Int>>):ExprOf<Out>;
}
```

##### `Resolve.coerce`

```haxe
import be.types.Resolve.coerce;

class Main {
    public static function main() {
        var input = '2018-11-15';
        var aInt:Int = coerce( input );
        var aFloat:Float = coerce( input );
        var aDate:Date = coerce( input );
        var aFake:Fake = coerce( input );

        trace( 
            aInt    /*2018*/, 
            aFloat  /*2018*/, 
            aDate   /*Novemeber 15th 2018*/, 
            aFake   /* {name:"2018-11-15"} */
        );
    }

}

class Fake {
    var name:String;
    public function new(v:String) name = v;
    public static function mkFake(v:String):Fake return new Fake(v);
}
```

##### `Resolve.resolve`

```haxe
import be.types.Resolve.resolve;

class Main {
    public static function main() {
        var input = '999';
        trace( asInt(Std, input) );     // trace(999);
        trace( asInt(Fake, input) );    // trace(1000);
        trace( asInt(_ -> 1, '125') );  // trace(1);
    }

    public static inline function asInt(r:Resolve<String->Int, ~/int/i, ~//>, v:String):Int return r(v);
}

class Fake {
    public static function parseInt(v:String):Int return 1000;
    public static function parseFloat(v:String):Float return 0.0;
    public static function falseSig(v:String):Int return throw 'This is skipped due to the `~/int/i` regular expression';
}
```

#### `Pick`

`Pick` is a `@:genericBuild` macro which creates a `Resolve` making it a more friendly type to work with. 
`Pick` only requires the type signature.

```haxe
import be.types.Pick;
import be.types.Resolve.resolve;

class Main {
    public static function main() {
        var input = '999';
        trace( asInt(Std, input) );     // trace(999);
        trace( asInt(Fake, input) );    // trace(1000);
    }

    public static function asInt(r:Pick<String->Int>, v:String):Int return r(v);
}

class Fake {
    public static function parseFloat(v:String):Float return 0.0;
    public static function parseInt(v:String):Int return 1000;
}
```

### Defines

- `-D coerce-verbose` - Paired with `-debug`, this will have the build macros print a bunch of trace statements.