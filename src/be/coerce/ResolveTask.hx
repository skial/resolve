package be.coerce;

import haxe.macro.Expr;
import haxe.macro.Type;

enum ResolveTask {
    /**
        var m:String->Float = resolve(Type);
        var m:`signature` = resolve(`module`);
        var m:Resolve<String->Float, ~/int/i> = resolve(Type);
        var m:Resolve<`signature`, `ereg`> = resolve(`module`);
        ---
        If it can resolve to a function, it will look for a matching type `signature`
        on `module`
    **/
    SearchMethod(signature:Type, module:Type, statics:Bool, expr:Expr, ?ereg:EReg);

    /**
        var m:Date = coerce('2018-11-15');
        var m:`output` = coerce((`value`:`input`));
        ---
        Look through a known list of types for matching `input`=>`output`.
        If a type doesnt exist, search `output` for a `input->output` method.
    **/
    ConvertValue(input:Type, output:Type, value:Expr);

    /**
        var i:Int = 100;
        var m:Resolve<Int->Int, ~/^(add(ition|able)?|plus)/i> = resolve(i);
        ---
        var i:`input` = `expr`;
        var m:Resolve<`signature`, `ereg`> = resolve(i);
        ---
        var i:Int = 100;
        var i:`oldInput` = 100;
        var m:Resolve<Int->Int, ~/^(add(ition|able)?|plus)/i> = resolve(be.types.int.Add.add.bind(i));
        var m:Resolve<`signature`, `ereg`> = resolve((be.types.int.Add.add.bind(`expr`):`newInput`));
        ---
        CoreApi type promotion takes, in this case, an `Int` const, wraps it in
        a specialist abstract, matching the required type.
        
        With `-dce full` this should be inlined when possible.
    **/
    //TypePromotion(expr:Expr, oldInput:Type, newInput:Type, signature:Type, ?ereg:EReg);
}