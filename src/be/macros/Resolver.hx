package be.macros;

import haxe.macro.*;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Metas;
import haxe.macro.Defines;
import be.coerce.Errors;
import be.coerce.ResolveTask;

using StringTools;
using haxe.macro.Context;
using tink.CoreApi;
using tink.MacroApi;

enum abstract LocalDefines(Defines) {
    public var CoerceVerbose = 'coerce_verbose';
    
    @:to public inline function asBool():Bool {
		return haxe.macro.Context.defined(this);
	}

    @:op(A == B) private static function equals(a:LocalDefines, b:Bool):Bool;
    @:op(A && B) private static function and(a:LocalDefines, b:Bool):Bool;
    @:op(A != B) private static function not(a:LocalDefines, b:Bool):Bool;
    @:op(!A) private static function negate(a:LocalDefines):Bool;
}

class Resolver {

    @:persistent public static var stringMap = [
        'Int' => macro Std.parseInt,
        'Float' => macro Std.parseFloat,
        'Date' => macro std.Date.fromString,
        'String' => macro (v -> v),
        'Bool' => macro (v -> v.toLowerCase() == 'true'),
    ];

    @:persistent public static var intMap = [
        'String' => macro Std.string,
    ];

    @:persistent public static var floatMap = [
        'String' => macro Std.string,
    ];

    @:persistent public static var boolMap = [
        'String' => macro Std.string,
    ];
    
    @:persistent public static var typeMap = [
        'String' => stringMap,
        'Int' => intMap,
        'Float' => floatMap,
        'Bool' => boolMap,
        //'Array' => new Map()
    ];

    public static function determineTask(expr:Expr, input:Type, output:Type):ResolveTask {
        var result = null;

        // Yes this is a lazy hack but its for future me.
        if ('$output'.indexOf('TAbstract(be.types.Pick') > -1) {
            var c = output.toComplex();
            output = Context.typeof(macro (null:$c).asResolve());
        }
        
        if (Debug && CoerceVerbose) {
            trace( 'expression      :   ' + expr.toString() );
            trace( 'input type      :   ' + input );
            trace( 'input reduced   :   ' + input.reduce() );
            trace( 'output type     :   ' + output );
        }

        switch input.reduce() {
            case TAnonymous(_.get() => {status:AClassStatics(clsr = _.get() => ({kind:KAbstractImpl(absr)}) )}):
                var outputComplex = output.follow().toComplex();
                var method = (macro be.types.Resolve.Method.fromResolve((null:$outputComplex))).typeof().sure();
                var _signature = (macro (null:$outputComplex).get()).typeof();
                var fieldEReg:EReg = getFieldEReg(outputComplex);
                var metaEReg:EReg = getMetaEReg(outputComplex);

                if (Debug && CoerceVerbose) {
                    trace( 'static class    :   ' + clsr );
                    trace( 'abstract type   :   ' + absr );
                    trace( 'sig type        :   ' + _signature );
                    trace( 'method type     :   ' + method );
                    trace( 'output ctype    :   ' + outputComplex.toString() );
                    trace( 'field ereg      :   ' + fieldEReg );
                    trace( 'meta ereg       :   ' + metaEReg );
                }

                if (output.unify(method)) {
                    var methodComplex = method.toComplex();
                    var signature = (macro ((null:$outputComplex):$methodComplex).toResolve().get()).typeof().sure();
                    
                    if (Debug && CoerceVerbose) {
                        trace( 'method ctype    :   ' + methodComplex.toString() );
                        trace( 'sig ctype       :   ' + signature );
                    }

                    result = SearchMethod(signature, TAbstract(absr, []), true, absr.toString().resolve(), fieldEReg, metaEReg);
                }

            case TAnonymous(_.get() => {status:AClassStatics(ref)}):
                var outputComplex = output.follow().toComplex();
                var method = (macro be.types.Resolve.Method.fromResolve((null:$outputComplex))).typeof().sure();
                // TODO this is just to force, I'm guessing, tink_macro DirectTypes to real types.
                var _signature = (macro (null:$outputComplex).get()).typeof();
                var fieldEReg:EReg = getFieldEReg(outputComplex);
                var metaEReg:EReg = getMetaEReg(outputComplex);

                if (Debug && CoerceVerbose) {
                    trace( 'static class    :   ' + ref );
                    trace( 'sig type        :   ' + _signature );
                    trace( 'method type     :   ' + method );
                    trace( 'output ctype    :   ' + outputComplex.toString() );
                    trace( 'field ereg      :   ' + fieldEReg );
                    trace( 'meta ereg       :   ' + metaEReg );
                }

                if (output.unify(method)) {
                    var methodComplex = method.toComplex();
                    var signature = (macro ((null:$outputComplex):$methodComplex).toResolve().get()).typeof().sure();
                    
                    if (Debug && CoerceVerbose) {
                        trace( 'method ctype    :   ' + methodComplex.toString() );
                        trace( 'sig ctype       :   ' + signature );
                    }

                    result = SearchMethod(signature, TInst(ref, []), true, ref.toString().resolve(), fieldEReg, metaEReg);
                }
                
            case TInst(_.get() => t, params) if (t.constructor != null && !t.meta.has(Metas.CoreApi)):
                var outputComplex = output.toComplex();
                var method = (macro be.types.Resolve.Method.fromResolve((null:$outputComplex))).typeof().sure();
                
                var fieldEReg = getFieldEReg(outputComplex);
                var metaEReg = getMetaEReg(outputComplex);

                if (output.unify(method)) {
                    var methodComplex = method.toComplex();
                    var signature = (macro ((null:$outputComplex):$methodComplex).toResolve().get()).typeof().sure();

                    if (Debug && CoerceVerbose) {
                        trace( outputComplex.toString() );
                        trace( signature );
                    }

                    result = SearchMethod(signature, input.reduce(), false, expr, fieldEReg, metaEReg);
                }

            case x:
                if (Debug && CoerceVerbose) {
                    trace( x );
                }

                result = ConvertValue(input, output, expr);

        }

        if (Debug && CoerceVerbose) {
            trace( result );
        }

        return result;
    }

