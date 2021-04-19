package be.resolve.macros;

import haxe.macro.Type;
import haxe.macro.Defines;
import be.resolve.macros.Resolver.LocalDefines;
import haxe.macro.Expr.TypePath;
import haxe.macro.Expr.ComplexType;
import haxe.macro.*;

using tink.MacroApi;
using haxe.macro.TypeTools;

@:nullSafety(Strict)
class ResolveBuilder {

    public static function search() {
        var type = Context.getLocalType();
        var pos = Context.currentPos();
        var debug = Defines.Debug && ResolveVerbose;

        var signatureType:Null<Type> = null;
        var signatureComplex:Null<ComplexType> = null;
        var fieldERegParts:Array<String> = [];
        var fieldERegExpr:Expr = macro ~//i;
        var metaERegParts:Array<String> = [];
        var metaERegExpr:Expr = macro ~//i;
        var ctype:Null<ComplexType> = null;

        switch type {
            case TInst(_.get() => {pack:['be', 'types'], name:'Resolve'}, params) if (params.length != 0):
                switch params {
                    // [Type->Type]
                    case [t = TFun(_, _)]:
                        ctype = macro:be.types.ResolveMethod;
                        signatureType = t;
                    
                    // [Type]
                    case [t] if (!t.match(TFun(_, _))):
                        ctype = macro:be.types.ResolveProperty;
                        signatureType = t;
                        
                    // [Type->Type, ~/r/opt]
                    case [t = TFun(_, _), TInst(_.get() => { kind:KExpr( e = _.expr => EConst(CRegexp(r, opt))) }, _)]:
                        ctype = macro:be.types.ResolveMethod;
                        signatureType = t;
                        if (r.indexOf('@') > -1) {
                            metaERegParts = [r, opt];
                            metaERegExpr = e;
                        } else {
                            fieldERegParts = [r, opt];
                            fieldERegExpr = e;
                        }

                    // [Type->Type, ~/fr/fopts, ~/mr/mopts]
                    case [t = TFun(_, _), TInst(_.get() => { kind:KExpr( e1 = _.expr => EConst(CRegexp(r1, opt1))) }, _), TInst(_.get() => { kind:KExpr( e2 = _.expr => EConst(CRegexp(r2, opt2))) }, _)]:
                        ctype = macro:be.types.ResolveMethod;
                        signatureType = t;
                        fieldERegParts = [r1, opt1];
                        fieldERegExpr = e1;
                        metaERegParts = [r2, opt2];
                        metaERegExpr = e2;

                    // [Type, ~/r/opt]
                    case [t, TInst(_.get() => { kind:KExpr( e = _.expr => EConst(CRegexp(r, opt))) }, _)]:
                        ctype = macro:be.types.ResolveProperty;
                        signatureType = t;
                        if (r.indexOf('@') > -1) {
                            metaERegParts = [r, opt];
                            metaERegExpr = e;
                        } else {
                            fieldERegParts = [r, opt];
                            fieldERegExpr = e;
                        }

                    // [Type, ~/fr/fopts, ~/mr/mopts]
                    case [t, TInst(_.get() => { kind:KExpr( e1 = _.expr => EConst(CRegexp(r1, opt1))) }, _), TInst(_.get() => { kind:KExpr( e2 = _.expr => EConst(CRegexp(r2, opt2))) }, _)]:
                        ctype = macro:be.types.ResolveProperty;
                        signatureType = t;
                        fieldERegParts = [r1, opt1];
                        fieldERegExpr = e1;
                        metaERegParts = [r2, opt2];
                        metaERegExpr = e2;

                    case _:
                        if (debug) {
                            for (param in params) {
                                trace( param );
                            }

                        }

                }

                signatureComplex = signatureType.toComplex();

            case TInst(_.get() => {pack:['be', 'types'], name:'Resolve'}, []):
                /**
                    If no parameters are found, its likely an import, or fully qualified usage.
                **/
                return macro:be.types.ResolveFunctions;

            case x:
                if (debug) trace( x );
                /**
                    Act like its the above statement by default.
                **/
                return macro:be.types.ResolveFunctions;
        }

        if (debug) {
            trace( 'signature           : ' + (signatureType == null ? null : signatureType.toString()) );
            trace( 'field ereg          : ' );
            trace( ' ⨽ expr             : ' + fieldERegExpr.toString() );
            trace( ' ⨽ regx             : ' + fieldERegParts[0] );
            trace( ' ⨽ opts             : ' + fieldERegParts[1] );
            trace( 'meta ereg           : ' );
            trace( ' ⨽ expr             : ' + metaERegExpr.toString() );
            trace( ' ⨽ regx             : ' + metaERegParts[0] );
            trace( ' ⨽ opts             : ' + metaERegParts[1] );

        }

        switch ctype {
            case TPath({params:params}):
                params.push( TPType(signatureComplex) );
                // Manually insert TPExpr, as `macro:be.types.Resolve{Method|Property}<$signatureComplex, $fieldEReg, $metaEReg>` fails.
                params.push( TPExpr(fieldERegExpr) );   // field name regular expression.
                params.push( TPExpr(metaERegExpr) );    // field metadata regular expression.

            case x:
                if (debug) trace(x);

        }

        if (debug) {
            try {
                trace( 'returned signature  : ' + ctype.toString() );

            } catch (_) {
                trace( ctype );

            }
        }

        return ctype;
    }

}