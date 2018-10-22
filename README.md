# coerce

Helpful Types to select functions based on method signatures.
~~Type conversion from one type to another.~~

### Types

#### `Resolve`

```haxe
abstract Resolve<T:Function, @:const R:EReg> {
    @:from public static function coerce<In>(expr:haxe.macro.Expr.ExprOf<Class<Int>>):haxe.macro.Expr;
}
```

```haxe
import be.types.Resolve.coerce;

class Main {
    public static function main() {
        var input = '999';
        trace( asInt(coerce(Std), input) );     // trace(999);
        trace( asInt(coerce(Fake), input) );    // trace(1000);
    }

    public static inline function asInt(r:Resolve<String->Int, ~/int/i>, v:String):Int return r(v);
}

class Fake {
    public static function parseFloat(v:String):Float return 0.0;
    public static function falseSig(v:String):Int return throw 'This is skipped due to the `~/int/i` regular expression';
    public static function parseInt(v:String):Int return 1000;
}
```

#### `Pick`

`Pick` is a `@:genericBuild` macro which wraps `Resolve` making it a more UX friendly type to work with. 
`Pick` only requires the type signature.

```haxe
import be.types.Pick;
import be.types.Resolve.coerce;

class Main {
    public static function main() {
        var input = '999';
        trace( asInt(coerce(Std), input) );     // trace(999);
        trace( asInt(coerce(Fake), input) );    // trace(1000);
    }

    public static function asInt(r:Pick<String->Int>, v:String):Int return r(v);
}

class Fake {
    public static function parseFloat(v:String):Float return 0.0;
    public static function parseInt(v:String):Int return 1000;
}
```

### Notes

- It's recommended to `import be.type.Resolve.coerce` and wrapping classes in `coerce` to avoid false autocompletion errors.

### Defines

- `-D coerce-verbose` - Paired with `-debug`, this will have the build macros print a bunch of trace statements.