    public static function findMethod(signature:Type, module:Type, statics:Bool, pos:Position, ?fieldEReg:EReg, ?metaEReg:EReg):Promise<Array<{name:String, type:Type}>> {
        var results = [];
        var blankField = fieldEReg == null || '$fieldEReg'.startsWith('~//');
        var blankMeta = metaEReg == null || '$metaEReg'.startsWith('~//');
        
        if (Debug && CoerceVerbose) {
            trace( 'sig         :   ' + signature );
            trace( 'use statics :   ' + statics );
            trace( 'field ereg  :   ' + fieldEReg );
            trace( 'meta ereg   :   ' + metaEReg );
        }

        switch signature {
            case TFun(args, ret):
                var moduleID = module.getID();

                if (Debug && CoerceVerbose) {
                    trace( moduleID );
                    trace( 'args: ' + args );
                    trace( 'return type: ' + ret );
                }

                var fields:Array<{name:String, type:Type, meta:Metadata}> = switch module {
                    case TInst(_.get() => t, params):
                        var fs = statics ? t.statics.get() : t.fields.get();
                        fs.map( f -> {name:f.name, type:f.type, meta:f.meta.get()} );

                    case TAbstract(_.get() => t, params):
                        [for (f in t.from) 
                            (f.field == null) 
                                ? {name:'', type:f.t, meta:[]} 
                                : {name:f.field.name, type:f.field.type, meta:f.field.meta.get()}
                        ]
                        .concat([
                        for(f in t.binops)
                            {name:f.field.name, type:f.field.type, meta:f.field.meta.get()}
                        ]);

                    case x:
                        if (Debug && CoerceVerbose) {
                            trace(x);
                        }

                        [];

                }

                if (Debug && CoerceVerbose) {
                    trace( 'checking    :   ' + fields.map( f->f.name ) );
                }

                haxe.ds.ArraySort.sort( fields, (f1, f2) -> {
                    var fieldMatch = blankField;
                    var metaMatch = blankMeta;
                    
                    var f1total = 0;
                    var f2total = 0;

                    if (!fieldMatch) {
                        switch [fieldEReg.match(f1.name), fieldEReg.match(f2.name)] {
                            case [true, false]: f1total++;
                            case [false, true]: f2total++;
                            case _:
                        }

                    }

                    if (!metaMatch) {
                        for (meta in f1.meta) {
                            var str = meta.toString();
                            if (metaEReg.match( str )) f1total++;
                        }

                        for (meta in f2.meta) {
                            var str = meta.toString();
                            if (metaEReg.match( str )) f2total++;
                        }

                    }

                    if (Debug && CoerceVerbose) {
                        trace( f1.name, f2.name, f1total, f2total, f1total - f2total );
                    }

                    return f1total - f2total;
                } );

                if (Debug && CoerceVerbose) {
                    trace( 'sorted      :   ' + fields.map( f->f.name ) );
                }

                results = fields;

            case x:
                return new Error( NotFound, NotFunction + ' Not ${x.getID()}', pos );

        }

        return results;
    }

