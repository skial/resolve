package be.macros;

import haxe.macro.*;
import haxe.macro.Type;
import haxe.macro.Type.ClassField;
import haxe.macro.Expr.ComplexType;
import haxe.macro.Metas;
import haxe.macro.Defines;
import be.coerce.Errors;
import be.coerce.ResolveTask;

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
        
        if (Debug && CoerceVerbose) {
            trace( expr.toString() );
            trace( input );
            trace( output );
            trace( input.reduce() );
        }

        switch input.reduce() {
            case TAnonymous(_.get() => {status:AClassStatics(ref)}):
                var ereg = null;
                var outputComplex = output.toComplex();
                var method = (macro be.types.Resolve.Method.fromResolve((null:$outputComplex))).typeof().sure();
                // TODO this is just to force, I'm guessing, tink DirectTypes to real types.
                var _signature = (macro (null:$outputComplex).get()).typeof();

                if (Debug && CoerceVerbose) {
                    trace( ref );
                    trace( outputComplex );
                    trace( _signature );
                    trace( outputComplex.toString() );
                }

                ereg = getEReg(outputComplex);

                if (output.unify(method)) {
                    var methodComplex = method.toComplex();
                    var signature = (macro ((null:$outputComplex):$methodComplex).toResolve().get()).typeof().sure();
                    
                    result = SearchMethod(signature, TInst(ref, []), true, ref.toString().resolve(), ereg);
                }
                
            case TInst(_.get() => t, params) if (t.constructor != null && !t.meta.has(Metas.CoreApi)):
                var outputComplex = output.toComplex();
                var method = (macro be.types.Resolve.Method.fromResolve((null:$outputComplex))).typeof().sure();
                
                var ereg = getEReg(outputComplex);

                if (output.unify(method)) {
                    var methodComplex = method.toComplex();
                    var signature = (macro ((null:$outputComplex):$methodComplex).toResolve().get()).typeof().sure();

                    result = SearchMethod(signature, input.reduce(), false, expr, ereg);
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

    public static function findMethod(signature:Type, module:Type, statics:Bool, ?ereg:EReg):Promise<Array<{name:String, type:Type}>> {
        var result = [];
        var isArray = false;
        var unified = false;
        var pos = Context.currentPos();
        
        if (Debug && CoerceVerbose) {
            trace( signature.toComplex().toString() );
            trace( module.toComplex().toString() );
            trace( statics );
        }

        switch signature {
            case TFun(args, ret):
                var moduleID = module.getID();

                if (Debug && CoerceVerbose) {
                    trace( moduleID );
                    trace( args );
                    trace( ret );
                }

                var fields:Array<{name:String, type:Type}> = switch module {
                    case TInst(_.get() => t, params):
                        statics ? t.statics.get() : t.fields.get();

                    case TAbstract(_.get() => t, params):
                        [for (f in t.from) 
                            (f.field == null) ? {name:'', type:f.t} : f.field
                        ]
                        .concat([
                        for(f in t.binops)
                            f.field
                        ]);

                    case x:
                        if (Debug && CoerceVerbose) {
                            trace(x);
                        }

                        [];

                }

                if (Debug && CoerceVerbose) {
                    trace( fields.map( f->f.name ) );
                }
                
                var matches = [];

                if (fields.length > 0) for (field in fields) {
                    var eregMatch = true;
                    if (ereg != null) eregMatch = ereg.match(field.name);
                    if (eregMatch && field.type.unify(signature)) matches.push( field );

                }

                if (Debug && CoerceVerbose) {
                    trace( matches.map( f->f.name ) );
                }

                result = matches;

            case x:
                return new Error( NotFound, NotFunction + ' Not ${x.getID()}', pos );

        }

        return result;
    }

    public static function convertValue(input:Type, output:Type, value:Expr):Promise<Expr> {
        var result = null;
        var inputID = input.getID();
        var outputID = output.getID();

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

            findMethod(signature, output, true).handle( function(o) switch o {
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

    public static function getEReg(ctype:ComplexType):Null<EReg> {
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

}