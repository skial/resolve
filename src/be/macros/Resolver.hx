package be.macros;

import haxe.macro.*;
import haxe.macro.Type;
import haxe.macro.Type.ClassField;
import haxe.macro.Expr.ComplexType;
import be.coerce.Errors;
import be.coerce.Metadata;
import be.coerce.ResolveTask;

using haxe.macro.Context;
using tink.CoreApi;
using tink.MacroApi;

class Resolver {

    public static var stringMap = [
        'Int' => macro Std.parseInt,
        'Float' => macro Std.parseFloat,
        'Date' => macro std.Date.fromString,
        'String' => macro (v -> v),
        'Bool' => macro (v -> v.toLowerCase() == 'true'),
    ];
    public static var intMap = [
        'String' => macro Std.string,
    ];
    public static var floatMap = [
        'String' => macro Std.string,
    ];
    public static var boolMap = [
        'String' => macro Std.string,
    ];
    public static var typeMap = [
        'String' => stringMap,
        'Int' => intMap,
        'Float' => floatMap,
        'Bool' => boolMap,
        //'Array' => new Map()
    ];

    public static function determineTask(expr:Expr, input:Type, output:Type):ResolveTask {
        var result = null;
        
        #if (debug && coerce_verbose)
        trace( expr.toString() );
        trace( input );
        trace( output );
        #end

        switch input.reduce() {
            case TAnonymous(_.get() => {status:AClassStatics(ref)}):
                var ereg = null;
                var outputComplex = output.toComplex();
                var method = (macro be.types.Resolve.Method.fromResolve((null:$outputComplex))).typeof().sure();
                // TODO this is just to force, I'm guessing, tink DirectTypes to real types.
                var _signature = (macro (null:$outputComplex).get()).typeof();
                #if (debug && coerce_verbose)
                trace( ref );
                trace( outputComplex );
                trace( _signature );
                trace( outputComplex.toString() );
                #end
                ereg = getEReg(outputComplex);

                if (output.unify(method)) {
                    var methodComplex = method.toComplex();
                    var signature = (macro ((null:$outputComplex):$methodComplex).toResolve().get()).typeof().sure();
                    
                    result = SearchMethod(signature, TInst(ref, []), true, ref.toString().resolve(), ereg);
                }
                
            case TInst(_.get() => t, params) if (t.constructor != null && !t.meta.has(CoreApi)):
                var outputComplex = output.toComplex();
                var method = (macro be.types.Resolve.Method.fromResolve((null:$outputComplex))).typeof().sure();
                
                var ereg = getEReg(outputComplex);

                if (output.unify(method)) {
                    var methodComplex = method.toComplex();
                    var signature = (macro ((null:$outputComplex):$methodComplex).toResolve().get()).typeof().sure();

                    result = SearchMethod(signature, input.reduce(), false, expr, ereg);
                }

            case x:
                #if (debug && coerce_verbose)
                trace( x );
                #end
                result = ConvertValue(input, output, expr);

        }

        #if (debug && coerce_verbose)
        trace( result );
        #end

        return result;
    }

    public static function findMethod(signature:Type, module:Type, statics:Bool, ?ereg:EReg):Promise<Array<{name:String, type:Type}>> {
        var result = [];
        var isArray = false;
        var unified = false;
        var pos = Context.currentPos();
        
        #if (debug && coerce_verbose)
        trace( signature.toComplex().toString() );
        trace( module.toComplex().toString() );
        trace( statics );
        #end

        switch signature {
            case TFun(args, ret):
                var moduleID = module.getID();
                #if (debug && coerce_verbose)
                trace( moduleID );
                trace( args );
                trace( ret );
                #end
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
                        #if (debug && coerce_verbose)
                        trace(x);
                        #end
                        [];

                }

                #if (debug && coerce_verbose)
                trace( fields.map( f->f.name ) );
                #end
                
                var matches = [];

                if (fields.length > 0) for (field in fields) {
                    var eregMatch = true;
                    if (ereg != null) eregMatch = ereg.match(field.name);
                    if (eregMatch && field.type.unify(signature)) matches.push( field );

                }

                #if (debug && coerce_verbose)
                trace( matches.map( f->f.name ) );
                #end

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

        #if (debug && coerce_verbose)
        trace( input );
        trace( output );
        trace( value.toString() );
        trace( inputID );
        trace( outputID );
        #end
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
            #if (debug && coerce_verbose)
            trace( matchesArray, unified, matchesArray && unified );
            #end
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
            #if (debug && coerce_verbose)
            trace( signature );
            #end
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