    public static function convertValue(input:Type, output:Type, value:Expr):Promise<Expr> {
        var result = null;
        var inputID = input.getID();
        var outputID = output.getID();
        var position = value.pos;

        if (Debug && CoerceVerbose) {
            trace( input );
            trace( output );
            trace( value.toString() );
            trace( inputID );
            trace( outputID );
        }
        
        if (typeMap.exists( inputID )) {
            var sub = typeMap.get( inputID );
            if (sub.exists( outputID )) {
                result = macro @:pos(value.pos) $e{sub.get( outputID )}($value);

            }

        }

        if (result == null) {
            var outputComplex = output.toComplex();
            var emptyArray = (macro new Array()).typeof().sure();
            var matchesArray = emptyArray.unify(output);
            var unified = input.unify(output);

            if (Debug && CoerceVerbose) {
                trace( matchesArray, unified, matchesArray && unified );
            }

            if (unified) {
                result = macro @:pos(value.pos) ($value:$outputComplex);

            } else if (matchesArray) {
                trace( matchesArray, outputComplex.toString() );

            }
        }
        
        if (result == null) {
            var inputComplex = input.toComplex();
            var outputComplex = output.toComplex();
            var signature = (macro:$inputComplex->$outputComplex).toType().sure();

            if (Debug && CoerceVerbose) {
                trace( signature );
            }

            var tmp:Expr = null;
            var error:Error = null;

            findMethod(signature, output, true, position).handle( function(o) switch o {
                case Success(matches):
                    if (matches.length > 0) {
                        tmp = outputID.resolve().field(matches[matches.length-1].name);

                    } else {
                        error = new Error( NotFound, NoMatches, value.pos );

                    }

                case Failure(err):
                    error = err;

            } );

            if (error != null) return new Error( error.code, error.message, error.pos );
            
            result = tmp == null ? value : macro @:pos(value.pos) $tmp($value);
        }

        if (result == null) return new Error( NotFound, TotalFailure, value.pos );
        
        return result;
    }

    public static function getFieldEReg(ctype:ComplexType):Null<EReg> {
        var result = null;

        switch ctype {
            case TPath( {params:p} ) if (p != null && p.length > 1):
                switch p[1] {
                    case TPExpr(_.expr => EConst(CRegexp(r, o))):
                        result = new EReg(r, o);

                    case _:
                }

            case _:

        }

        return result;
    }

    public static function getMetaEReg(ctype:ComplexType):Null<EReg> {
        var result = null;

        switch ctype {
            case TPath( {params:p} ) if (p != null && p.length > 1):
                switch p[2] {
                    case TPExpr(_.expr => EConst(CRegexp(r, o))):
                        result = new EReg(r, o);

                    case _:
                }

            case _:

        }

        return result;
    }

}