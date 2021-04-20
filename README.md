# resolve

An `abstract` type to help filter and select fields based on type signatures, naming schemes and metadata usage using regular expressions.

### Why tho?

Resolve is more useful for when dealing with user provided types during macro generation. _If using resolve in other macros, it is recommended to use the `be.resolve.macros.Resolver` methods directly._

### Type Support

Classes and Abstracts are supported, currently. There are two ways of searching, either static or instance fields, with _some exceptions_ for Abstracts.

##### Searching Statics

-   ```haxe
    var r:Resolve<Int->Int> = SomeClass;
    ```

##### Searching Instances

-   ```haxe
    var i:SomeClass = new SomeClass();
    var r:Resolve<Int->Int> = i;
    ```

##### Filtering against names

- ```haxe
  var r:Resolve<Int->Int, ~/add(ition|able)?/> = /*Search against instance or static expression*/.
  ```

##### Filtering against metadata

> Notice the open and close brackets `()` are escaped.
- ```haxe
  var r:Resolve<Int->Int, ~/@:op\([\w\d\s]+\+[\w\d\s]+\)/> = /*Search against instance or static expression*/.
  ```

##### Filtering against names & metadata

- `Resolve<$type, $name, $meta>`
    + `$type` is always position `0`.
    + If both `EReg`'s are supplied:
      - Names is always position `1`.
      - Metas is always position `2`.
    + If either `EReg` is omitted, `Resolve` will:
      - Check for `@` character, if it exists, it assumes its a meta regular expression.
      - Otherwise it defaults to a name regular expression.
- ```haxe
  var r:Resolve<Int->Int, ~/add(ition|able)?/, ~/@:op\([\w\d\s]+\+[\w\d\s]+\)/> = /*Search against instance or static expression*/.
  ```

##### Abstract Support

> Abstracts are compile time only types, with many features which can result in complex usage. Pairing them with macros make this more difficult. 🔥🐲 

To access Abstract features like `@:to`, `@:from`, `@:op(_)` etc, the metadata filter needs to match the respective metadata for that feature.

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
        var r:Resolve<String->Int, ~/int/i> = resolve(Std);
        // `r` is already resolved, so gets passed as `Std.parseInt`.
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

#### `Resolve`

`Resolve` is a `@:genericBuild` macro which redirects to either a `ResolveMethod` or `ResolveProperty` or `ResolveFunctions` type.
- `Resolve` only requires the type signature.
- How does `Resolve` decide if a regular expression passed in is a metadata filter or not?
    + It checks for the existence of the `@` character, which isn't a valid ident character in Haxelang.

```haxe
import be.types.Resolve;
import be.types.Resolve.resolve;

class Main {
    public static function main() {
        var input = '999';
        trace( asInt(Std, input) );             // trace(999);
        trace( asInt(resolve(Fake), input) );   // trace(1000);
        // Functions that unify pass right through.
        trace( asInt(_ -> 1, '125') );  // trace(1);
    }

    // `Resolve<String-Int>` returns the `ResolveMethod<String->Int, ~//, ~//>` type.
    static function asInt(r:Resolve<String->Int>, v:String):Int return r(v);
}

public class Fake {
    static function parseFloat(v:String):Float return 0.0;
    static function parseInt(v:String):Int return 1000;
}
```

### ⚠ `be.resolve.macros.Resolver`

> Take a look at the source of `be.types.ResolveFunctions` on how to get started.

```haxe
class Resolver {
    public static function determineTask(expr:Expr, input:Type, output:Type, ?debug:Bool):ResolveTask;
    public static function findMethod(signature:Type, module:Type, statics:Bool, pos:Position, ?fieldEReg:EReg, ?metaEReg:EReg, ?debug:Bool):Outcome<Array<{name:String, type:Type}>, Error>;
    public static function convertValue(input:Type, output:Type, value:Expr, ?debug:Bool):Outcome<Expr, Error>;
    public static function handleTask(task:ResolveTask, ?debug:Bool):Expr;
}
```

### Defines

- `-D resolve-verbose` - Paired with `-debug` will have the build macros print **a lot** of trace statements.