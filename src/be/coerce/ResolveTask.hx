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
        on `module`, sorted favoring matches against `ereg` & `meta`, if available.
    **/
    SearchMethod(signature:Type, module:Type, statics:Bool, expr:Expr, ?ereg:EReg, ?meta:EReg);

    /**
        var m:Date = coerce('2018-11-15');
        var m:`output` = coerce((`value`:`input`));
        ---
        Look through a known list of types for matching `input`=>`output`.
        If a type doesnt exist, search `output` for a `input->output` method.
    **/
    ConvertValue(input:Type, output:Type, value:Expr);

    /**
        The hint is in the name and type description.
        ---
        Currently only `SearchMethod` is supported.
    **/
    Multiple(tasks:Array<ResolveTask>);
}