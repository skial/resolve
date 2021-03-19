# coerce

An `abstract` type to help filter and select functions based on method signatures and regular expressions for naming schemes and metadata.

### Why tho?

Coerce is more useful for when dealing with user provided types during macro generation. _If using coerce in macros, its recommended to use the `be.macros.Resolver` methods directly._

### Type Support

Classes and Abstracts are supported, currently. There are two ways of searching, either static or instance fields, with _some exceptions_ for Abstracts.

##### Searching Statics

-   ```haxe
    var r:Resolve<Int->Int, ~//, ~//> = SomeClass;
    ```

##### Searching Instances

-   ```haxe
    var i:SomeClass = new SomeClass();
    var r:Resolve<Int->Int, ~//, ~//> = i;
    ```

##### Filtering against names

- ```haxe
  var r:Resolve<Int->Int, ~/add(ition|able)?/, ~//> = /*Search against instance or static expression*/.
  ```

##### Filtering against metadata

> A fields metadata object is stringified using `haxe.macro.Printer` so it can be checked with the provided `EReg`.
- ```haxe
  var r:Resolve<Int->Int, ~//, ~/@:op([\w\d\s]+\+[\w\d\s]+)/> = /*Search against instance or static expression*/.
  ```

##### Abstract Support

> Abstracts are compile time only types, with many features which can result in complex usage. Pairing them with macros make this more difficult. 🐲 

To access Abstract features like `@:to`, `@:from`, `@:op(_)` etc, the meta filter needs to match the respective metadata for that feature. 

Some of these features are `static` implementations. An Abstract *instance* passed to a `Resolve` type with a matching meta `EReg` will be changed to the *static* representation and in doing so, dropping the instance reference.

### Types API

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

> Using `resolve(<expr>)` can help prevent auto-completion issues.

```haxe
import be.types.Resolve;
import be.types.Resolve.resolve;

class Main {
    public static function main() {
        var input = '999';
        var r:Resolve<String->Int, ~/int/i, ~//i> = resolve(Std);
        // `r` is already resolved, so gets passed `Std.parseInt`.
        trace( asInt(r, input) );       // trace(999);
        // Resolves to `Std.parseInt`.
        trace( asInt(Std, input) );     // trace(999);
        // Resolves to `Fake.parseInt`.
        trace( asInt(Fake, input) );    // trace(1000);
        // Functions that unify pass right through.
        trace( asInt(_ -> 1, '125') );  // trace(1);
    }

    static inline function asInt(r:Resolve<String->Int, ~/int/i, ~//i, v:String):Int return r(v);
}

public class Fake {
    static function parseInt(v:String):Int return 1000;
    static function parseFloat(v:String):Float return 0.0;
    static function falseSig(v:String):Int return throw 'This is skipped due to the `~/int/i` regular expression';
}
```

#### `Pick`

`Pick` is a `@:genericBuild` macro which creates a `Resolve` type, making it a more friendly type to work with. 
- `Pick` only requires the type signature.
- How does `Pick` decide if a regular expression passed in is a metadata filter or not?
    + It checks for the existence of the `@` character, which isn't a valid ident character in Haxelang.

```haxe
import be.types.Pick;
import be.types.Resolve.resolve;

class Main {
    public static function main() {
        var input = '999';
        trace( asInt(Std, input) );             // trace(999);
        trace( asInt(resolve(Fake), input) );   // trace(1000);
        // Functions that unify pass right through.
        trace( asInt(_ -> 1, '125') );  // trace(1);
    }

    // `Pick<String-Int>` returns the `Resolve<String->Int, ~//, ~//>` type.
    static function asInt(r:Pick<String->Int>, v:String):Int return r(v);
}

public class Fake {
    static function parseFloat(v:String):Float return 0.0;
    static function parseInt(v:String):Int return 1000;
}
```

### `be.macros.Resolver`

Take a look at the source for `be.coerce.Resolve` for getting started.

```haxe
class Resolver {
    public static function determineTask(expr:Expr, input:Type, output:Type, ?debug:Bool):ResolveTask;
    public static function findMethod(signature:Type, module:Type, statics:Bool, pos:Position, ?fieldEReg:EReg, ?metaEReg:EReg, ?debug:Bool):Outcome<Array<{name:String, type:Type}>, Error>;
    public static function convertValue(input:Type, output:Type, value:Expr, ?debug:Bool):Outcome<Expr, Error>;
    public static function handleTask(task:ResolveTask, ?debug:Bool):Expr;
}
```

### Defines

- `-D coerce-verbose` - Paired with `-debug` will have the build macros print **a lot** of trace statements.